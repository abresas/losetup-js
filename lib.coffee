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

# LoopDevice describes a loop device, whether it is used or not.
exports.LoopDevice = LoopDevice = (path, isUsed, device, inode, fileName, offset) ->
	return { path, isUsed, device, inode, fileName, offset }

# Read the loop device status for a device in path.
#
# Used for populating instances of LoopDevice.
#
# @returns Promise Status64
readStatus = (path) ->
	fs.openAsync(path, 'r+')
	.then (fd) ->
		Promise.try ->
			status64 = Status64()
			buf = status64.buffer()
			ioctl(fd, LOOP_GET_STATUS64, buf)
			return status64
		.finally ->
			fs.closeAsync(fd)

# Returns a promise that resolves to true if the file in path
# is a loop device.
#
# @returns Promise Boolean
exports.isLoopDevice = isLoopDevice = (path) ->
	fs.statAsync(path)
	.then (stat) ->
		stat.isBlockDevice() and stat.rdev >> 8 == LOOPMAJOR

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
exports.attach = attach = (loopDevice, path, opts = {}) ->
	Promise.try ->
		if loopDevice.isUsed
			throw new LoopDeviceBusyError('Cannot allocate already used device.', loopDevice.path)
		devFd = fs.openAsync(loopDevice.path, 'r+')
		targetFd = fs.openAsync(path, 'r+')
		Promise.all([ devFd, targetFd ])
	.spread (devFd, targetFd) ->
		Promise.try ->
			ioctl(devFd, LOOP_SET_FD, targetFd)
		.catch (e) ->
			msg = 'Failed setting loopback device file descriptor.'
			if e.errno
				msg += ' ioctl errno: ' + e.errno
			throw new LosetupError(msg)
		.finally ->
			fs.closeAsync(targetFd)
		.then ->
			status64 = Status64()	
			status64.buffer().fill(0)
			status64.set('file_name', path)
			if opts.partscan
				status64.set('flags', FLAGS_PARTSCAN)
			if opts.offset
				status64.set('offset', opts.offset)
			Promise.try ->
				ioctl(devFd, LOOP_SET_STATUS64, status64.buffer(), true)
			.catch (e) ->
				msg = 'Failed updating loopback device status.'
				if e.errno
					msg += ' ioctl errno: ' + e.errno
				Promise.try ->
					ioctl(devFd, LOOP_CLR_FD)
				.catch (e) ->
					console.error('Failed to unmount during clean up', e, e.stack)
				.finally ->
					throw new LosetupError(msg)
			.then ->
				if opts.partscan
					Promise.try ->
						ioctl(devFd, BLKRRPART, 0)
					.catch (e) ->
						# Setting the loop device succeeded, but only rereading partition table failed.
						# Print a warning, but consider the operation successful.
						console.error('Failed to reread partition table.', e)
		.finally ->
			fs.closeAsync(devFd)
	.then ->
		getLoopDevice(loopDevice.path) # return loop device with new data

# Detach a loop device from any files, and return a new instance of LoopDevice.
#
# @returns Promise [LoopDevice]
exports.detach = detach = Promise.method (loopDevice) ->
	Promise.try ->
		if not loopDevice.isUsed
			throw new LoopDeviceNotUsedError('Cannot delete unallocated loop device.', loopDevice.path)
		fs.openAsync(loopDevice.path, 'r+')
	.then (fd) ->
		ioctl(fd, LOOP_CLR_FD)
	.then ->
		getLoopDevice(loopDevice.path) # return loop device with new data

exports.reloadPartitionTable = Promise.method (loopDevice) ->
	Promise.try ->
		if not loopDevice.isUsed
			throw new LoopDeviceNotUsedError('Cannot read partition table from unallocated loop device.', loopDevice.path)
		fs.openAsync(loopDevice.path, 'r')
	.then (fd) ->
		ioctl(fd, BLKRRPART, 0)
