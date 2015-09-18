Promise = require 'bluebird'
util = require 'util'
fs = Promise.promisifyAll(require 'fs')
path = require 'path'
ioctl = require 'ioctl'
Struct = require 'struct'
TypedError = require 'typed-error'

DEV_LOOP_PATH = '/dev'
LOOPMAJOR = 7
LOOP_SET_FD = 0x4C00
LOOP_CLR_FD = 0x4C01
LOOP_SET_STATUS64 = 0x4C04
LOOP_GET_STATUS64 = 0x4C05
BLKRRPART = 4703
FLAGS_PARTSCAN = 8

# Data structure that can be used in place of loop_info64 for ioctl calls.
#
# See http://lxr.free-electrons.com/source/include/uapi/linux/loop.h#L45
# for the definition of struct loop_info64.
Status64 = ->
	status64 = Struct()
		.word64Ule('device')
		.word64Ule('inode')
		.word64Ube('rdevice')
		.word64Ule('offset')
		.word64Ule('size_limit')
		.word32Ule('number')
		.word32Ule('encrypt_type')
		.word32Ule('encrypt_key_size')
		.word32Ule('flags')
		.chars('file_name', 64)
		.chars('encrypt_key', 32)
		.array('init', 2, 'word64Ule')
	status64.allocate()

class LosetupError extends TypedError
exports.LosetupError = LosetupError

class NotLoopDeviceError extends LosetupError
	constructor: (message, @path) ->
		@path = path
		super message
exports.NotLoopDeviceError = NotLoopDeviceError

class LoopDeviceBusyError extends LosetupError
	constructor: (message, @path) ->
		@path = path
		super message
exports.LoopDeviceBusyError = LoopDeviceBusyError

class LoopDeviceNotUsedError extends LosetupError
	constructor: (message, @path) ->
		super message
exports.LoopDeviceNotUsedError = LoopDeviceNotUsedError

class LoopDeviceNotFoundError extends LosetupError
	constructor: (message, @path) ->
		super message
exports.LoopDeviceNotFoundError = LoopDeviceNotFoundError

# LoopDevice describes a loop device, whether it is used or not.
exports.LoopDevice = LoopDevice = (path, isUsed, device, inode, fileName, offset) ->
	return { path, isUsed, device, inode, fileName, offset }

# Read the loop device status for a device in path.
#
# Used for populating instances of LoopDevice.
#
# @returns Promise Status64
readStatus = (path) ->
	fd = fs.openAsync(path, 'r+').disposer (fd) ->
		fs.closeAsync(fd)
	Promise.using fd, (fd) ->
		status64 = Status64()
		buf = status64.buffer()
		ioctl(fd, LOOP_GET_STATUS64, buf)
		return status64
	.catch (e) ->
		if e.code is 'ENOENT'
			throw new LoopDeviceNotFoundError('Loop device not found.', path)
		else
			throw e

# Returns a promise that resolves to true if the file in path
# is a loop device.
#
# @returns Promise Boolean
exports.isLoopDevice = isLoopDevice = (path) ->
	fs.statAsync(path)
	.then (stat) ->
		stat.isBlockDevice() and stat.rdev >> 8 == LOOPMAJOR
	.catch (e) ->
		if e.code is 'ENOENT'
			throw new LoopDeviceNotFoundError('Loop device not found.', path)
		else
			throw e

# Get information about a loop device.
#
# @returns Promise LoopDevice
exports.getLoopDevice = getLoopDevice = (path) ->
	isLoopDevice(path)
	.then (isLoop) ->
		if not isLoop
			throw new NotLoopDeviceError('Not a loop device', path)
		readStatus(path)
		.then (status) ->
			LoopDevice(path, true, status.get('device'), status.get('inode'), status.get('file_name'), status.get('offset'))
		.catch ->
			LoopDevice(path, false, null, null, null, 0)

# List all loop devices, used or not.
#
# @returns Promise [LoopDevice]
exports.listAll = listAll = (path = DEV_LOOP_PATH) ->
	fs.readdirAsync(path)
	.filter (file) ->
		file.match(/^loop(\d+)$/)
	.map (f) ->
		DEV_LOOP_PATH + '/' + f
	.filter(isLoopDevice)
	.map(getLoopDevice)

# List all used loop devices.
#
# @returns Promise [LoopDevice]
exports.listUsed = listUsed = (path = DEV_LOOP_PATH) ->
	listAll(path)
	.filter (loopDevice) ->
		loopDevice.isUsed

# Find the first unused loop device.
#
# @returns Promise [LoopDevice]
exports.findUnused = findUnused = (path = DEV_LOOP_PATH) ->
	listAll(path)
	.filter (loopDevice) ->
		not loopDevice.isUsed
	.get(0)

# Attach a loop device to a file, and return a new instance of LoopDevice.
#
# @returns Promise [LoopDevice]
exports.attach = attach = Promise.method (loopDevice, path, opts = {}) ->
	if loopDevice.isUsed
		throw new LoopDeviceBusyError('Cannot allocate already used device.', loopDevice.path)
	devFd = fs.openAsync(loopDevice.path, 'r+').disposer (fd) ->
		fs.closeAsync(fd)
	targetFd = fs.openAsync(path, 'r+').disposer (fd) ->
		fs.closeAsync(fd)
	Promise.using devFd, targetFd, (devFd, targetFd) ->
		Promise.try ->
			ioctl(devFd, LOOP_SET_FD, targetFd)
		.then ->
			status64 = Status64()	
			status64.buffer().fill(0)
			status64.set('file_name', path)
			if opts.partscan
				status64.set('flags', FLAGS_PARTSCAN)
			if opts.offset
				status64.set('offset', opts.offset)
			ioctl(devFd, LOOP_SET_STATUS64, status64.buffer(), true)
	.then ->
		getLoopDevice(loopDevice.path) # return loop device with new data
	.catch (e) ->
		detach(loopDevice)
		.catch (e) ->
			console.error('Failed to detach during clean up', e, e.stack)
		.finally ->
			throw e

# Detach a loop device from any files, and return a new instance of LoopDevice.
#
# @returns Promise [LoopDevice]
exports.detach = detach = Promise.method (loopDevice) ->
	if not loopDevice.isUsed
		throw new LoopDeviceNotUsedError('Cannot delete unallocated loop device.', loopDevice.path)
	fs.openAsync(loopDevice.path, 'r+')
	.then (fd) ->
		ioctl(fd, LOOP_CLR_FD)
	.then ->
		getLoopDevice(loopDevice.path) # return loop device with new data

exports.reloadPartitionTable = reloadPartitionTable = Promise.method (loopDevice) ->
	if not loopDevice.isUsed
		throw new LoopDeviceNotUsedError('Cannot read partition table from unallocated loop device.', loopDevice.path)
	fs.openAsync(loopDevice.path, 'r')
	.then (fd) ->
		ioctl(fd, BLKRRPART, 0)
