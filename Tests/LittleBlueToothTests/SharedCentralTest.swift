//
//  SharedCentralTest.swift
//  LittleBlueToothTests
//
//  Created by Andrea Finollo on 02/09/2020.
//

import XCTest
import CoreBluetoothMock
import Combine
@testable import LittleBlueToothForTest

class SharedCentralTest: LittleBlueToothTests {
    var littleBT2: LittleBlueTooth!
    override func setUpWithError() throws {
        try super.setUpWithError()
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    // Try multiple scan with same manager
    func testSharedConnection() {
        
        disposeBag.removeAll()
        
        var littleBTConfOne = LittleBluetoothConfiguration()
        littleBTConfOne.mode = .shared
        
        var littleBTConfTwo = LittleBluetoothConfiguration()
        littleBTConfTwo.mode = .shared
        
        littleBT = LittleBlueTooth(with: littleBTConfOne)
        littleBT2 = LittleBlueTooth(with: littleBTConfTwo)
        
        blinkyWOR.simulateProximityChange(.immediate)
        blinky.simulateProximityChange(.immediate)
        
        let connectionExpectationOne = expectation(description: "Connection One identifier expectation")
        let connectionExpectationTwo = expectation(description: "Connection Two identifier expectation")

        var connectedPeripheralOne: Peripheral?
        var connectedPeripheralTwo: Peripheral?
        
        
        func secondConnection() {
            StartLittleBlueTooth
                .startDiscovery(for: littleBT2, withServices: [CBUUID.nordicBlinkyService])
                .filter{ (discovery) -> Bool in
                    if discovery.name! == "nRF Blinky" {
                        return true
                    }
                    return false
            }
            .connect(for: littleBT2)
            .delay(for: .seconds(5), scheduler: DispatchQueue.global())
            .sink(receiveCompletion: { completion in
                print("Completion \(completion)")
            }) { (connectedPeriph) in
                print("Periph2 \(connectedPeriph)")
                connectedPeripheralTwo = connectedPeriph
                self.littleBT2.disconnect()
                    .delay(for: .seconds(7), scheduler: DispatchQueue.global())
                    .sink(receiveCompletion: { _ in
                    }) { _ in
                        connectionExpectationTwo.fulfill()
                }
                .store(in: &self.disposeBag)
            }
            .store(in: &disposeBag)
        }
        
        StartLittleBlueTooth
            .startDiscovery(for: littleBT, withServices: [CBUUID.nordicBlinkyService])
            .filter{ (discovery) -> Bool in
                if discovery.name! == "nRF Blinky WO" {
                    return true
                }
                return false
        }
        .connect(for: littleBT)
        .delay(for: .seconds(5), scheduler: DispatchQueue.global())
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (connectedPeriph) in
            print("Periph1 \(connectedPeriph)")
            connectedPeripheralOne = connectedPeriph
            secondConnection()
            self.littleBT.disconnect()
                .delay(for: .seconds(3), scheduler: DispatchQueue.global())
                .sink(receiveCompletion: { _ in
                }) { _ in
                    connectionExpectationOne.fulfill()
            }
            .store(in: &self.disposeBag)
        }
        .store(in: &disposeBag)
        
       
        
        wait(for: [connectionExpectationTwo, connectionExpectationOne], timeout: 200)
        
        XCTAssertNotNil(connectedPeripheralTwo)
        XCTAssertNotNil(connectedPeripheralOne)
        XCTAssert(connectedPeripheralOne!.name! == "nRF Blinky WO")
        XCTAssert(connectedPeripheralTwo!.name! == "nRF Blinky")

    }
    
}
