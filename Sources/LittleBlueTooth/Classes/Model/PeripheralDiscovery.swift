//
//  PeripheralDiscovery.swift
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


public protocol PeripheralIdentifiable: Identifiable {
    var id: UUID {get set}
    var name: String? {get set}
}
/// An object that contains the unique identifier of the `CBPeripheral` and the name of it (if present)
public struct PeripheralIdentifier: PeripheralIdentifiable {
    /// The `UUID`of the peripheral
    public var id: UUID
    /// The name of the peripheral
    public var name: String?
    /// The wrapped `CBPeripheral`
    public var cbPeripheral: CBPeripheral?
    
    /// Initialize a `PeripheralIdentifier` using a `CBPeripheral`
    public init(peripheral: CBPeripheral) {
        self.id = peripheral.identifier
        self.name = peripheral.name
        self.cbPeripheral = peripheral
    }
    /// Initialize a  `PeripheralIdentifier`.
    /// - parameter uuid: the `UUID` of a peripheral.
    /// - parameter name: the name of a peripheral
    /// - returns: An instance of `PeripheralIdentifier`.
    public init(uuid: UUID, name: String? = nil) {
        self.id = uuid
        self.name = name
    }
    /// Initialize a  `PeripheralIdentifier`.
    /// - parameter string: the uuid in string of a peripheral.
    /// - parameter name: the name of a peripheral
    /// - throws: and error is thrown if the converstion string->UUID fails
    /// - returns: An instance of `PeripheralIdentifier`.
    public init(string: String, name: String? = nil) throws {
        if let id = UUID(uuidString: string) {
            self.init(uuid: id, name: name)
        } else {
            throw LittleBluetoothError.invalidUUID(string)
        }
    }
}

extension PeripheralIdentifier: CustomStringConvertible {
    /// Extended description
    public var description: String {
        return """
        UUID: \(id)
        Name: \(name ?? "not availbale")
        """
    }
}

/**
An object that contains the unique identifier of the `CBPeripheral`, the name of it (if present) and the advertising info.
*/
public struct PeripheralDiscovery: PeripheralIdentifiable {
    /// The `UUID` of the discovery
    public var id: UUID
    /// The name of the discovery
    public var name: String?
    /// The wrapped `CBPeripheral` of the discovery
    public let cbPeripheral: CBPeripheral
    /// The wrapped `AdvertisingInfo` of the discovery
    public let advertisement: AdvertisingInfo
    /// The wrapped rssi of the discovery
    public let rssi: Int
    /// Initialize a  `PeripheralDiscovery`.
    /// - parameter peripheral: the `CBPeripheral` that you want to wrap
    /// - parameter advertisement: the advertising info as they are returned from `CBManager`
    /// - parameter rssi: the rssi iof the `CBPeripheral`
    /// - returns: An instance of `PeripheralDiscovery`.
    init(_ peripheral: CBPeripheral, advertisement: [String : Any], rssi: NSNumber) {
        self.cbPeripheral = peripheral
        self.name = peripheral.name
        self.id = peripheral.identifier
        self.rssi = rssi.intValue
        self.advertisement = AdvertisingInfo(advertisementData: advertisement)
    }
}

extension PeripheralDiscovery: CustomDebugStringConvertible {
    /// Extended description of the discovery
    public var debugDescription: String {
        return """
        Name: \(name ?? "not available")
        CB Peripheral: \(cbPeripheral)
        Adv: \(advertisement.debugDescription)
        RSSI: \(rssi)
        """
    }
    
    
}

extension PeripheralIdentifier: Equatable, Hashable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        if lhs.id == rhs.id  {
            return true
        }
        return false
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
}
