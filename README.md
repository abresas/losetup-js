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
* [losetup.isLoopDevice(path)](#module_is_loop_device)
* [losetup.getLoopDevice(path)](#module_get_loop_device)
* [losetup.listAll(path = "/dev")](#module_list_all)
* [losetup.listUsed(path = "/dev")](#module_list_used)
* [losetup.findUnused(path = "/dev/")](#module_find_unused)
* [losetup.attach](#module_attach)
* [losetup.detach](#module_detach)

<a name="loopdevice"></a>
#### LoopDevice(path, isUsed, device, inode, fileName)

"constructor" function for a loop device data structure.

Returns objects having the following fields:

* <a name="loopdevice_path"></a> path: String
* <a name="loopdevice_is_used"></a> isUsed: Boolean
* <a name="loopdevice_device"></a> device: Integer
* <a name="loopdevice_inode"></a> inode: Integer
* <a name="loopdevice_file_name"></a> fileName: String

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
##### losetup.attach(LoopDevice dev, String path) => Promise LoopDevice
Attaches the loop device dev to the file in path.

Result promise resolves to an updated loop device description.
Does not alter the input object.

<a name="module_detach"></a>
##### losetup.detach(LoopDevice dev) => Promise LoopDevice
Detaches any files from loop device dev.

Result promise resolves to an updated loop device description.
Does not alter the input object.

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
