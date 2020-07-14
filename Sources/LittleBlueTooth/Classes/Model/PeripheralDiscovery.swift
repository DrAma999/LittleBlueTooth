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
    public var id: UUID
    public var name: String?
    
    public init(peripheral: CBPeripheral) {
        self.id = peripheral.identifier
        self.name = peripheral.name
    }
    
    public init(uuid: UUID, name: String? = nil) {
        self.id = uuid
        self.name = name
    }
    
    public init(string: String, name: String? = nil) throws {
        if let id = UUID(uuidString: string) {
            self.init(uuid: id, name: name)
        } else {
            throw LittleBluetoothError.invalidUUID(string)
        }
    }
}

extension PeripheralIdentifier: CustomStringConvertible {
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
        
    public var id: UUID
    public var name: String?
    
    public let cbPeripheral: CBPeripheral
    public let advertisement: AdvertisingInfo
    public let rssi: Int
    
    init(_ peripheral: CBPeripheral, advertisement: [String : Any], rssi: NSNumber) {
        self.cbPeripheral = peripheral
        self.name = peripheral.name
        self.id = peripheral.identifier
        self.rssi = rssi.intValue
        self.advertisement = AdvertisingInfo(advertisementData: advertisement)
    }
}

extension PeripheralDiscovery: CustomDebugStringConvertible {
    public var debugDescription: String {
        return """
        Name: \(name ?? "not available")
        CB Peripheral: \(cbPeripheral)
        Adv: \(advertisement)
        RSSI: \(rssi)
        """
    }
    
    
}
