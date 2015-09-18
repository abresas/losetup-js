losetup
-------

[![npm version](https://badge.fury.io/js/losetup.svg)](http://npmjs.org/package/losetup)
[![dependencies](https://david-dm.org/abresas/losetup.png)](https://david-dm.org/abresas/losetup.png)

Losetup library for node.js.

Allows attaching, detaching, and listing loop devices in a Linux system.

Installation
------------

```sh
$ npm install losetup
```

Documentation
-------------

* [losetup.LoopDevice](#loopdevice)
  * [property: .path](#loopdevice_path)
  * [property: .isUsed](#loopdevice_is_used)
  * [property: .device](#loopdevice_device)
  * [property: .inode](#loopdevice_inode)
  * [property: .fileName](#loopdevice_file_name)
  * [property: .offset](#loopdevice_offset)
* [losetup.errors](#errors)
  * [.LosetupError](#errors_losetup_error)
  * [.NotLoopDeviceError](#errors_not_loop_device_error)
  * [.LoopDeviceBusyError](#errors_loop_device_busy_error)
  * [.LoopDeviceNotUsedError](#errors_loop_device_not_used_error)
  * [.LoopDeviceNotFoundError](#errors_loop_device_not_found_error)
* [losetup.isLoopDevice(path)](#module_is_loop_device)
* [losetup.getLoopDevice(path)](#module_get_loop_device)
* [losetup.listAll(path = "/dev")](#module_list_all)
* [losetup.listUsed(path = "/dev")](#module_list_used)
* [losetup.findUnused(path = "/dev/")](#module_find_unused)
* [losetup.attach(loopDevice, path, opts = {})](#module_attach)
* [losetup.detach(loopDevice)](#module_detach)
* [losetup.reloadPartitionTable(loopDevice)](#module_reload_partition_table)

<a name="loopdevice"></a>
#### losetup.LoopDevice(path, isUsed, device, inode, fileName)

Class describing a loop device.

Properties:

* <a name="loopdevice_path"></a> *path*: String
* <a name="loopdevice_is_used"></a> *isUsed*: Boolean
* <a name="loopdevice_device"></a> *device*: Integer
* <a name="loopdevice_inode"></a> *inode*: Integer
* <a name="loopdevice_file_name"></a> *fileName*: String
* <a name="loopdevice_offset"></a> *offset*: Integer

<a name="errors"></a>
#### losetup.errors

Contains all the exported error classes:

* <a name="errors_losetup_error"></a> *LosetupError*: All errors inherit from this class.
* <a name="errors_not_loop_device_error"></a> *NotLoopDeviceError*: The device is not a loop device.
* <a name="errors_loop_device_busy_error"></a> *LoopDeviceBusyError*: The device is busy (already attached).
* <a name="errors_loop_device_not_used_error"></a> *LoopDeviceNotUsedError*: The device was expected to be attached, but isn't.
* <a name="errors_loop_device_not_found_error"></a> *LoopDeviceNotFoundError*: The device does not exist at all.

<a name="module_is_loop_device"></a>
##### losetup.isLoopDevice(String path) => Promise Boolean
Promise resolves to true if path is a loop device.

<a name="module_get_loop_device"></a>
##### losetup.getLoopDevice(String path) => Promise LoopDevice
Resolves to a LoopDevice describing the device in path.

<a name="module_list_all"></a>
##### losetup.listAll(String path = "/dev") => Promise [LoopDevice]
Resolves to a list of LoopDevice for all the loop devices in path.

<a name="module_list_used"></a>
##### losetup.listUsed(String path = "/dev") => Promise [LoopDevice]
List all the loop devices in path that are currently attached to a file.

<a name="module_find_unused"></a>
##### losetup.findUnused(String path = "/dev") => Promise LoopDevice
Finds the first loop device in path that is currently not used.

<a name="module_attach"></a>
##### losetup.attach(LoopDevice dev, String path, Object opts = {}) => Promise LoopDevice
Attaches the loop device dev to the file in path.

Result promise resolves to an updated loop device description.
Does not alter the input object.

The third argument defines additional options:
  * *partscan*: Enable partition scanning on device. Boolean, defaults to false.
  * *offset*: Attach to an offset in the file, in bytes. Number, defaults to 0.

<a name="module_detach"></a>
##### losetup.detach(LoopDevice dev) => Promise LoopDevice
Detaches any files from loop device dev.

Result promise resolves to an updated loop device description.
Does not alter the input object.

<a name="module_reload_partition_table"></a>
##### losetup.reloadPartitionTable(LoopDevice dev) => Promise
Forces the operating system to reload partition table for device.

Uses BLKRRPART ioctl command.

If device /dev/loopX is a disk with many partitions, then after calling this function,
the operating system will create /dev/loopXpY for each partition of the disk.

To make sure the operating system will scan the partition table,
attach the device with partscan option enabled.

Support
-------

If you're having any problem, please [raise an issue](https://github.com/abresas/losetup-js/issues/new) on GitHub.

Contribute
----------

- Issue Tracker: [github.com/abresas/losetup-js/issues](https://github.com/abresas/losetup-js/issues)
- Source Code: [github.com/abresas/losetup-js](https://github.com/abresas/losetup-js)

License
-------

The project is licensed under the Apache License 2.0.
