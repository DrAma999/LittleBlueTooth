//
//  Task.swift
//  LittleBlueTooth
//
//  Created by Andrea Finollo on 10/06/2020.
//  Copyright © 2020 Andrea Finollo. All rights reserved.
//

import Foundation
#if TEST
@preconcurrency import CoreBluetoothMock
#else
@preconcurrency import CoreBluetooth
#endif

/// Type alias for a CBUUID string used to identify services
public typealias LittleBlueToothServiceIndentifier = String
/// Type alias for a CBUUID string used to identify characteristic
public typealias LittleBlueToothCharacteristicIndentifier = String


/// A representation of a bluetooth characteristic
public struct LittleBlueToothCharacteristic: Identifiable {
    /// The `CBUUID` of the characteristic
    public let id: CBUUID
    /// The `CBUUID` of the service
    public let service: CBUUID
    /// Properties of the characteristic. They are mapped from `CBCharacteristicProperties`
    public let properties: Properties
    /// Inner value of the `CBCaharacteristic`
    public var rawValue: Data? {
        cbCharacteristic?.value
    }
    
    private var cbCharacteristic: CBCharacteristic?
    
    /// Initialize a  `LittleBlueToothCharacteristic`.
    /// - parameter characteristic: the `LittleBlueToothCharacteristicIndentifier` instance, basically a string
    /// - parameter service: the `LittleBlueToothServiceIndentifier` instance, basically a string
    /// - parameter properties: an option set of properties
    /// - returns: An instance of `LittleBlueToothCharacteristic`.
    public init(characteristic: LittleBlueToothCharacteristicIndentifier, for service: LittleBlueToothServiceIndentifier, properties: LittleBlueToothCharacteristic.Properties) {
        self.id = CBUUID(string: characteristic)
        self.service = CBUUID(string: service)
        self.properties = properties
    }
    /// Initialize a  `LittleBlueToothCharacteristic` from a `CBCharacteristic`
    /// - parameter characteristic: the `CBCharacteristic` instance that you want to use
    /// - returns: An instance of `LittleBlueToothCharacteristic`.
    public init(with characteristic: CBCharacteristic) {
        // Couldn't get rid of this orrible compiler flags but it is present to make work SPM build and Xcode build
#if swift(>=5.5)
        guard let service = characteristic.service else {
            fatalError("There must be a service associated to the characteristic")
        }
#else
        let service = characteristic.service
#endif
        self.id = characteristic.uuid
        self.service = service.uuid
        self.cbCharacteristic = characteristic
        self.properties = Properties(properties: characteristic.properties)
    }
    
    /// A helper method to get a concrete value from the value contained in the characteristic.
    /// The type must conform to the `Readable` protocol
    /// - parameter characteristic: the `CBCharacteristic` instance that you want to use
    /// - returns: An instance of  of the requested type.
    /// - throws: If the transformation from the `Data` to the `T` type cannot be made an error is thrown
    public func value<T: Readable>() throws -> T {
        guard let data = rawValue else {
            throw LittleBluetoothError.emptyData
        }
        return try T.init(from: data)
    }
}

extension LittleBlueToothCharacteristic: Equatable, Hashable {
    /// If two `LittleBlueToothCharacteristic` are compared and they have the same characteristic and service identifier they are equal
    public static func == (lhs: Self, rhs: Self) -> Bool {
        if lhs.id == rhs.id &&
            lhs.service == rhs.service {
            return true
        }
        return false
    }
    
    /// Combute the hash of a `LittleBlueToothCharacteristic`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(service)
    }
    
}

public extension LittleBlueToothCharacteristic {
    /// Permitted operations on the characteristic they already exist in CBCharacteristic need to remap when initialized from CBCharacteristic
    struct Properties: OptionSet {
        public let rawValue: UInt8
        
        public static let broadcast                     = Properties(rawValue: 1 << 0)
        public static let read                          = Properties(rawValue: 1 << 1)
        public static let writeWithoutResponse          = Properties(rawValue: 1 << 2)
        public static let write                         = Properties(rawValue: 1 << 3)
        public static let notify                        = Properties(rawValue: 1 << 4)
        public static let indicate                      = Properties(rawValue: 1 << 5)
        public static let authenticatedSignedWrites     = Properties(rawValue: 1 << 6)
        public static let extendedProperties            = Properties(rawValue: 1 << 7)
        public static let notifyEncryptionRequired      = Properties(rawValue: 1 << 8)
        public static let indicateEncryptionRequired    = Properties(rawValue: 1 << 9)
        
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

