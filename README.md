
<p align="center">
  <img width="200" height="200" src="README/Icon.png">
</p>
<p><img src="https://img.shields.io/static/v1?label=platforms&message=iOS13|macOS10.15|watchOS6.0|tvOS13&color=black"></p> <p><img src="https://img.shields.io/static/v1?label=carthage&message=compatible&color=green"> <img src="https://img.shields.io/static/v1?label=SwiftPM&message=compatible&color=green"></p>

![Swift](https://github.com/DrAma999/LittleBlueTooth/workflows/Swift/badge.svg?branch=master)
[![CodeFactor](https://www.codefactor.io/repository/github/drama999/littlebluetooth/badge)](https://www.codefactor.io/repository/github/drama999/littlebluetooth)
[![codecov](https://codecov.io/gh/DrAma999/LittleBlueTooth/branch/master/graph/badge.svg)](https://codecov.io/gh/DrAma999/LittleBlueTooth)

  
  
# LITTLE BLUETOOTH
## INTRODUCTION
LittleBluetooth is a library that helps you developing applications that need to work with a bluetooth low energy device.
It is written using `Swift` and the `Combine` framework thus is only compatible from iOS 13, macOS 10.15, watchOS 6.0 to upper version.
It will make pretty easy to work with CoreBlueTooth: connecting to a peripheral and reading a characteristic can be mabe with just these lines of code:
```
StartLittleBlueTooth
.startDiscovery(for: self.littleBT, withServices: [CBUUID(string: HRMCostants.HRMService)])
.prefix(1)
.connect(for: self.littleBT)
.read(for: self.littleBT, from: hrmSensorChar)
.sink(receiveCompletion: { (result) in
    print("Result: \(result)")
    switch result {
    case .finished:
        break
    case .failure(let error):
        print("Error while changing sensor position: \(error)")
        break
    }
        
}) { (value: HeartRateSensorPositionResponse) in // Specify the concrete type
    print("Value: \(value)")
}
.store(in: &disposeBag)
```
An instance of LittleBluetooth can control only one peripheral, you can use more instances as many peripheral you need, but first read this [answer](https://developer.apple.com/forums/thread/20810) on Apple forums to understand the impact of having more `CBCentralManager` instances.

The library is still on development so use at own you risk.

[!NOTE]  
While the 1.0.0 compile fine on swift 6 even with complete concurrency check, it doesn't mean is thread safe. CoreBluetooth is not yet and is very difficult to make it fully compliant. That is why exposed classes arre marked as `@unchecked Sendable`. For previous swift version is possible to resolve versione `0.8.0`.

## TOC
[Features](#features)

[Installation](#installation)

[How to use it](#how-to-use-it)

* [Instantiate](#instantiate)
* [Scan](#scan)
* [Connect](#connect)
* [Read](#read)
* [Write](#write)
* [Listen](#listen)
* [Disconnection](#disconnection)
* [Connection event observer](#connection-event-observer)
* [Initialization operation](#initialization-operations)
* [Autoconnection](#Autoconnection)
* [State preservation and restoration](#state-preservation-and-state-restoration)
* [Central manager extraction](#cbcentralmanager-cbperipheral-extraction)

[Custom operators](#custom-combine-operator)

[Documentation](#documentation)

[Sample application](#sample-application)

[License](#license)

## FEATURES
* Built on top of Combine
* Deploys on **iOS, macOS, macOS (Catalyst), tvOS, watchOS**
* Chainable operations: scan, connect, enable listen, disable listen and read/write . Each operation is executed serially without having to worry in dealing with delegates
* Peripheral state and bluetooth state observation. You can watch the bluetooth state and also the peripheral states for a more fine grained control in the UI. Those information are also checked before starting any operation.
* Single notification channel: you can subscribe to the notification channel to receive all the data of the enabled characteristics. You have also single and connectable publishers.
* Write and listen (or better listen and write): sometimes you need to write a command and get a “response” right away
* Initialization operations: sometimes you want to perform some bluetooth commands right after a connection, for instance an authentication, and you want to perform that before another operation have access to the peripheral.
* Readable and Writable characteristics: basically those two protocols will deal in reading a `Data` object to the concrete type you want or writing your concrete type into a `Data` object.
* Simplified `Error` normalization and if you need more information you can always access the inner `CBError`
* Code coverage > 90% 

## INSTALLATION
### Carthage
Add the following to your Cartfile:

```
github "DrAma999/LittleBlueTooth" ~> 1.0.0
```
Since the framework supports most of the Apple devices, you probably want to to build for a specific platform by adding the option `--platform` after the `carthage update` command. For instance:
```
carthage update --platform iOS`
```

*This step is super-optional:*
The library has a sub-dependency with Nordic library [Core Bluetooth Mock](https://github.com/NordicSemiconductor/IOS-CoreBluetooth-Mock) that helped me in creating unit tests, if you want to launch unit tests you must add this to your Cartfile and use the `LittleBlueToothForTest` product instead of  `LittleBlueTooth`, note that this target is made only to run tests by using mocks.

### Swift Package Manager
Add the following dependency to your Package.swift file:
```
.package(url: "https://github.com/DrAma999/LittleBlueTooth.git", from: "0.7.1")
```
Or simply add the URL from XCode menu Swift packages.
### XCFramework
Already compiled XCFramework are avaible to be download in the release section of github.

## HOW TO USE IT
### Instantiate
Create a `LittleBluetoothConfiguration` object and pass it to the init method of `LittleBlueTooth`.
All `LittleBluetoothConfiguration` properties are optional.
```
    var littleBTConf = LittleBluetoothConfiguration()
    littleBT = LittleBlueTooth(with: littleBTConf)
```
### Scan
You can scan with or without a timeout, after a timeout you receive a `.scanTimeout` error. 
You can set up your timeout for each sort of operation, for instance for a scan:
```
anycanc = littleBT.startDiscovery(withServices: [littleChar.service])
.timeout(DispatchQueue.SchedulerTimeType.Stride(timeout.dispatchInterval), scheduler: DispatchQueue.main, options: nil, error: .scanTimeout)
```
Note that each peripheral found is published to the subscribers chain until you stop the scan request or you connect to a device (when you connect scan is automatically suspended.

_Scan and stop_:

```
        // Remember that the AnyCancellable resulting from the `sink` must have a strong reference
        // Also pay attention to eventual retain cycles
        anycanc = littleBT.startDiscovery(withServices: [littleChar.service])
        .filter { (discovery) -> Bool in
            print("discovery \(discovery)")
            if let name = discovery.advertisement.localName, name == "PunchLX" {
                return true
            }
            return false
        }
        .flatMap{ (discovery) -> AnyPublisher<PeripheralDiscovery, LittleBluetoothError> in
            print("Discovery: \(discovery)")
            return self.littleBT.stopDiscovery()map {discovery}.eraseToAnyPublisher()
        }
        .sink(receiveCompletion: { result in
            print("Result: \(result)")
            switch result {
            case .finished:
                break
            case .failure(let error):
                // Handle errors
                print("Error: \(error)")
            }
        }, receiveValue: { (periph) in
            print("Discovered Peripheral \(periph)")
        })
```
_Scan with connection_:

The scan process is automatically stopped once you start the connection command.
```
        // Remember that the AnyCancellable resulting from the `sink` must have a strong reference
        // Also pay attention to eventual retain cycles
        anycanc = littleBT.startDiscovery(withServices: [littleChar.service])
        .filter { (discovery) -> Bool in
            print("discovery \(discovery)")
            if let name = discovery.advertisement.localName, name == "PunchLX" {
                return true
            }
            return false
        }
        .flatMap { (discovery)-> AnyPublisher<Peripheral, LittleBluetoothError> in
            self.littleBT.connect(to: discovery)
        }
        .sink(receiveCompletion: { result in
            print("Result: \(result)")
            switch result {
            case .finished:
                break
            case .failure(let error):
                // Handle errors
            }
        }, receiveValue: { (periph) in
            print("Connected Peripheral \(periph)")
        })
```
_Scan with peripherals buffer_:

```
        // Remember that the AnyCancellable resulting from the `sink` must have a strong reference
        // Also pay attention to eventual retain cycles
        anycanc = littleBT.startDiscovery(withServices: [littleChar.service])
        .collect(10)
        .map{ (discoveries) -> AnyPublisher<[PeripheralDiscovery], LittleBluetoothError> in
            print("Discoveries: \(discoveries)")
            return self.littleBT.stopDiscovery().map {discoveries}.eraseToAnyPublisher()
        }
        .sink(receiveCompletion: { result in
            print("Result: \(result)")
            switch result {
            case .finished:
                break
            case .failure(let error):
                // Handle errors
                print("Error: \(error)")
            }
        }, receiveValue: { (peripherals) in
            print("Discovered Peripherals \(peripherals)")
        })
```

### Connect
_Connection from discovery_:

A `PeripheralDiscovery` is a representation of what you usually get from a scan, it has the `UUID` of the peripheral and the advertising info.
```
        // Taken a discovery from scan
        anycanc = self.littleBT.connect(to: discovery)
        .sink(receiveCompletion: { result in
            print("Result: \(result)")
            switch result {
            case .finished:
                break
            case .failure(let error):
                // Handle errors
            }
        }, receiveValue: { (periph) in
            print("Connected Peripheral \(periph)")
        })
```
_Direct connection from peripheral identifier_:

 `PeripheralIdentifier` is a wrapper around a `CBPeripheral` identifier, this allows you to connect to a peripheral just knowing the `UUID` of the peripheral.
```

         anycanc = self.littleBT.connect(to: peripheralIs)
        .sink(receiveCompletion: { result in
            print("Result: \(result)")
            switch result {
            case .finished:
                break
            case .failure(let error):
                // Handle errors
            }
        }, receiveValue: { (periph) in
            print("Connected Peripheral \(periph)")
        })
```

### Read
_Reading from a characteristic_:

To read from a characteristic first you have to create an instance of `LittleBluetoothCharacteristic` and define the data you want to read.
```
let littleChar = LittleBlueToothCharacteristic(characteristic: "19B10011-E8F2-537E-4F6C-D104768A1214", for: "19B10010-E8F2-537E-4F6C-D104768A1214")
```
The class or struct that you want to read must conform to the `Readable`
protocol, basically it means that it can be instantiated from a `Data` object.

For example here I’m declaring and `Acceleration` struct that contains acceleration data from a sensor.

```
struct Acceleration: Readable {
    let measureAx: Float
    let measureAy: Float
    let measureAz: Float
    let measureGx: Float
    let measureGy: Float
    let measureGz: Float

    let timestamp: TimeInterval

    init(from bluetoothData: Data) throws {
        let timeInt: UInt32 = try bluetoothData.extract(start: 0, length: 4)
        timestamp = TimeInterval(exactly: timeInt.littleEndian)! / 1000.0
        var measureInt: Int16 = try bluetoothData.extract(start: 4, length: 2)
        measureAx = Float(measureInt.littleEndian) / 100.0
        measureInt = try bluetoothData.extract(start: 6, length: 2)
        measureAy = Float(measureInt.littleEndian) / 100.0
        measureInt = try bluetoothData.extract(start: 8, length: 2)
        measureAz = Float(measureInt.littleEndian) / 100.0
        var measureGyroInt: Int32 = try bluetoothData.extract(start: 10, length: 4)
        measureGx = Float(measureGyroInt.littleEndian) / 100.0
        measureGyroInt = try bluetoothData.extract(start: 14, length: 4)
        measureGy = Float(measureGyroInt.littleEndian) / 100.0
        measureGyroInt = try bluetoothData.extract(start: 18, length: 4)
        measureGz = Float(measureGyroInt.littleEndian) / 100.0
    }

}
```

After that, is just a matter of call the read method.

```
        anycanc = littleBT.startDiscovery(withServices: [littleChar.service])
        .filter { (discovery) -> Bool in
            if let name = discovery.advertisement.localName, name == "PunchLX" {
                return true
            }
            return false
        }
        .flatMap { (discovery)-> AnyPublisher<Peripheral, LittleBluetoothError> in
            self.littleBT.connect(to: discovery)
        }
        .flatMap{_ -> AnyPublisher<LedState, LittleBluetoothError> in
            self.littleBT.read(from: self.littleChar)
        }
        .sink(receiveCompletion: { result in
            print("Result: \(result)")
            switch result {
            case .finished:
                break
            case .failure(let error):
                print("Error: \(error)")
                // Handle error
            }
        }, receiveValue: { (acc) in
            print("Read \(acc)")
        })
```

### Write
_Writing to a characteristic_:

To write to a characteristic first you have to create an instance of `LittleBluetoothCharacteristic` and define the data you want to read.
```
let littleChar = LittleBlueToothCharacteristic(characteristic: "19B10011-E8F2-537E-4F6C-D104768A1214", for: "19B10010-E8F2-537E-4F6C-D104768A1214")
```
The class or struct that you want to write must conform to the `Writable`
protocol, basically it means that it can be converted to a `Data` object.

For example here I’m declaring an object that simply turns on and off a LED.
```
struct LedState: Writable {
    let isOn: Bool
    var data: Data {
        return isOn ? Data([0x01]) : Data([0x00])
    }
}
```

After that is just a matter of call the write publisher.

```
littleBT.write(to: charateristic, value: ledState)
```

_WriteAndListen_:

Sometimes you need to write a command to a “Control point” and read the subsequent reply from the BT device.
This means attach yourself as a listener to a characteristic, write the command and wait for the reply.
This process has been made super simple by using “write and listen”.
```
        anycanc = littleBT.startDiscovery(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : false])
        .flatMap { discovery in
            self.littleBT.connect(to: discovery)
        }
        .flatMap { _ in
            self.littleBT.writeAndListen(from: littleCharateristic, value: ledState)
        }
        .sink(receiveCompletion: { completion in
            print("Result: \(result)")
            switch result {
            case .finished:
                break
            case .failure(let error):
                print("Error: \(error)")
                // Handle error
            }
        }) { (answer: LedState) in
            print("Answer \(answer)")            
        }
```

### Listen
You can listen to a charcteristic in different ways.

_Listen_:

After creating your `LittleCharacteristic` instance, then send the `startListen(from:)` and attach the subscriber. Of course the object you want to read must conform the `Readable` object.
```
anycanc = littleBT.startDiscovery(withServices: [littleChar.service])
.filter { (discovery) -> Bool in
    print("discovery \(discovery)")
    if let name = discovery.advertisement.localName, name == "PunchLX" {
        return true
    }
    return false
}
.flatMap { (discovery)-> AnyPublisher<Peripheral, LittleBluetoothError> in
    self.littleBT.connect(to: discovery)
}
.flatMap{_ -> AnyPublisher<LedState, LittleBluetoothError>in
    self.littleBT.startListen(from: self.littleChar)
}
.sink(receiveCompletion: { result in
    print("Result: \(result)")
}, receiveValue: { (acc) in
    print("Read \(acc)")
})
```



**Note: if you stop listening to a characteristic, it doesn’t matter if you have more subscribers. The listen process will stop. It’ s up you to provide the business logic to avoid this behavior.**

_Connectable listen_:

After creating your `LittleCharacteristic` instance, then send the `connectableListenPublisher(for: valueType:)`. Of course the object you want to read must conform the `Readable` object.
This is usefull when you want to create more subscribers and attach them later. When you are ready just call the `connect()` method and notifications will start to stream.
```
let connectable = littleBT.connectableListenPublisher(for: charateristic, valueType: ButtonState.self)

// First subscriber
connectable
.sink(receiveCompletion: { completion in
    print("Completion \(completion)")
}) { (answer) in
    print("Sub1 \(answer)")
}
.store(in: &disposeBag)

// Second subscriber
connectable
.sink(receiveCompletion: { completion in
    print("Completion \(completion)")
}) { (answer) in
  print("Sub2: \(answer)")
}
.store(in: &disposeBag)


littleBT.startDiscovery(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : false])
.map { disc -> PeripheralDiscovery in
    print("Discovery discovery \(disc)")
    return disc
}
.flatMap { discovery in
    self.littleBT.connect(to: discovery)
}
.map { _ -> Void in
    self.cancellable = connectable.connect()
    return ()
}
.sink(receiveCompletion: { completion in
    print("Completion \(completion)")
}) { (answer) in
    print("Answer \(answer)")
}
.store(in: &disposeBag)
```

_Multiple listen_:

If you need to receive more notifications on just one subscriber this publisher is made for you.
Just activate one or more notification and subscribe to the `listenPublisher` publisher.
It starts to stream all notifications once a peripheral is connected automatically.
Now, it's your responsability to filter and converting `Data` object from `CBCharacteristic` to your type.
```
// First publisher
littleBT.listenPublisher
.filter { charact -> Bool in
        charact.id == charateristicOne.id
}
.tryMap { (characteristic) -> ButtonState in
        try characteristic.value()
}
.mapError { (error) -> LittleBluetoothError in
    if let er = error as? LittleBluetoothError {
        return er
    }
    return .emptyData
}
.sink(receiveCompletion: { completion in
        print("Completion \(completion)")
    }) { (answer) in
        print("Sub1: \(answer)")
}
.store(in: &self.disposeBag)

// Second publisher
littleBT.listenPublisher
.filter { charact -> Bool in
        charact.id == charateristicOne.id
}
.tryMap { (characteristic) -> LedState in
    try characteristic.value()
}.mapError { (error) -> LittleBluetoothError in
    if let er = error as? LittleBluetoothError {
        return er
    }
    return .emptyData
}
.sink(receiveCompletion: { completion in
        print("Completion \(completion)")
    }) { (answer) in
        print("Sub2: \(answer)")
}
.store(in: &self.disposeBag)


littleBT.startDiscovery(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : false])
.map { disc -> PeripheralDiscovery in
        print("Discovery discovery \(disc)")
        return disc
}
.flatMap { discovery in
    self.littleBT.connect(to: discovery)
}
.flatMap { periph in
    self.littleBT.enableListen(from: charateristicOne)
}
.flatMap { periph in
    self.littleBT.enableListen(from: charateristicTwo)
}
.sink(receiveCompletion: { completion in
    print("Completion \(completion)")
}) { (answer) in
  
}
.store(in: &disposeBag)

```

### Disconnection
Disconnection can be explicit or unexpected.
Explicit when you call the method:
```
 self.littleBT.disconnect()
```
Unexpected can be due for different reasons: device reset, device out of range etc

Indipendently if it is unexpected or explicit `LittleBlueTooth` will clean up everything after registering a disconnection.

### Connection event observer
_Connection event observer_:

The `connectionEventPublisher` informs you about what happen while you are connected to a device.
A connection event is defined by different states:
* `.connected(CBPeripheral)`:  a peripheral was connected after a `connect` command
* `.autoConnected(CBPeripheral)`:  a peripheral was connected automatically, this event is triggered when you use the  `autoconnectionHandler`
* `.ready(CBPeripheral)`: this state means that now you can send commands to a peripheral. Why ready and not just connected? because you could have been set some `connectionTasks` and *ready* means that, if they where present, they have been executed.
* `.connectionFailed(CBPeripheral, error: LittleBluetoothError?)`: when during a connection something goes wrong
* `.disconnected(CBPeripheral, error: LittleBluetoothError?)`: when a peripheral ha been disconnected could be from an explicit disconnection or unexpected disconnection

_Peripheral state observer_:

It can be used for more fine grained control over peripheral states, they comes from the `CBPeripheralStates`

### Initialization operations
Sometimes after a connection you need to perform some repetitive task, for instance an authetication by sending a key or a NONCE.
This operations are stored inside the `connectionTasks` property and excuted after a  normal connection or from an autoconnection. All other operations will be excuted after this has been done.

### Autoconnection
The autoconnection is managed by the `autoconnectionHandler` handler.
You can inspect the error and decide if an automatic connection is necessary.
If you return `true` the connection process will start, once the peripheral has been found a connection will be established. If you return `false` iOS will not try to establish a connection.
Connection process will remain active also in background if the app has the right permission, to cancel just call `disconnect`.
When a connection will be established an `.autoConnected(PeripheralIdentifier)` event will be streamed to the `connectionEventPublisher`
If you want to cancel it you have to send an explicit disconnection.

Autoconnection will be interrupted in these condition:
App Permission | Conditions
------------ | -------------
App has no BT permission to run in bkg | Explicit disconnection, App killed by user/system, when suspended
App has  BT permission to run in bkg | Explicit disconnection, App killed by user/system
App has  BT permission to run in bkg and state restoration enable | Explicit disconnection, App killed by user

### State preservation and state restoration
First read Apple documentation [here](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html), [here](https://developer.apple.com/library/archive/qa/qa1962/_index.html) and my article on [Medium](https://medium.com/@andrea.alessandro/core-bluetooh-state-preservation-and-restoration-f107031b32fa).

To make state restoration/preservation work, first you must instantiate `LittleBluetTooth` with a dictionary that contains for the key `CBCentralManagerOptionRestoreIdentifierKey` a specific string identifier by using the `LittleBluetoothConfiguration` and you must add a handler that it will be called during state restoration. You MUST also opt-in for bluetooth LE accessories in background.
Must be also noted that state restoration works *always* not only in background, for instance if you kill the application using the swipe, the next time you relaunch it the Central Manager will return the previous state, you must consider that. If you only want  some operations to be run in background, just ask the UIApplication state and apply your business logic.

If your app is woken up by a bluetooh event in background it will call the `applicationDidFinishLauching` along with a dictionary. Using this key, `UIApplicationLaunchOptionsBluetoothCentralsKey`, you receive an array of identifiers of CBCentralManager instances that were working before the app was closed. You have a chance to restore the  `LittleBlueTooth` central manger by extracting the identifer from the launching option dictionary and passing it to the `LittleBlueToothConfiguration` (or you can simply instantiate using a constant).
If an state restoration event is triggered the handler will receive a `Restored` object.  A restored object con be a `Peripheral` along with its instance or a scan along with the discovery publisher that will publish all the discovered peripherals. A peripheral will be ruturned even if it is has been disconnected.
To be notified again about peripheral state please subscribe to the `connectionEventPublisher` only if the peripheral is in a *ready* state is possible to send other command.

If you don't want LittleBluetooth to manage state restoration, you can subscribe to the `restoreStatePublisher` publisher, you will receive a `CentralRestorer` object that contains all the necessary information to manage state restoration by yourself.
Note:
* Restoration can happen in background and foreground
* The Peripheral object returned can be in different state depending on what has been restored. If a peripheral has been disconnected and an  `autoconnectionHandler` is provided LittleBluetooth will try to re-establish a connection.

### CBCentralManager CBPeripheral extraction
Sometimes it could be uselful to extract an already connected peripheral and a central manger and pass them to another framework. For instance if you need to make an OTA firmware update using the nordic library this would be required.
The extraction is made exaclty for this purpuse.
```
let extractedState = littleBT.extract() 
```
Before extraction you need to stop listen to all the characteristics you where listening to.
The extracted state is a tuple `(central: CBCentralManager, peripheral: CBPeripheral?)`  that contains the used `CBCentralManger` and a `CBPeripheral` if connected.
You can also *restart* LittleBlueTooth instance by passing the same object that you have extracted.
```
self.littleBT.restart(with: extractedState.central, peripheral: extractedState.peripheral)
```

## CUSTOM COMBINE OPERATOR
Most of the functionalities are also wrapped inside custom operators. 

### Scan
The constant `StartLittleBlueTooth` is a syntatic sugar that helps you prepare the pipeline with correct error type:
```
StartLittleBlueTooth
.startDiscovery(for: self.littleBT, withServices: [CBUUID(string: HRMCostants.HRMService)])
.prefix(1)
// ...
```
The `.startDiscovery` operator can return multiple discoveries at different times it's up to you to take the correct results, by collecting, filtering, prefixing  before connecting at the next step.

### Connect
After getting a `PeripheralDiscovery` or a `PeripheralIdentifier` you can connect to that deveice.
```
StartLittleBlueTooth
.startDiscovery(for: self.littleBT, withServices: [CBUUID(string: HRMCostants.HRMService)])
.prefix(1)
.connect(for: self.littleBT)
// .sink( ...
```

### Read
To read is simple as:
```
StartLittleBlueTooth
           .read(for: self.littleBT, from: hrmSensorChar)
           .sink(receiveCompletion: { (result) in
               print("Result: \(result)")
               switch result {
               case .finished:
                   break
               case .failure(let error):
                   print("Error while changing sensor position: \(error)")
                   break
               }
               
           }) { (value: HeartRateSensorPositionResponse) in // Specify the concrete type
               print("Value: \(value)")
       }
       .store(in: &disposeBag)
```
Note that to make the compiler understand the generic type of the function at the next step you probably need to specify the concrete type.
### Write
```
StartLittleBlueTooth
          .write(for: self.littleBT, to: hrmControlPointChar, value: UInt8(0x01))
          .sink(receiveCompletion: { (result) in
              print("Result: \(result)")
              switch result {
              case .finished:
                  break
              case .failure(let error):
                  print("Error while writing control point: \(error)")
                  break
              }
              
          }) {}
      .store(in: &disposeBag)
```

### Listen
To listen directly (enable and get results) from a characteristic:
```
StartLittleBlueTooth
.startListen(for: self.littleBT, from: hrmRateChar)
.sink(receiveCompletion: { (result) in
        print("Result: \(result)")
        switch result {
        case .finished:
            break
        case .failure(let error):
            print("Error while trying to listen: \(error)")
        }
}) { (value: HeartRateMeasurementResponse) in
    self.hrmRateLabel.text = String(value.value)
}
.store(in: &disposeBag)
```
To enable listen on a characteristic and attach before or later on  the `littleBT.listenPublisher` 
```
.enableListen(for: self.littleBT, from: charateristicOne)
```
To stop:
```
.disableListen(for: self.littleBT, from: hrmRateChar)
```

### Disconnect
To disconnect from a device simply call:
```
.disconnect(for: self.littleBT)
```
### Note
To start operations using a publisher or a custom operator you **must attach a subscriber**.
And the result `AnyCancellable` must be store in a property or in a disposebag, you must guarantee the existance of the pipeline untill the end.

## DOCUMENTATION
Jazzy doc is available [here](https://drama999.github.io/LittleBlueTooth/index.html)

## SAMPLE APPLICATION
A sample application can be download [here](https://github.com/DrAma999/LittleBlueToothTestApp). It requires also to adownload an application for macOS or iOS to simulate a heart rate monitor.

## ROADMAP
- [x] SwiftPM support
- [x] State preservation and state restoration
- [ ] Improve code coverage
- [x] `CBManager` and `CBPeripheral` extraction
- [x] Add support to: **macOS**, **watchOS**, **tvOS**, **macOS catalyst**
- [x] Implement custom operator

## ISSUES
Please use Github, explaining what you did, how you did, what you expect and what you get.

## CONTRIBUTING
Since I'm working on this project in my spare time any help is appreciated.
Feel free to make a pull request.

## THANKS
This work would have never been possible without looking at the library [RXBluetooth Kit](https://github.com/Polidea/RxBluetoothKit) from Polidea (check it if you need to deploy on lower target) and [Bluejay](https://github.com/steamclock/bluejay), another amazing library for iOS.

Icon made by  [Freepik](https://www.flaticon.com/authors/freepik)  from  [www.flaticon.com](http://www.flaticon.com/) 

## LICENSE
MIT License

Copyright (c) 2020 Andrea Finollo

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

