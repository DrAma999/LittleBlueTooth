//
//  Task.swift
//  LittleBlueTooth
//
//  Created by Andrea Finollo on 10/06/2020.
//  Copyright © 2020 Andrea Finollo. All rights reserved.
//

import Foundation
#if TEST
import CoreBluetoothMock
#else
import CoreBluetooth
#endif

public typealias LittleBlueToothServiceIndentifier = String
public typealias LittleBlueToothCharacteristicIndentifier = String

public struct LittleBlueToothCharacteristic: Identifiable {
    public let id: CBUUID
    
    public let service: CBUUID
    
    public var rawValue: Data? {
        cbCharacteristic?.value
    }
    
    private var cbCharacteristic: CBCharacteristic?
    
    public init(characteristic: LittleBlueToothCharacteristicIndentifier, for service: LittleBlueToothServiceIndentifier) {
        self.id = CBUUID(string: characteristic)
        self.service = CBUUID(string: service)
    }
    
    public init(with characteristic: CBCharacteristic) {
        self.id = characteristic.uuid
        self.service = characteristic.service.uuid
        self.cbCharacteristic = characteristic
    }
    
    public func value<T: Readable>() throws -> T {
        guard let data = rawValue else {
            throw LittleBluetoothError.emptyData
        }
        return try T.init(from: data)
    }
}

extension LittleBlueToothCharacteristic: Equatable, Hashable {}

