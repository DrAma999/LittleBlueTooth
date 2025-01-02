//
//  Extraction.swift
//  LittleBlueToothTests
//
//  Created by Andrea Finollo on 09/08/2020.
//

import XCTest
@preconcurrency import CoreBluetoothMock
import Combine
@testable import LittleBlueToothForTest

class Extraction: LittleBlueToothTests {

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

    func testExtractionWithPeriph() {
        disposeBag.removeAll()
        var configuration = LittleBluetoothConfiguration()
        configuration.isLogEnabled = true
        littleBT = LittleBlueTooth(with: configuration)
    
        blinky.simulateProximityChange(.immediate)
        let extractionExpectation = expectation(description: "Extraction expectation")
        
        var connectedPeripheral: Peripheral?
        var extractedState: (central: CBCentralManager, peripheral: CBPeripheral?)?
        
        littleBT.startDiscovery(withServices: nil)
        .flatMap { discovery in
            self.littleBT.connect(to: discovery)
        }
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (connectedPeriph) in
            print("Discovery \(connectedPeriph)")
            connectedPeripheral = connectedPeriph
            // Extract state
            extractedState = self.littleBT.extract()
            extractionExpectation.fulfill()
        }
        .store(in: &disposeBag)
        
        waitForExpectations(timeout: 15)
        XCTAssertNotNil(connectedPeripheral)
        XCTAssertEqual(connectedPeripheral!.cbPeripheral.identifier, blinky.identifier)
        XCTAssertNotNil(extractedState)
        XCTAssertEqual(extractedState!.peripheral!.identifier, blinky.identifier)
        XCTAssertEqual(extractedState!.peripheral!.state, CBPeripheralState.connected)
        self.littleBT.disconnect()

    }

    func testExtractionWithoutPeriph() {
        disposeBag.removeAll()
        var configuration = LittleBluetoothConfiguration()
        configuration.isLogEnabled = true
        littleBT = LittleBlueTooth(with: configuration)
        
        let extractedState = self.littleBT.extract()
        
        XCTAssertNil(extractedState.peripheral)
        XCTAssertNotNil(extractedState.central)
    }
    
    func testRestart() {
        disposeBag.removeAll()
        var configuration = LittleBluetoothConfiguration()
        configuration.isLogEnabled = true
        littleBT = LittleBlueTooth(with: configuration)
        blinky.simulateDisconnection()
        blinky.simulateProximityChange(.immediate)
        let restartExpectation = expectation(description: "Restart expectation")
        
        var connectedPeripheral: Peripheral?
        var extractedState: (central: CBCentralManager, peripheral: CBPeripheral?)?
        
        littleBT.startDiscovery(withServices: nil)
        .flatMap { discovery in
            self.littleBT.connect(to: discovery)
        }
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (connectedPeriph) in
            print("Discovery \(connectedPeriph)")
            connectedPeripheral = connectedPeriph
            // Extract state
            extractedState = self.littleBT.extract()
            XCTAssertNotNil(connectedPeripheral)
            XCTAssertEqual(connectedPeripheral!.cbPeripheral.identifier, blinky.identifier)
            XCTAssertNotNil(extractedState)
            XCTAssertEqual(extractedState!.peripheral!.identifier, blinky.identifier)
            self.littleBT.restart(with: extractedState!.central, peripheral: extractedState!.peripheral!)
            restartExpectation.fulfill()
        }
        .store(in: &disposeBag)
        
        waitForExpectations(timeout: 10)
        XCTAssertNotNil(littleBT.peripheral)
        self.littleBT.disconnect()
        
    }
}
