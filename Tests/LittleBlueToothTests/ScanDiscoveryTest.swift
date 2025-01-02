//
//  ScanDiscoveryTest.swift
//  LittleBlueToothTests
//
//  Created by Andrea Finollo on 26/06/2020.
//  Copyright © 2020 Andrea Finollo. All rights reserved.
//

import XCTest
import Combine
import CoreBluetoothMock
@testable import LittleBlueToothForTest

class ScanDiscoveryTest: LittleBlueToothTests {
    

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


    func testPeripheralDiscoveryPowerOn() {
        disposeBag.removeAll()

        blinky.simulateProximityChange(.immediate)

        let discoveryExpectation = expectation(description: "Discovery expectation")
        var discovery: PeripheralDiscovery?
        
        littleBT.startDiscovery(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : false])
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (discov) in
            print("Discovery \(discov)")
            discovery = discov
            self.littleBT.stopDiscovery()
            .sink(receiveCompletion: {_ in
            }) { () in
                discoveryExpectation.fulfill()
            }
            .store(in: &self.disposeBag)
        }
        .store(in: &disposeBag)
        
        waitForExpectations(timeout: 10)
        XCTAssertNotNil(discovery)
        _ = discovery!.name
        let peripheral = discovery!.cbPeripheral
        let advInfo = discovery!.advertisement
        XCTAssertEqual(discovery!.cbPeripheral.identifier, blinky.identifier)
        XCTAssertEqual(peripheral.identifier, blinky.identifier)
        XCTAssertNotNil(advInfo)
    }
    
    
    func testPeripheralDiscoveryPowerOff() {
        disposeBag.removeAll()
        CBMCentralManagerMock.simulateInitialState(.poweredOff)
        
        blinky.simulateProximityChange(.immediate)
        
        let discoveryExpectation = expectation(description: "Discovery Expectation")
        var isPowerOff = false
        littleBT.startDiscovery(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : false])
        .sink(receiveCompletion: { completion in
                print("Completion \(completion)")
                switch completion {
                case .failure(let error):
                    isPowerOff = false
                    if case LittleBluetoothError.bluetoothPoweredOff = error {
                        isPowerOff = true
                    }
                    self.littleBT.stopDiscovery()
                    .sink(receiveCompletion: {_ in
                    }) { () in
                        discoveryExpectation.fulfill()
                    }
                    .store(in: &self.disposeBag)
                case .finished:
                    break
                }
            }) { (discovery) in
                print("Discovery \(discovery)")
        }
        .store(in: &disposeBag)
        
        waitForExpectations(timeout: 10)
        XCTAssertTrue(isPowerOff)
    }
    
    func testPeripheralDiscoveryStopScan() {
        disposeBag.removeAll()

        blinky.simulateProximityChange(.immediate)
        let discoveryExpectation = expectation(description: "Discovery Expectation")
        var isScanning = true

        littleBT.startDiscovery(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : false])
        .map { disc -> PeripheralDiscovery in
            print("Discovery discovery \(disc)")
            return disc
        }
        .flatMap {discovery in
            self.littleBT.stopDiscovery().map {discovery}
        }
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (answer) in
            print("Value \(answer)")
            isScanning = self.littleBT.cbCentral.isScanning
            discoveryExpectation.fulfill()
        }
        .store(in: &disposeBag)
        waitForExpectations(timeout: 10)
        XCTAssertFalse(isScanning)
    }
    
    func testPeripheralScanTimeout() {
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.outOfRange)
        let discoveryExpectation = expectation(description: "Discovery Expectation")

        var isScanTimeout = false
        let timeout = TimeInterval(3)
        littleBT.startDiscovery(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : false])
        .timeout(DispatchQueue.SchedulerTimeType.Stride(timeout.dispatchInterval), scheduler: DispatchQueue.main, options: nil, error: .scanTimeout)
        .flatMap { discovery in
            self.littleBT.connect(to: discovery)
        }
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
            switch completion {
            case .failure(let error):
                isScanTimeout = false
                if case LittleBluetoothError.scanTimeout = error {
                    isScanTimeout = true
                }
                discoveryExpectation.fulfill()
            case .finished:
                break
            }
        }) { (connectedPeriph) in
            print("Connected periph: \(connectedPeriph)")
        }
        .store(in: &disposeBag)
        wait(for: [discoveryExpectation], timeout: 15)
        
        XCTAssert(isScanTimeout)

    }
}
