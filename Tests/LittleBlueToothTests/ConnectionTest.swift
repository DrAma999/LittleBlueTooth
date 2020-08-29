//
//  ConnectionTest.swift
//  LittleBlueToothTests
//
//  Created by Andrea Finollo on 29/06/2020.
//  Copyright © 2020 Andrea Finollo. All rights reserved.
//

import XCTest
import CoreBluetoothMock
import Combine
@testable import LittleBlueToothForTest

class ConnectionTest: LittleBlueToothTests {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try super.setUpWithError()
        littleBT = LittleBlueTooth(with: LittleBluetoothConfiguration())
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testPeripheralConnectionSuccess() {
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.immediate)
        let connectionExpectation = expectation(description: "Connection expectation")
        
        var connectedPeripheral: Peripheral?
        
        littleBT.startDiscovery(withServices: nil)
        .flatMap { discovery in
            self.littleBT.connect(to: discovery)
        }
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (connectedPeriph) in
            print("Discovery \(connectedPeriph)")
            connectedPeripheral = connectedPeriph
            self.littleBT.disconnect().sink(receiveCompletion: { _ in
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
    
    func testPeripheralConnectionReadRSSI() {
         disposeBag.removeAll()
         
         blinky.simulateProximityChange(.near)
         let readRSSIExpectation = expectation(description: "Read RSSI expectation")
         
         var rssiRead: Int?
         
         littleBT.startDiscovery(withServices: nil)
         .flatMap { discovery in
             self.littleBT.connect(to: discovery)
         }
         .flatMap{ _ in
            self.littleBT.readRSSI()
         }
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
    

    func testMultipleConnection() {
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.immediate)
        let connectionExpectation = expectation(description: "Multiple connection")
        
        var isAlreadyConnected = false
        
        littleBT.startDiscovery(withServices: nil)
        .flatMap { discovery in
            self.littleBT.connect(to: discovery).map {_ in discovery}
        }
        .flatMap { discovery in
            self.littleBT.connect(to: discovery)
        }
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
            switch completion {
            case .finished:
                break
            case let .failure(error):
                if case LittleBluetoothError.peripheralAlreadyConnectedOrConnecting(_) = error {
                    isAlreadyConnected = true
                    connectionExpectation.fulfill()
                    self.littleBT.disconnect()
                }
            }
        }) { (connectedPeriph) in
            print("Discovery \(connectedPeriph)")
        }
        .store(in: &disposeBag)
        waitForExpectations(timeout: 10)
        XCTAssert(isAlreadyConnected)
    }
    
