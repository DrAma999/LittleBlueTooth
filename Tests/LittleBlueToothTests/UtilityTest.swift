//
//  UtilityTest.swift
//  LittleBlueToothTests
//
//  Created by Andrea Finollo on 05/07/2020.
//  Copyright © 2020 Andrea Finollo. All rights reserved.
//

import XCTest
import CoreBluetoothMock
import Combine
import os.log
@testable import LittleBlueToothForTest

class UtilityTest: LittleBlueToothTests {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    struct LedStateWrong: Readable {
        let isOn: Bool
        
        init(from data: Data) throws {
            let answer: Bool = try data.extract(start: 0, length: 4)
            self.isOn = answer
        }
        
    }
    
    func testReadable() {
        let ledState = try? LedState(from: Data([0x01]))
        XCTAssertNotNil(ledState)
        
        do {
            let _ = try LedStateWrong(from: Data([0x01]))
        } catch let error {
            if case LittleBluetoothError.deserializationFailedDataOfBounds(_,_,_) = error {
                XCTAssert(true)
            } else {
                XCTAssert(false)
            }
        }
    }
    
    struct WritableMock: Writable {
        var data: Data {
            return LittleBlueTooth.assemble([UInt8(0x01), UInt8(0x02)])
        }
        
    }
    
    func testCharacteristicEquality() {
        let characteristicOne = LittleBlueToothCharacteristic(characteristic: CBMUUID.buttonCharacteristic.uuidString, for: CBMUUID.nordicBlinkyService.uuidString, properties: [.read, .notify])
        let characteristicTwo = LittleBlueToothCharacteristic(characteristic: "00001524-1212-EFDE-1523-785FEABCD123", for: "00001523-1212-EFDE-1523-785FEABCD123", properties: [.read, .notify])
        XCTAssert(characteristicOne == characteristicTwo)
    }
    
    func testCharacteristicEqualityFail() {
          let characteristicOne = LittleBlueToothCharacteristic(characteristic: CBMUUID.buttonCharacteristic.uuidString, for: CBMUUID.nordicBlinkyService.uuidString, properties: [.read, .notify])
          let characteristicTwo = LittleBlueToothCharacteristic(characteristic: "00001524-1212-EFDE-1523-785FEABCD123", for: "00001523-1212-EFDE-1523-785FEABCD127", properties: [.read, .notify])
          XCTAssertFalse(characteristicOne == characteristicTwo)
      }
    
    func testCharacteristicHash() {
        let characteristicOne = LittleBlueToothCharacteristic(characteristic: CBMUUID.buttonCharacteristic.uuidString, for: CBMUUID.nordicBlinkyService.uuidString, properties: [.read, .notify])
        let characteristicTwo = LittleBlueToothCharacteristic(characteristic: "00001524-1212-EFDE-1523-785FEABCD123", for: "00001523-1212-EFDE-1523-785FEABCD123", properties: [.read, .notify])
        XCTAssert(characteristicOne.hashValue == characteristicTwo.hashValue)
     }
    
    func testWritable() {
        let writable = WritableMock()
        XCTAssert(writable.data == Data([0x01, 0x02]))
    }
    
    func testExtension() {
        let uintdt = UInt8(0x01).data
        XCTAssert(uintdt == Data([0x01]))
        
        let dtuint = UInt8(from: Data([0x01]))
        XCTAssert(dtuint == 0x01)

        let data = Data(from: Data([0x01]))
        XCTAssert(data == Data([0x01]))

        let dataData = data.data
        XCTAssert(dataData == Data([0x01]))

    }
    
    func testPeripheralIdentifier() {
        let uuid = UUID()
        var periphId: PeripheralIdentifier? = PeripheralIdentifier(uuid: uuid, name: "foo")
        XCTAssertTrue(periphId!.name! == "foo")
        XCTAssertTrue(periphId!.id == uuid)
        
        periphId = PeripheralIdentifier(uuid: uuid)
        XCTAssertTrue(periphId!.id == uuid)

        periphId = try? PeripheralIdentifier(string: uuid.uuidString, name: "foo")
        XCTAssertNotNil(periphId)
        XCTAssertTrue(periphId!.name! == "foo")
        XCTAssertTrue(periphId!.id == uuid)
        
        periphId = try? PeripheralIdentifier(string: uuid.uuidString)
        XCTAssertNotNil(periphId)
        XCTAssertTrue(periphId!.id == uuid)
        
       
        
        var periphIdTwo = PeripheralIdentifier(uuid: periphId!.id)
        XCTAssertTrue(periphId == periphIdTwo)

        periphIdTwo = PeripheralIdentifier(uuid: UUID())
        XCTAssertFalse(periphId == periphIdTwo)
        
        periphId = try? PeripheralIdentifier(string: "")
        XCTAssertNil(periphId)
    }
    
    func testShareReplay() {
        var event1: Set<String> = []
        var event2: Set<String> = []

        let cvs = CurrentValueSubject<String, Never>("Hello")
        
        let shareTest =
            cvs
                .shareReplay(1)
                .eraseToAnyPublisher()
        
        let sub1 = shareTest.sink(receiveValue: { value in
            event1.insert(value)
            print("subscriber1: \(value)\n")
        })
        print("Sub1: \(sub1)")

        let sub2 = shareTest.sink(receiveValue: { value in
            event2.insert(value)
            print("subscriber2: \(value)\n")
        })
        print("Sub2: \(sub2)")

        cvs.send("World")
        cvs.send(completion: .finished)
        cvs.send("Huge")
        
        XCTAssert(event1.count == 2)
        XCTAssert(event1 == event2)
    }
    
    // MARK: - Loggable

    /// Note that the current implementation does not actually `throw` but rather uses `assert`.  Nevertheless
    /// wrapping with `XCTAssertNoThrow` accomplishes the goal of verifying the function behaviour while adding
    /// a tiny future proof should assert be replaced by a thrown Error.
    func testLoggableShouldAccept3Args() {
        
        class MockLogger: Loggable {
            var isLogEnabled = true
            static var wasCalled = false
        }
        
        XCTAssertNoThrow(
            MockLogger().log("3 may pass", log: OSLog.LittleBT_Log_General, type: .info,
                             arg: ["arg1", "arg2", "arg3"])
        )
    }

}
