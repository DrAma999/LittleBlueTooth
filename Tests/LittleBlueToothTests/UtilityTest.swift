//
//  UtilityTest.swift
//  LittleBlueToothTests
//
//  Created by Andrea Finollo on 05/07/2020.
//  Copyright © 2020 Andrea Finollo. All rights reserved.
//

import XCTest
import CoreBluetoothMock
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
            return LittleBlueTooth.ensemble([UInt8(0x01), UInt8(0x02)])
        }
        
    }
    
    func testCharacteristicEquality() {
        let characteristicOne = LittleBlueToothCharacteristic(characteristic: CBMUUID.buttonCharacteristic.uuidString, for: CBMUUID.nordicBlinkyService.uuidString)
        let characteristicTwo = LittleBlueToothCharacteristic(characteristic: "00001524-1212-EFDE-1523-785FEABCD123", for: "00001523-1212-EFDE-1523-785FEABCD123")
        XCTAssert(characteristicOne == characteristicTwo)
    }
    
    func testCharacteristicHash() {
        let characteristicOne = LittleBlueToothCharacteristic(characteristic: CBMUUID.buttonCharacteristic.uuidString, for: CBMUUID.nordicBlinkyService.uuidString)
        let characteristicTwo = LittleBlueToothCharacteristic(characteristic: "00001524-1212-EFDE-1523-785FEABCD123", for: "00001523-1212-EFDE-1523-785FEABCD123")
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
        
        periphId = try? PeripheralIdentifier(string: "")
        XCTAssertNil(periphId)
    }

}
