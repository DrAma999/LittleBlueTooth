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


/// A representation of a bluetooth characteristic
public struct LittleBlueToothCharacteristic: Identifiable {
    public let id: CBUUID
    public let service: CBUUID
    public let properties: Properties
    
    public var rawValue: Data? {
        cbCharacteristic?.value
    }
    
    private var cbCharacteristic: CBCharacteristic?
    
    public init(characteristic: LittleBlueToothCharacteristicIndentifier, for service: LittleBlueToothServiceIndentifier, properties: LittleBlueToothCharacteristic.Properties) {
        self.id = CBUUID(string: characteristic)
        self.service = CBUUID(string: service)
        self.properties = properties
    }
    
    public init(with characteristic: CBCharacteristic) {
        self.id = characteristic.uuid
        self.service = characteristic.service.uuid
        self.cbCharacteristic = characteristic
        self.properties = Properties(properties: characteristic.properties)
    }
    
    public func value<T: Readable>() throws -> T {
        guard let data = rawValue else {
            throw LittleBluetoothError.emptyData
        }
        return try T.init(from: data)
    }
}

extension LittleBlueToothCharacteristic: Equatable, Hashable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        if lhs.id == rhs.id &&
            lhs.service == rhs.service {
            return true
        }
        return false
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(service)
    }
    
}

public extension LittleBlueToothCharacteristic {
    /// Permitted operations on the characteristic they already exist in CBCharacteristic need to remap when initialized from CBCharacteristic
    struct Properties: OptionSet {
        public let rawValue: UInt8
        
        public static var broadcast                     = Properties(rawValue: 1 << 0)
        public static var read                          = Properties(rawValue: 1 << 1)
        public static var writeWithoutResponse          = Properties(rawValue: 1 << 2)
        public static var write                         = Properties(rawValue: 1 << 3)
        public static var notify                        = Properties(rawValue: 1 << 4)
        public static var indicate                      = Properties(rawValue: 1 << 5)
        public static var authenticatedSignedWrites     = Properties(rawValue: 1 << 6)
        public static var extendedProperties            = Properties(rawValue: 1 << 7)
        public static var notifyEncryptionRequired      = Properties(rawValue: 1 << 8)
        public static var indicateEncryptionRequired    = Properties(rawValue: 1 << 9)
        
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
        
        public init(properties: CBCharacteristicProperties) {
            self = Self.mapToProperties(values: properties)
        }
        
        static func mapToProperties(values: CBCharacteristicProperties) -> Properties {
            var properties: Properties = []
            values.elements().forEach { (prop) in
                switch prop {
                case .broadcast:
                    properties.update(with: .broadcast)
                case .read:
                    properties.update(with: .read)
                case .writeWithoutResponse:
                    properties.update(with: .writeWithoutResponse)
                case .write:
                    properties.update(with: .write)
                case .notify:
                    properties.update(with: .notify)
                case .indicate:
                    properties.update(with: .indicate)
                case .authenticatedSignedWrites:
                    properties.update(with: .authenticatedSignedWrites)
                case .extendedProperties:
                    properties.update(with: .extendedProperties)
                case .notifyEncryptionRequired:
                    properties.update(with: .notifyEncryptionRequired)
                case .indicateEncryptionRequired:
                    properties.update(with: .indicateEncryptionRequired)
                default:
                    print("NO mapping")
                }
            }
            return properties
        }
    }
}

