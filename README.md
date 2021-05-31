# NFCtoBLE

A simple way to connect an iOS device to a BLE peripheral by giving all essential tools threw property wrapper.

[![GitHub license](https://img.shields.io/github/license/yanngodeau/SimplyNFC)](https://github.com/yanngodeau/NFCtoBLE/blob/main/LICENSE)
[![Platform](https://img.shields.io/badge/plateform-iOS-yellow)](https://github.com/yanngodeau/NFCtoBLE)
[![Swift](https://img.shields.io/badge/swift-5.1%2B-orange)](https://swift.org)

## Principle

The iOS device uses the pairing key read from the NFC tag to locate the device to connect. Of course, the device must advertise the same ID.

> Please be aware that this framework does not manage the configuration of your Bluetooth device. It is up to you to configure it properly to advertise the pairing key you want.

## Installation

### Swift package manager

Go to `File | Swift Packages | Add Package Dependency...` in Xcode and search for « NFCtoBLE » .

If you have *Swift.package* file, include the following dependency:

```swift
dependencies: [
    // [...]
    .package(name: "NFCtoBLE", 
             url: "https://github.com/yanngodeau/NFCtoBLE.git", 
             .upToNextMajor(from: "x.y")) // Replace x.y with your required version
]
```

and add it to your target:

```swift
targets: [
    // [...]
    .target(
        name: "<Your target name>",
        dependencies: ["NFCtoBLE"]),
]
```

### Cathage

You can use [Carthage](https://github.com/Carthage/Carthage) to install `NFCtoBLE` by adding it to your `Cartfile`.

```swift
github "yanngodeau/NFCtoBLE"
```

### Manual

1. Put NFCtoBLE repo somewhere in your project directory.
2. In Xcode, add `NFCtoBLE.xcodeproj` to your project
3. On your app's target, add the NFCtoBLE framework:
   1. as an embedded binary on the General tab.
   2. as a target dependency on the Build Phases tab.

## Usage

### @NFCTag

`@NFCTag` is a property wrapper used to combine all tag reading and writing logic, as well as pairing management.

#### Mark a property as @NFCTag

```swift
@NFCTag(pairingKey: "c20c8a91-badb-4d5f-a563-960f8e3b1608") myPeripheral = MyPeripheral()
```

`myPeripheral` is the object describing the Bluetooth device you plan to connect to. It can be whatever you want, or whatever you think is useful to write on the tag to describe the Bluetooth device.

The `pairingKey` parameter represents the pairing identifier used to locate a BLE device. It must be the same as the one announced by the device you plan to connect to.

If you don't know the pairing key and intend to read a tag to retrieve it, you can set the key to `nil`.  The key will be redefined when the tag is read.

#### Write tag

```swift
@NFCTag(pairingKey: "c20c8a91-badb-4d5f-a563-960f8e3b1608") myPeripheral: MyPeripheral()

_myPeripheral.write { manager in
    // Session did become active
    manager.setMessage("👀 Place iPhone near the tag to be written on")
} didWrite: { manager, result in
    // Tag has been written
    switch result {
    case .failure:
        manager.setMessage("👎 Failed to write tag")
    case .success:
        manager.setMessage("🙌 Tag successfully written")
}
```

`didBecomeActive` : handles actions on session activation

`didWrite` : handles actions when the tag has been written

#### Read tag

```swift
@NFCTag(pairingKey: nil) myPeripheral: MyPeripheral()

_myPeripheral.read { manager in
    manager.setMessage("👀 Place iPhone near the tag to read")
} didRead: { manager, result in
    switch result {
    case .failure(let error):
        manager.setMessage("👎 Failed to read tag")
    case .success:
        manager.setMessage("🙌 Tag read successfully")
}
```

`didBecomeActive` : handles actions on session activation

`didRead` : handles actions when the tag has been read

#### Pairing

```swift
@NFCTag(pairingKey: "c20c8a91-badb-4d5f-a563-960f8e3b1608") myPeripheral: MyPeripheral()
var usedServices : [CBUUID] // Target services to be used

_myPeripheral.scanToConnect(withservices: [usedServices]) { manager in
    // Session did become active
} didConnect: { manager, result in 
    switch result {
    case .failure(let error):
        print("Tag. connection failure")
    case .success:
        print("Connected to peripheral")
        connectedPeripheral = try? result.get() // Get the connected peripheral 
}
```

`didBecomeActive` : handles actions on session activation

`didRead` : handles actions when the tag has been read

`didConnect` : handles actions when the tag has been connected

#### Handle received values

You can handle the received value by adding an action using the `Peripheral` function `onValueUpdated(_ perform: @escaping DidUpdateValue)` :

```swift
connectedPeripheral?.onValueUpdated({ characteristicUUID, data in
    // Perform action
})
```

## Contribute

- Fork it!
- Create your feature branch: `git checkout -b my-new-feature`
- Commit your changes: `git commit -am 'Add some feature'`
- Push to the branch: `git push origin my-new-feature`
- Submit a pull request

## License

SimplyNFC is distributed under the [MIT License](https://mit-license.org).

## Author

- Yann Godeau - [@yanngodeau](https://github.com/yanngodeau)


