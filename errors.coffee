TypedError = require 'typed-error'

class LosetupError extends TypedError

class NotLoopDeviceError extends LosetupError
	constructor: (message, @path) ->
		@path = path
		super message

class LoopDeviceBusyError extends LosetupError
	constructor: (message, @path) ->
		@path = path
		super message

class LoopDeviceNotUsedError extends LosetupError
	constructor: (message, @path) ->
		super message

class LoopDeviceNotFoundError extends LosetupError
	constructor: (message, @path) ->
		super message

exports.LosetupError = LosetupError
exports.NotLoopDeviceError = NotLoopDeviceError
exports.LoopDeviceBusyError = LoopDeviceBusyError
exports.LoopDeviceNotUsedError = LoopDeviceNotUsedError
exports.LoopDeviceNotFoundError = LoopDeviceNotFoundError
