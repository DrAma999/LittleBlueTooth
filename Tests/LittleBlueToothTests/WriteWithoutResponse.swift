//
//  WriteWithoutResponse.swift
//  LittleBlueToothTests
//
//  Created by Andrea Finollo on 28/07/2020.
//

import XCTest
import CoreBluetoothMock
import Combine
@testable import LittleBlueToothForTest

class WriteWithoutResponse: LittleBlueToothTests {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try super.setUpWithError()
        var lttlCon = LittleBluetoothConfiguration()
        lttlCon.centralManagerQueue = DispatchQueue.global()
        littleBT = LittleBlueTooth(with: lttlCon)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

   func testWriteWOResponse() {
       disposeBag.removeAll()
       blinky.simulateProximityChange(.outOfRange)
       blinkyWOR.simulateProximityChange(.immediate)
       let charateristic = LittleBlueToothCharacteristic(characteristic: CBUUID.ledCharacteristic.uuidString, for: CBUUID.nordicBlinkyService.uuidString)
       let writeWOResp = expectation(description: "Write without response expectation")

       var data = Data()
       (0..<23).forEach { (val) in
           data.append(val)
       }
       littleBT.startDiscovery(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : false])
       .flatMap { discovery in
           self.littleBT.connect(to: discovery)
       }
       .flatMap { _ in
           self.littleBT.write(to: charateristic, value: data, response: false)
       }
       .sink(receiveCompletion: { completion in
           print("Completion \(completion)")
       }) { (answer) in
           print("Answer \(answer)")
           self.littleBT.disconnect().sink(receiveCompletion: {_ in
           }) { (_) in
               writeWOResp.fulfill()
           }
           .store(in: &self.disposeBag)

       }
       .store(in: &disposeBag)
        waitForExpectations(timeout: 10)
   }

}
