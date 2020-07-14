
<p align="center">
  <img width="200" height="200" src="README/Icon.png">
</p>
<p><img src="https://img.shields.io/static/v1?label=platforms&message=iOS13&color=black"></p><p><img src="https://img.shields.io/static/v1?label=coverage&message=83%&color=yellowgreen"></p> <p><img src="https://img.shields.io/static/v1?label=carthage&message=compatible&color=green"> <img src="https://img.shields.io/static/v1?label=SwiftPM&message=compatible&color=green"></p>

  
  
# LITTLE BLUETOOTH
## INTRODUCTION
LittleBluetooth is a library that helps you developing applications that need to work with a bluetooth device.
It is written using `Swift` and the `Combine` framework thus is only compatible from iOS13 to upper version.
An instance of LittleBluetooth can control only one peripheral, you can use more instances as many peripheral you need, but first read this [answer](https://developer.apple.com/forums/thread/20810) on Apple forums to understand the impact of having more `CBCentralManager` instances.
The library is still on development so use at own you risk.

## INSTALLATION
### Carthage
Add the following to your Cartfile:

```
github "DrAma999/LittleBlueTooth" ~> 0.1.0
```

The library has a sub-dependency with Nordic library [Core Bluetooth Mock](https://github.com/NordicSemiconductor/IOS-CoreBluetooth-Mock) that helped me in creating unit tests, if you want to launch unit tests you must add this to your dependencies. Unforutnately at the moment the nordic library supports only SwiftPM and Cocoapods.

## FEATURES
* Built on top of combine
* Deploys on **iOS**
* Chainable operations: scan, connect, start listen, stop listen and read/write . Each operation is executed serially without having to worry in dealing with delegates
* Peripheral state and bluetooth state observation. You can watch the bluetooth state and also the peripheral state for a more fine grained control in the UI. Of course those information are also checked before starting any operation.
* Single notification channel: you can subscribe to the notification channel to receive all the data of the enabled characteristics. Of course you have also single and connectable publishers.
* Write and listen (or better listen and write): sometimes you need to write a command and get a “response” right away
* Initialization operations: sometimes you want to perform some bluetooth commands right after a connection, for instance an authentication, and you want to perform that before another operation have access to the peripheral.
* Readable and Writable characteristics: basically those two protocols will deal in reading a `Data` object to the concrete type you want or writing your concrete type into a `Data` object.
* Simplified `Error` normalization and if you want more you can always access the inner `CBError`
* Code coverage > 80%

## HOW TO USE IT
### Scan
You can scan with or without a timeout, after a timeout you receive a .scanTimeout error. Note that each peripheral found is published to the subscribers chain until you stop the scan request or you connect to a device (when you connect scan is automatically suspended.
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
        .flatMap{ (discovery) -> AnyPublisher<Void, LittleBluetoothError> in
            print("Discovery: \(discovery)")
            return self.littleBT.stopDiscovery()
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

The scan process is automatically stopped one you start the connection command.
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

For example here I’m declaring and Acceleration struct that contains acceleration data from a sensor.

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

After that is just a matter of call the read method.

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
        .flatMap{_ in
            self.littleBT.read(from: self.littleChar, forType: Acceleration.self)
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
You can listen to a charcteristic in few different ways.

_Listen_:

After creating your `LittleCharacteristic` instance, then send the `startListen(from:forType:)` and attach the subscriber. Of course the object you want to read must conform the `Readable` object.
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
.flatMap{_ in
    self.littleBT.startListen(from: self.littleChar, forType: Acceleration.self)
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
Now, it's your responsability to filter and converting `Data` object from `CBCharacteristic` to you type.
```
// First publisher
littleBT.listenPublisher
.filter { charact -> Bool in
        charact.uuid == charateristicOne.characteristic
}
.tryMap { (characteristic) -> ButtonState in
    guard let data = characteristic.value else {
        throw LittleBluetoothError.emptyData
    }
    return try ButtonState(from: data)
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
        charact.uuid == charateristicTwo.characteristic
}
.tryMap { (characteristic) -> LedState in
    guard let data = characteristic.value else {
        throw LittleBluetoothError.emptyData
    }
    return try LedState(from: data)
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
    self.littleBT.startListen(from: charateristicOne)
}
.flatMap { periph in
    self.littleBT.startListen(from: charateristicTwo)
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
* `.connected(PeripheralIdentifier)`: when a peripheral is connected after a `connect` command
* `.autoConnected(CBPeripheral)`: when a peripheral is connected automatically this event is triggered when you use the  `autoconnectionHandler`
* `.connectionFailed(CBPeripheral, error: LittleBluetoothError?)`: when during a connection something goes wrong
* `.disconnected(CBPeripheral, error: LittleBluetoothError?)`: when a peripheral ha been disconnected could be from an explicit disconnection or unexpected disconnection

_Peripheral state observer_:

It can be used for more fine grained control over peripheral states, they comes from the `CBPeripheralStates`

### Initialization operations
Sometimes after a connection you need to perform some repetitive task, for instance an authetication by sending a key or a NONCE.
This operations are stored inside the `connectionTasks` property and excuted after a connection normal or from an autoconnection. All other operations will be excuted after this has been done.

### Autoconnection
The autoconnection is managed by the `autoconnectionHandler` handler.
You can inspect the error and decide if an automatic connection is necessary.
If you return `true` the connection process will start, once the peripheral has been found a connection will be established. If you return `false` iOS will not try to establish a connection.
Connection process will remain active also in background if the app has the right
permission, to cancel just call `disconnect`.
When a connection will be established an `.autoConnected(PeripheralIdentifier)` event will be streamed to the `connectionEventPublisher`
If you want to cancel it you have to send an explicit disconnection.

Autoconnection will be interrupted in these condition:
App Permission | Conditions
------------ | -------------
App has no BT permission to run in bkg | Explicit disconnection, App killed by user/system, when suspended
App has  BT permission to run in bkg | Explicit disconnection, App killed by user/system

## ROADMAP
- [x] SwiftPM support
- [ ] State preservation and state restoration
- [ ] Improve code coverage
- [ ] `CBManager` and `CBPeripheral` extraction
- [ ] Add multiple peripheral support
- [ ] Add support to: **macOS**, **watchOS**, **tvOS**

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

