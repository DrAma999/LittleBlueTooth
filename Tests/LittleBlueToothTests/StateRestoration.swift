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
        let peri = FakePeriph()
        CBMCentralManagerFactory.simulateStateRestoration = { (identifier) -> [String : Any]  in
            return [ CBCentralManagerRestoredStatePeripheralsKey : [peri] ]
        }
      
       
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testStateRestore() {
        let restoreExpectation = expectation(description: "State restoration")

        var littleBTConf = LittleBluetoothConfiguration()
        littleBTConf.centralManagerOptions = [CBMCentralManagerOptionRestoreIdentifierKey : "myIdentifier"]
        littleBT = LittleBlueTooth(with: littleBTConf)
        
        littleBT.restoreStatePublisher
        .sink { (restorer) in
            print(restorer)
            restoreExpectation.fulfill()
        }
        
        
        waitForExpectations(timeout: 10)
    }
}
