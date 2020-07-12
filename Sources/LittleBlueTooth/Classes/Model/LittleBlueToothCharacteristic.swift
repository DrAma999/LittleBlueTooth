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

public struct LittleBlueToothCharacteristic {
    public let characteristic: CBUUID
    public let service: CBUUID
    
    public init(characteristic: LittleBlueToothCharacteristicIndentifier, for service: LittleBlueToothServiceIndentifier) {
        self.characteristic = CBUUID(string: characteristic)
        self.service = CBUUID(string: service)
    }
}

