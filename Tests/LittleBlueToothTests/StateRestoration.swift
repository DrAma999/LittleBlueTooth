//
//  StateRestoration.swift
//  LittleBlueToothTests
//
//  Created by Andrea Finollo on 15/07/2020.
//

import XCTest
import Combine
import CoreBluetoothMock
@testable import LittleBlueToothForTest


class StateRestoration: LittleBlueToothTests {
    let fakeCBUUID = CBUUID(nsuuid: UUID())

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try super.setUpWithError()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testStateRestore() {
        let discoveryExpectation = expectation(description: "Discovery expectation")

        blinky.simulateProximityChange(.immediate)
        
        var littleBTConf = LittleBluetoothConfiguration()
        littleBTConf.centralManagerOptions = [CBMCentralManagerOptionRestoreIdentifierKey : "myIdentifier"]
        littleBT = LittleBlueTooth(with: littleBTConf)
        
        var periph: [PeripheralIdentifier]?
        var scanOptions: [String : Any]?
        var scanServices: [CBUUID]?
        
        var discoveredPeri: CBPeripheral?
        littleBT.startDiscovery(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : false])
            .sink(receiveCompletion: { completion in
                print("Completion \(completion)")
            }) { (discov) in
                print("Discovery \(discov)")
                discoveredPeri = discov.cbPeripheral
                self.littleBT.stopDiscovery()
                    .sink(receiveCompletion: {_ in
                    }) { () in
                        discoveryExpectation.fulfill()
                }
                .store(in: &self.disposeBag)
        }
        .store(in: &disposeBag)
                
        waitForExpectations(timeout: 10)
        
        let restoreExpectation = expectation(description: "State restoration")

        CBMCentralManagerFactory.simulateStateRestoration = { (identifier) -> [String : Any]  in
            return [
                CBCentralManagerRestoredStatePeripheralsKey : [discoveredPeri],
                CBCentralManagerRestoredStateScanOptionsKey : [CBCentralManagerScanOptionAllowDuplicatesKey : false],
                CBCentralManagerRestoredStateScanServicesKey : [self.fakeCBUUID]
            ]
        }

        littleBTConf = LittleBluetoothConfiguration()
        littleBTConf.restoreHandler = { restore in
            print("Restorer \(restore)")
        }
        littleBTConf.centralManagerOptions = [CBMCentralManagerOptionRestoreIdentifierKey : "myIdentifier"]
        littleBT = LittleBlueTooth(with: littleBTConf)
        
        littleBT.restoreStatePublisher
            .sink { (restorer) in
                print(restorer)
                periph = restorer.peripherals
                scanOptions = restorer.scanOptions
                scanServices = restorer.services
                restoreExpectation.fulfill()
        }
        .store(in: &disposeBag)
        
        waitForExpectations(timeout: 10)

        XCTAssertNotNil(periph)
        XCTAssertNotNil(scanOptions)
        XCTAssertNotNil(scanServices)
        XCTAssert(scanServices!.count == 1)
        XCTAssert(scanServices!.first! == fakeCBUUID)
        XCTAssert((scanOptions![CBCentralManagerScanOptionAllowDuplicatesKey] as! Bool) == false)

    }
}
