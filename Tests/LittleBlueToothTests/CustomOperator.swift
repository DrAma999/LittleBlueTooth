//
//  CustomOperator.swift
//  LittleBlueToothTests
//
//  Created by Andrea Finollo on 27/08/2020.
//

import XCTest
import CoreBluetoothMock
import Combine
@testable import LittleBlueToothForTest

class CustomOperator: LittleBlueToothTests {

   override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try super.setUpWithError()
        littleBT = LittleBlueTooth(with: LittleBluetoothConfiguration())
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /// Connection custom operator test
    func testConnectionOperatorFromScanDiscovery() {
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.immediate)
        let connectionExpectation = expectation(description: "Connection expectation")
        
        var connectedPeripheral: Peripheral?
        
        StartLittleBlueTooth
        .startDiscovery(for: self.littleBT, withServices: nil)
        .connect(for: self.littleBT)
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (connectedPeriph) in
            print("Discovery \(connectedPeriph)")
            connectedPeripheral = connectedPeriph
            self.littleBT.disconnect()
            .delay(for: .seconds(5), scheduler: DispatchQueue.global())
            .sink(receiveCompletion: { _ in
            }) { _ in
                connectionExpectation.fulfill()
            }
            .store(in: &self.disposeBag)
        }
        .store(in: &disposeBag)
        
        waitForExpectations(timeout: 15)
        XCTAssertNotNil(connectedPeripheral)
        XCTAssertEqual(connectedPeripheral!.cbPeripheral.identifier, blinky.identifier)
    }
    
    /// Connection custom operator test
    func testConnectionOperatorFromPeriphIdentifier() {
        disposeBag.removeAll()
        blinkyWOR.simulateProximityChange(.outOfRange)
        blinky.simulateProximityChange(.immediate)
        let connectionExpectation = expectation(description: "Connection identifier expectation")
        
        var connectedPeripheral: Peripheral?
        
        StartLittleBlueTooth
        .startDiscovery(for: self.littleBT, withServices: nil)
        .prefix(1)
        .map{ PeripheralIdentifier(peripheral: $0.cbPeripheral)}
        .connect(for: self.littleBT)
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (connectedPeriph) in
            print("Discovery \(connectedPeriph)")
            connectedPeripheral = connectedPeriph
            self.littleBT.disconnect()
            .delay(for: .seconds(5), scheduler: DispatchQueue.global())
            .sink(receiveCompletion: { _ in
            }) { _ in
                connectionExpectation.fulfill()
            }
            .store(in: &self.disposeBag)
        }
        .store(in: &disposeBag)
        
        waitForExpectations(timeout: 15)
        XCTAssertNotNil(connectedPeripheral)
        XCTAssertEqual(connectedPeripheral!.cbPeripheral.identifier, blinky.identifier)
    }
    
    /// Scan e Stop custom operator test
    func testScanStopOperatorFromScanDiscovery() {
        disposeBag.removeAll()
        blinkyWOR.simulateProximityChange(.immediate)
        blinky.simulateProximityChange(.immediate)
        let scanExpectation = expectation(description: "Scanning expectation")
        scanExpectation.expectedFulfillmentCount = 2
        var isStopped = false
        var periphCounter = 0
        
        StartLittleBlueTooth
        .startDiscovery(for: self.littleBT, withServices: nil)
        .map { periph in
           periphCounter += 1
        }
        .delay(for: .seconds(5), scheduler: DispatchQueue.global())
        .stopDiscovery(for: self.littleBT)
        .map {
           isStopped = true
        }
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (_) in
            print("Stopped")
            blinkyWOR.simulateProximityChange(.outOfRange)
            scanExpectation.fulfill()
        }
        .store(in: &disposeBag)
        
        waitForExpectations(timeout: 15)
        XCTAssertTrue(isStopped)
        XCTAssertTrue(periphCounter == 2)
    }
    
    /// ReadRSSI custom operator test
    func testPeripheralConnectionReadRSSIOperator() {
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.near)
        let readRSSIExpectation = expectation(description: "Read RSSI expectation")
        
        var rssiRead: Int?
        
        StartLittleBlueTooth
        .startDiscovery(for: self.littleBT, withServices: nil)
        .connect(for: self.littleBT)
        .readRSSI(for: self.littleBT)
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (rssi) in
            print("RSSI \(rssi)")
            rssiRead = rssi
            self.littleBT.disconnect().sink(receiveCompletion: { _ in
            }) { _ in
                readRSSIExpectation.fulfill()
            }
            .store(in: &self.disposeBag)
        }
        .store(in: &disposeBag)
        
        waitForExpectations(timeout: 15)
        XCTAssertNotNil(rssiRead)
        XCTAssert(rssiRead! < 70)
        
    }
    
    /// Disconnection custom operator test
    func testDisconnectionOperator() {
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.immediate)
        
        let disconnectionExpectation = expectation(description: "Disconnection expectation")
        var isDisconnected = false
        
        StartLittleBlueTooth
        .startDiscovery(for: self.littleBT, withServices: nil)
        .connect(for: littleBT)
        .delay(for: .seconds(5), scheduler: DispatchQueue.global())
        .disconnect(for: littleBT)
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (disconnectedPeriph) in
            print("Disconnection \(disconnectedPeriph)")
            isDisconnected = true
            disconnectionExpectation.fulfill()
        }
        .store(in: &disposeBag)
        
        waitForExpectations(timeout: 30)
        XCTAssert(isDisconnected)
    }
    
    
    /// Read custom operator test
    func testReadLedOFFOperator() {
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.immediate)
        let charateristic = LittleBlueToothCharacteristic(characteristic: CBUUID.ledCharacteristic.uuidString, for: CBUUID.nordicBlinkyService.uuidString, properties: [.read, .notify, .write])
        let readExpectation = expectation(description: "Read expectation")
        
        var ledState: LedState?
        
        StartLittleBlueTooth
        .startDiscovery(for: self.littleBT, withServices: nil)
        .connect(for: self.littleBT)
        .read(for: self.littleBT, from: charateristic)
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (answer: LedState) in
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
    
    /// Read custom operator test fail for wrong charcteriscti
    func testWrongCharacteristicErrorOperator() {
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.immediate)
        let charateristic = LittleBlueToothCharacteristic(characteristic: "00001525-1212-EFDE-1523-785FEABCD133", for: CBUUID.nordicBlinkyService.uuidString, properties: [.read, .notify, .write])
        let wrongCharacteristicExpectation = expectation(description: "Wrong characteristic expectation")

        var isWrong = false
        
        StartLittleBlueTooth
        .startDiscovery(for: self.littleBT, withServices: nil)
        .connect(for: self.littleBT)
        .read(for: self.littleBT, from: charateristic)
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
            switch completion {
            case .finished:
                break
            case let .failure(error):
                if case LittleBluetoothError.characteristicNotFound(_) = error {
                    isWrong = true
                    self.littleBT.disconnect().sink(receiveCompletion: {_ in
                    }) { (_) in
                        wrongCharacteristicExpectation.fulfill()
                    }
                    .store(in: &self.disposeBag)
                }
            }
        }) { (answer: LedState) in
            print("Answer \(answer)")
        }
        .store(in: &disposeBag)
        
        waitForExpectations(timeout: 10)
        XCTAssert(isWrong)
    }
    
    /// Write custom operator test
    func testWriteLedOnReadLedONOperator() {
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.immediate)
        let charateristic = LittleBlueToothCharacteristic(characteristic: CBUUID.ledCharacteristic.uuidString, for: CBUUID.nordicBlinkyService.uuidString, properties: [.read, .notify, .write])
        let readExpectation = expectation(description: "Read expectation")
        
        var ledState: LedState?
        
        StartLittleBlueTooth
            .startDiscovery(for: self.littleBT, withServices: nil)
            .connect(for: self.littleBT)
            .write(for: self.littleBT, from: charateristic, value: Data([0x01]))
            .read(for: self.littleBT, from: charateristic)
            .sink(receiveCompletion: { completion in
                print("Completion \(completion)")
            }) { (answer: LedState) in
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
    
    /// Write and listen custom operator test
    func testWriteAndListenOperator() {
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.immediate)
        let charateristic = LittleBlueToothCharacteristic(characteristic: CBUUID.ledCharacteristic.uuidString, for: CBUUID.nordicBlinkyService.uuidString, properties: [.read, .notify, .write])
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
        
        StartLittleBlueTooth
        .startDiscovery(for: self.littleBT, withServices: nil)
        .prefix(1)
        .connect(for: self.littleBT)
        .writeAndListen(for: self.littleBT, from: charateristic, value: Data([0x01]))
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
    /// Listen custom operator test
    func testListenOperator() {
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.immediate)
        let charateristic = LittleBlueToothCharacteristic(characteristic: CBMUUID.buttonCharacteristic.uuidString, for: CBMUUID.nordicBlinkyService.uuidString, properties: [.read, .notify])
        let listenExpectation = expectation(description: "Listen expectation")
        
        var listenCounter = 0
        var timerCounter = 0
        let timer = Timer.publish(every: 1, on: .main, in: .common)
        let scheduler: AnyCancellable =
        timer
        .map {_ in
            blinky.simulateValueUpdate(Data([0x01]), for: CBMCharacteristicMock.buttonCharacteristic)
            timerCounter += 1
        }.sink { value in
            print("Led value:\(value)")
        }
        
        StartLittleBlueTooth
        .startDiscovery(for: self.littleBT, withServices: nil)
        .connect(for: self.littleBT)
        .startListen(for: self.littleBT, from: charateristic)
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (answer: LedState) in
            listenCounter += 1
            print("Answer \(answer)")
            if listenCounter > 10 {
                scheduler.cancel()
                self.littleBT.disconnect().sink(receiveCompletion: {_ in
                }) { (_) in
                    listenExpectation.fulfill()
                }
                .store(in: &self.disposeBag)
            }
        }
        .store(in: &disposeBag)
        _ = timer.connect()

        waitForExpectations(timeout: 20)
        XCTAssert(listenCounter == timerCounter)
    }
    /// Enable Listen custom operator test
    func testListenToMoreCharacteristicOperator() {
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.immediate)
        let charateristicOne = LittleBlueToothCharacteristic(characteristic: CBMUUID.buttonCharacteristic.uuidString, for: CBMUUID.nordicBlinkyService.uuidString, properties: [.read, .notify])
        let charateristicTwo = LittleBlueToothCharacteristic(characteristic: CBMUUID.ledCharacteristic.uuidString, for: CBMUUID.nordicBlinkyService.uuidString, properties: [.read, .notify, .write])
        // Expectation
        let firstListenExpectation = XCTestExpectation(description: "First sub more expectation")
        let secondListenExpectation = XCTestExpectation(description: "Second sub more expectation")
        var sub1Event = [Bool]()
        var sub2Event = [Bool]()
        var firstCounter = 0
        var secondCounter = 0
        // Simulate notification
        var timerCounter = 0
        let timer = Timer.publish(every: 1, on: .main, in: .common)
        let scheduler: AnyCancellable = timer
            .map {_ -> UInt8 in
                var data = UInt8.random(in: 0...1)
                blinky.simulateValueUpdate(Data([data]), for: CBMCharacteristicMock.buttonCharacteristic)
                data = UInt8.random(in: 0...1)
                blinky.simulateValueUpdate(Data([data]), for: CBMCharacteristicMock.ledCharacteristic)
                timerCounter += 1
                return data
        }.sink { value in
            print("Sink from timer value:\(value)")
        }
        
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
                if firstCounter == 10 {
                    scheduler.cancel()
                    return
                } else {
                    sub1Event.append(answer.isOn)
                    firstCounter += 1
                }
        }
        .store(in: &self.disposeBag)
        
        // Second publisher
        littleBT.listenPublisher
        .filter { charact -> Bool in
            charact.id == charateristicTwo.id
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
                if secondCounter == 10 {
                    return
                } else {
                    sub2Event.append(answer.isOn)
                    secondCounter += 1
                }
        }
        .store(in: &self.disposeBag)

        StartLittleBlueTooth
        .startDiscovery(for: self.littleBT, withServices: nil)
        .connect(for: self.littleBT)
        .enableListen(for: self.littleBT, from: charateristicOne)
        .enableListen(for: self.littleBT, from: charateristicTwo)
        .delay(for: .seconds(20), scheduler: DispatchQueue.global())
        .disableListen(for: self.littleBT, from: charateristicOne)
        .disableListen(for: self.littleBT, from: charateristicTwo)
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (_) in
            secondListenExpectation.fulfill()
            firstListenExpectation.fulfill()
        }
        .store(in: &disposeBag)
        _ = timer.connect()
        
        wait(for: [firstListenExpectation, secondListenExpectation], timeout: 30)
        littleBT.disconnect()
        XCTAssert(sub1Event.count == sub2Event.count)
        XCTAssert(timerCounter - 1 == sub1Event.count)
    }

}
