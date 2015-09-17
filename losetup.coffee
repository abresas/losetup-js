Promise = require 'bluebird'
losetup = require './lib'
program = require 'commander'

show = (dev) ->
	if dev.isUsed
		console.log(dev.path + ': [' + ('0000' + dev.device.toString(16)).slice(-4) + ']:' + dev.inode + ' (' + dev.fileName + ')')
	else
		console.log('device ' + dev.path + ' is not used.')

help = ->
	console.log('Usage:')
	console.log(' ' + program.name(), 'loop_device                             give_info')
	console.log(' ' + program.name(), '-a | --all                              list all used')
	console.log(' ' + program.name(), '-d | --detach <loopdev> [<loopdev> ...] delete')
	console.log(' ' + program.name(), '-f | --find                             find unused')
	console.log(' ' + program.name(), '[options] {-f|--find|loopdev} <file>    setup')
	console.log('')
	console.log('Options:')
	console.log(' -h, --help             this help')
	console.log(' -v, --verbose          verbose mode')
	console.log(' --version              print version information')

	process.exit(0)

program.version(require('./package.json').version)

program
.option('-a, --all')
.option('-d, --detach')
.option('-f, --find')
.option('-v, --verbose')
.option('-h, --help')
.on('help', help)
.parse(process.argv)

Promise.try ->
	if program.detach # losetup -d [loopdev...]
		if not program.args.length
			devices = losetup.listUsed()
		else
			devices = Promise.all(losetup.getLoopDevice(path) for path in program.args)
		devices.each(losetup.detach)	
	else if program.all # losetup -a
		if program.args.length
			help()
		losetup.listUsed()
		.each(show)
	else if program.find # losetup -f [file]
		if program.args.length > 1
			help()
		losetup.findUnused()
		.then (dev) ->
			if program.args.length
				losetup.attach(dev, program.args[0])
			else
				console.log(dev.path)
	else # losetup loopdev [file]
		if program.args.length > 2 or not program.args.length
			help()
		losetup.getLoopDevice(program.args[0])
		.then (dev) ->
			if program.args.length == 2
				losetup.attach(dev, program.args[1])
			else
				show(dev)
.catch losetup.NotLoopDeviceError, (e) ->
	console.error('device not a loop device: ' + e.path)	
	process.exit(65)
.catch losetup.LoopDeviceBusyError, (e) ->
	console.error('loop device busy: ' + e.path)
	process.exit(65)
.catch losetup.LoopDeviceNotUsedError, (e) ->
	console.error('loop device is not used: ' + e.path)
	process.exit(65)
.catch (e) ->
	console.error('losetup error', e, e.stack)
	process.exit(1)
