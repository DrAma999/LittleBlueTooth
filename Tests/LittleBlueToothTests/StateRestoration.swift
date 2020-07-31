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
        let peri = FakePeriph()
        
        CBMCentralManagerFactory.simulateStateRestoration = { (identifier) -> [String : Any]  in
            return [ CBCentralManagerRestoredStatePeripheralsKey : [peri],
                     CBCentralManagerRestoredStateScanOptionsKey : [CBCentralManagerScanOptionAllowDuplicatesKey : false],
                     CBCentralManagerRestoredStateScanServicesKey : [self.fakeCBUUID]
            ]
        }
      
       
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testStateRestore() {
        // Cannot simulate the restore of peripheral since all in CentralRestore I check against the retrive peripheral that must be of CBPeripheral type
        let restoreExpectation = expectation(description: "State restoration")
        
        var periph: [PeripheralIdentifier]? = nil
        var scanOptions: [String : Any]? = nil
        var scanServices: [CBUUID]? = nil
        
        var littleBTConf = LittleBluetoothConfiguration()
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
