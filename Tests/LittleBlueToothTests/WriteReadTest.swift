//
//  ReadTest.swift
//  LittleBlueToothTests
//
//  Created by Andrea Finollo on 29/06/2020.
//  Copyright © 2020 Andrea Finollo. All rights reserved.
//

import XCTest
import Combine
import CoreBluetoothMock
@testable import LittleBlueToothForTest

struct LedState: Readable {
    let isOn: Bool

    init(from data: Data) throws {
        let answer: Bool = try data.extract(start: 0, length: 1)
        self.isOn = answer
    }
    
}

class ReadWriteTest: LittleBlueToothTests {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try super.setUpWithError()
        var configuration = LittleBluetoothConfiguration()
        configuration.isLogEnabled = true
        littleBT = LittleBlueTooth(with: configuration)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testWrongServiceError() {
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.immediate)
        let charateristic = LittleBlueToothCharacteristic(characteristic: CBMUUID.ledCharacteristic.uuidString, for: "10001523-1212-EFDE-1523-785FEABCD123", properties: [.notify, .read, .write])

        let wrongServiceExpectation = expectation(description: "Wrong service expectation")
        
        var isWrong = false
        
        littleBT.startDiscovery(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : false])
            .map { disc -> PeripheralDiscovery in
                print("Discovery discovery \(disc)")
                return disc
        }
        .flatMap { discovery in
            self.littleBT.connect(to: discovery)
        }
        .flatMap { _ -> AnyPublisher<LedState, LittleBluetoothError> in
            self.littleBT.read(from: charateristic)
        }
        .sink(receiveCompletion: { (completion) in
            print("Completion \(completion)")
            switch completion {
            case .finished:
                break
            case let .failure(error):
                if case LittleBluetoothError.serviceNotFound(_) = error {
                    isWrong = true
                    self.littleBT.disconnect().sink(receiveCompletion: {_ in
                    }) { (_) in
                        wrongServiceExpectation.fulfill()
                    }
                    .store(in: &self.disposeBag)
                } else {
                    isWrong = false
                }
            }
        }) { (answer) in
            print("Answer \(answer)")
        }
        .store(in: &disposeBag)
        
        waitForExpectations(timeout: 30)
        XCTAssert(isWrong)
    }
    
    func testDiscoverServices() {
        blinky.simulateReset()
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.immediate)
        
        let discoverExpectation = expectation(description: "Discover services expectation")
        var servicesCount: Int?
        littleBT.startDiscovery(withServices: nil, options: [CBMCentralManagerScanOptionAllowDuplicatesKey : false])
        .map { disc -> PeripheralDiscovery in
                   print("Discovery discovery \(disc)")
                   return disc
        }
        .flatMap { discovery in
            self.littleBT.connect(to: discovery)
        }
        .flatMap { _ in
            self.littleBT.discover(nil)
        }
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (answer) in
            print("Answer \(answer)")
            servicesCount = answer?.count ?? 0
            self.littleBT.disconnect().sink(receiveCompletion: {_ in
            }) { (_) in
                discoverExpectation.fulfill()
            }
            .store(in: &self.disposeBag)
        }
        .store(in: &disposeBag)
        
        waitForExpectations(timeout: 100)
        XCTAssertNotNil(servicesCount)
        XCTAssert(servicesCount! == 1)
    }
    
    func testDiscoverCharacteristics() {
        blinky.simulateReset()
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.immediate)
        
        let discoverExpectation = expectation(description: "Discover characteristics expectation")
        var characteristicsCount: Int?
        littleBT.startDiscovery(withServices: nil, options: [CBMCentralManagerScanOptionAllowDuplicatesKey : false])
        .map { disc -> PeripheralDiscovery in
                   print("Discovery discovery \(disc)")
                   return disc
        }
        .flatMap { discovery in
            self.littleBT.connect(to: discovery)
        }
        .flatMap { _ in
            self.littleBT.discover(nil, from: CBMServiceMock.blinkyService)
        }
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (answer) in
            print("Answer \(answer)")
            characteristicsCount = answer?.count ?? 0
            self.littleBT.disconnect().sink(receiveCompletion: {_ in
            }) { (_) in
                discoverExpectation.fulfill()
            }
            .store(in: &self.disposeBag)
        }
        .store(in: &disposeBag)
        
        waitForExpectations(timeout: 100)
        XCTAssertNotNil(characteristicsCount)
        XCTAssert(characteristicsCount! == 2)
    }
    
    func testReadLedOFF() {
        blinky.simulateReset()
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.immediate)
        let charateristic = LittleBlueToothCharacteristic(characteristic: CBMUUID.ledCharacteristic.uuidString, for: CBMUUID.nordicBlinkyService.uuidString, properties: [.notify, .read, .write])
        let readExpectation = expectation(description: "Read expectation")
        
        var ledState: LedState?
        
        littleBT.startDiscovery(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : false])
        .map { disc -> PeripheralDiscovery in
                   print("Discovery discovery \(disc)")
                   return disc
        }
        .flatMap { discovery in
            self.littleBT.connect(to: discovery)
        }
        .flatMap { _ -> AnyPublisher<LedState, LittleBluetoothError> in
            self.littleBT.read(from: charateristic)
        }
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (answer) in
            print("Answer \(answer)")
            ledState = answer
            self.littleBT.disconnect().sink(receiveCompletion: {_ in
            }) { (_) in
                readExpectation.fulfill()
            }
            .store(in: &self.disposeBag)
        }
        .store(in: &disposeBag)
        
        waitForExpectations(timeout: 10)
        XCTAssertNotNil(ledState)
        XCTAssert(ledState!.isOn == false)
    }
    
    func testWriteLedOnReadLedON() {
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.immediate)
        let charateristic = LittleBlueToothCharacteristic(characteristic: CBMUUID.ledCharacteristic.uuidString, for: CBMUUID.nordicBlinkyService.uuidString, properties: [.notify, .read, .write])
        let readExpectation = expectation(description: "Read expectation")

        var ledState: LedState?
        
        littleBT.startDiscovery(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : false])
        .map { disc -> PeripheralDiscovery in
                   print("Discovery discovery \(disc)")
                   return disc
           }
        .flatMap { discovery in
            self.littleBT.connect(to: discovery)
        }
        .flatMap { _ in
            self.littleBT.write(to: charateristic, value: Data([0x01]))
        }
        .flatMap { _ -> AnyPublisher<LedState, LittleBluetoothError> in
            self.littleBT.read(from: charateristic)
        }
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (answer) in
            print("Answer \(answer)")
            ledState = answer
            self.littleBT.disconnect().sink(receiveCompletion: {_ in
            }) { (_) in
                readExpectation.fulfill()
            }
            .store(in: &self.disposeBag)

        }
        .store(in: &disposeBag)
         waitForExpectations(timeout: 10)
        XCTAssertNotNil(ledState)
        XCTAssert(ledState!.isOn == true)
    }

    
    func testWriteAndListen() {
        disposeBag.removeAll()
               
        blinky.simulateProximityChange(.immediate)
        let charateristic = LittleBlueToothCharacteristic(characteristic: CBMUUID.ledCharacteristic.uuidString, for: CBMUUID.nordicBlinkyService.uuidString, properties: [.notify, .read, .write])
        let writeAndListenExpectation = expectation(description: "Write and Listen")
        
        var ledState: LedState?
        
        Timer.publish(every: 0.5, on: .main, in: .common)
        .autoconnect()
        .map {_ in
            blinky.simulateValueUpdate(Data([0x01]),
                                           for: CBMCharacteristicMock.ledCharacteristic)
        }.sink { value in
            print("Led value:\(value)")
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
        .flatMap { _ in
            self.littleBT.writeAndListen(from: charateristic, value: Data([0x01]))
        }
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (answer: LedState) in
            print("Answer \(answer)")
            ledState = answer
            self.littleBT.disconnect().sink(receiveCompletion: {_ in
            }) { (_) in
                writeAndListenExpectation.fulfill()
            }
            .store(in: &self.disposeBag)
            
        }
        .store(in: &disposeBag)
         waitForExpectations(timeout: 10)
        XCTAssertNotNil(ledState)
        XCTAssert(ledState!.isOn == true)
    }
    
    func testMultipleRead() {
        blinky.simulateReset()
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.immediate)
        let ledCharateristic = LittleBlueToothCharacteristic(characteristic: CBUUID.ledCharacteristic.uuidString, for: CBUUID.nordicBlinkyService.uuidString, properties: [.read, .notify, .write])
        let buttonCharateristic = LittleBlueToothCharacteristic(characteristic: CBUUID.buttonCharacteristic.uuidString, for: CBUUID.nordicBlinkyService.uuidString, properties: [.read, .notify])
        let multipleReadExpectation = expectation(description: "Multiple read")
        
        var ledIsOff = false
        var buttonIsOff = false

        
        littleBT.startDiscovery(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : false])
        .map { disc -> PeripheralDiscovery in
            print("Discovery discovery \(disc)")
            return disc
        }
        .flatMap { discovery in
            self.littleBT.connect(to: discovery)
        }
        .flatMap { _ -> AnyPublisher<LedState, LittleBluetoothError> in
            self.littleBT.read(from: ledCharateristic)
        }
        .flatMap { led -> AnyPublisher<ButtonState, LittleBluetoothError> in
            ledIsOff = !led.isOn
            return self.littleBT.read(from: buttonCharateristic)
        }
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (button) in
            print("Answer \(button)")
            buttonIsOff = !button.isOn
            self.littleBT.disconnect().sink(receiveCompletion: {_ in
            }) { (_) in
                multipleReadExpectation.fulfill()
            }
            .store(in: &self.disposeBag)
        }
        .store(in: &disposeBag)
        
        waitForExpectations(timeout: 10)
        XCTAssert(buttonIsOff)
        XCTAssert(ledIsOff)
    }
    
    func testDisconnectionBeforeRead() {
        disposeBag.removeAll()

        blinky.simulateProximityChange(.immediate)
        let charateristic = LittleBlueToothCharacteristic(characteristic: CBMUUID.ledCharacteristic.uuidString, for: CBMUUID.nordicBlinkyService.uuidString, properties: [.notify, .read, .write])
        let disconnectionExpectation = expectation(description: "Disconnection before read")
        
        var isDisconnected = false

        littleBT.startDiscovery(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : false])
            .map { disc -> PeripheralDiscovery in
                print("Discovery discovery \(disc)")
                return disc
        }
        .flatMap { discovery in
            self.littleBT.connect(to: discovery)
        }
        .flatMap { _ -> AnyPublisher<LedState, LittleBluetoothError> in
            blinky.simulateDisconnection()
            return self.littleBT.read(from: charateristic)
        }
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
            switch completion {
            case .finished:
                break
            case let .failure(error):
                if case LittleBluetoothError.peripheralDisconnected(_, _) = error {
                    isDisconnected = true
                    disconnectionExpectation.fulfill()
                }
            }
        }) { (answer) in
            print("Answer \(answer)")
        }
        .store(in: &disposeBag)

        waitForExpectations(timeout: 10)
        XCTAssert(isDisconnected)
    }

}