    func testConnectionDisconnectionObserving() {
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.immediate)
        var connectionEvent = [ConnectionEvent]()
        var peripheralState = [PeripheralState]()
        let connectionExpectation = expectation(description: "Connection test")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(4)) {
            blinky.simulateDisconnection()
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
                connectionExpectation.fulfill()
            }
        }
        
        littleBT.startDiscovery(withServices: nil)
        .flatMap { discovery in
            self.littleBT.connect(to: discovery)
        }
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (connectedPeriph) in
            print("Discovery \(connectedPeriph)")
        }
        .store(in: &disposeBag)
        
        littleBT.connectionEventPublisher
        .sink { (event) in
            print("ConnectionEvent \(event)")
            connectionEvent.append(event)
        }
        .store(in: &disposeBag)
        
        littleBT.peripheralStatePublisher
        .sink { (state) in
            print("Peripheral state: \(state)")
            peripheralState.append(state)
        }
        .store(in: &disposeBag)

        waitForExpectations(timeout: 30)
        print("Connection disconnection event \(connectionEvent.count)")
        XCTAssert(connectionEvent.count == 3)

    }
    
    
    func testChangeDeviceName() {
        disposeBag.removeAll()

        blinky.simulateProximityChange(.immediate)

        let changeNameAndServiceExpectation = expectation(description: "Change name test")

        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(4)) {
            blinky.simulateServiceChange(newName: "pippo",
                                         newServices: [.blinkyService])
        }
        let charateristic = LittleBlueToothCharacteristic(characteristic: CBMUUID.ledCharacteristic.uuidString, for: CBMUUID.nordicBlinkyService.uuidString, properties: [.notify, .read, .write])


        littleBT.startDiscovery(withServices: nil)
        .flatMap { discovery in
            self.littleBT.connect(to: discovery)
        }
        .flatMap { _ -> AnyPublisher<LedState, LittleBluetoothError> in
            self.littleBT.read(from: charateristic)
        }
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (connectedPeriph) in
            print("Discovery \(connectedPeriph)")
        }
        .store(in: &disposeBag)

        littleBT.changesStatePublisher
            .sink { (state) in
                print("Peripheral state: \(state)")
                switch state {
                case let .invalidatedServices(services):
                    print("Invalidated services \(services)")
                case let .name(newName):
                    print("New Name: \(String(describing: newName))")
                    self.littleBT.disconnect()
                    changeNameAndServiceExpectation.fulfill()
                }
        }
        .store(in: &disposeBag)

        waitForExpectations(timeout: 30)
    }
    
    
    func testDisconnection() {
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.immediate)
        
        let disconnectionExpectation = expectation(description: "Disconnection expectation")
        
        var isDisconnected = false
        
        
        littleBT.startDiscovery(withServices: nil)
        .flatMap { discovery in
            self.littleBT.connect(to: discovery)
        }
        .flatMap { _ in
            self.littleBT.disconnect()
        }
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (disconnectedPeriph) in
            print("Disconnection \(disconnectedPeriph)")
            isDisconnected = true
            disconnectionExpectation.fulfill()
        }
        .store(in: &disposeBag)
        
        waitForExpectations(timeout: 10)
        XCTAssert(isDisconnected)
    }
    
    
    func testAutoConnection() {
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.immediate)
        var connectionEvent = [ConnectionEvent]()
        var peripheralState = [PeripheralState]()
        let connectionExpectation = expectation(description: "Connection test")
        littleBT.autoconnectionHandler = { (peripheral, error) -> Bool in
            return true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
            blinky.simulateReset()
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(10)) {
                connectionExpectation.fulfill()
            }
        }
        
        littleBT.startDiscovery(withServices: nil)
        .flatMap { discovery in
                self.littleBT.connect(to: discovery)
        }
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (connectedPeriph) in
            print("Discovery \(connectedPeriph)")
        }
        .store(in: &disposeBag)
        
        littleBT.connectionEventPublisher
            .sink { (event) in
                print("ConnectionEvent \(event)")
                connectionEvent.append(event)
        }
        .store(in: &disposeBag)
        
        littleBT.peripheralStatePublisher
            .sink { (state) in
                print("Peripheral state: \(state)")
                peripheralState.append(state)
        }
        .store(in: &disposeBag)
        
        waitForExpectations(timeout: 100)
        self.littleBT.autoconnectionHandler = nil
        self.littleBT.disconnect()
        print("Autoconn event \(connectionEvent.count)")
        XCTAssert(connectionEvent.count == 5)
    }
    
    func testPeripheralConnectionInitializationSuccess() {
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.immediate)
        let connectionExpectation = expectation(description: "Connection expectation")
        let charateristic = LittleBlueToothCharacteristic(characteristic: CBMUUID.ledCharacteristic.uuidString, for: CBMUUID.nordicBlinkyService.uuidString, properties: [.notify, .read, .write])

        var ledState: LedState?

        littleBT.connectionTasks = Just(()).setFailureType(to: LittleBluetoothError.self)
        .flatMap{ _ -> AnyPublisher<LedState, LittleBluetoothError> in
            self.littleBT.read(from: charateristic)
        }.map { state in
            ledState = state
            return ()
        }.eraseToAnyPublisher()
        
        
        var connectedPeripheral: Peripheral?
        
        littleBT.startDiscovery(withServices: nil)
        .flatMap { discovery in
            self.littleBT.connect(to: discovery)
        }
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (connectedPeriph) in
            print("Discovery \(connectedPeriph)")
            connectedPeripheral = connectedPeriph
            self.littleBT.disconnect().sink(receiveCompletion: { _ in
            }) { _ in
                connectionExpectation.fulfill()
            }
            .store(in: &self.disposeBag)
        }
        .store(in: &disposeBag)
        
        waitForExpectations(timeout: 15)
        littleBT.connectionTasks = nil
        XCTAssertNotNil(connectedPeripheral)
        XCTAssertNotNil(ledState)
        XCTAssert(!ledState!.isOn)
        XCTAssertEqual(connectedPeripheral!.cbPeripheral.identifier, blinky.identifier)
    }
    
    func testConnectionFailed() {
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.immediate)
        blinky.simulateReset()

        let foundExpectation = XCTestExpectation(description: "Device found expectation")
        
        var discovery: PeripheralDiscovery?
        
        littleBT.startDiscovery(withServices: nil)
            .sink(receiveCompletion: { completion in
                print("Completion \(completion)")
            }) { (disc) in
                print("Discovery \(disc)")
                discovery = disc
                foundExpectation.fulfill()
        }
        .store(in: &disposeBag)
        wait(for: [foundExpectation], timeout: 3)
        XCTAssertNotNil(discovery)
        
        blinky.simulateProximityChange(.outOfRange)
        // Should never happen
        let connected = XCTestExpectation(description: "Connected expectation")
        connected.isInverted = true
        
        littleBT.connect(to: discovery!)
        .sink(receiveCompletion: { (completion) in
            print("Completion \(completion)")
        }) { (periph) in
            print("Peripheral \(periph)")
            connected.fulfill()
        }
        .store(in: &disposeBag)
        
        wait(for: [connected], timeout: 3)
        littleBT.disconnect()
    }
}
