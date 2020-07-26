//
//  StateRestoration.swift
//  LittleBlueToothTests
//
//  Created by Andrea Finollo on 15/07/2020.
//

import XCTest
import Combine
import CoreBluetoothMock
@testable import LittleBlueTooth

class StateRestoration: LittleBlueToothTests {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try super.setUpWithError()
        CBMCentralManagerFactory.simulateStateRestoration = { (identifier) -> [String : Any]  in
            return [ CBCentralManagerRestoredStatePeripheralsKey : [blinky] ]
        }
      
       
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testStateRestore() {
        let wrongCharacteristicExpectation = expectation(description: "State restoration")

        var littleBTConf = LittleBluetoothConfiguration()
        littleBTConf.restoreHandler = { restored in
            print("restored \(restored)")
        }
        littleBTConf.centralManagerOptions = [CBMCentralManagerOptionRestoreIdentifierKey : "myIdentifier"]
        littleBT = LittleBlueTooth(with: littleBTConf)
        
        waitForExpectations(timeout: 10)
    }
}
