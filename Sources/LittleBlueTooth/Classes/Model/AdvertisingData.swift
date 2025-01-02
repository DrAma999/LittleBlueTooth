//
//  AdvertisingData.swift
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

/// A wrapper around the advertisement data returned from a BLE device.
public struct AdvertisingInfo {
     public let advertisementData: [String: Any]

       /// Creates advertisement data based on CoreBluetooth's dictionary
       /// - parameter advertisementData: Core Bluetooth's advertisement data
       public init(advertisementData: [String: Any]) {
           self.advertisementData = advertisementData
       }

       /// A string containing the local name of a peripheral.
       public var localName: String? {
           return advertisementData[CBAdvertisementDataLocalNameKey] as? String
       }

       /// A Data object containing the manufacturer data of a peripheral.
       public var manufacturerData: Data? {
           return advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
       }

       /// A dictionary containing service-specific advertisement data.
       /// The keys are CBUUID objects, representing CBService UUIDs. The values are Data objects,
       /// representing service-specific data.
       public var serviceData: [CBUUID: Data]? {
           return advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data]
       }

       /// An array of service UUIDs.
       public var serviceUUIDs: [CBUUID]? {
           return advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
       }

       /// An array of one or more CBUUID objects, representing CBService UUIDs that were found in the “overflow”
       /// area of the advertisement data.
       public var overflowServiceUUIDs: [CBUUID]? {
           return advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID]
       }

       /// A number (an instance of NSNumber) containing the transmit power of a peripheral.
       /// This key and value are available if the broadcaster (peripheral)
       /// provides its Tx power level in its advertising packet.
       /// Using the RSSI value and the Tx power level, it is possible to calculate path loss.
       public var txPowerLevel: NSNumber? {
           return advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber
       }

       /// A Boolean value that indicates whether the advertising event type is connectable.
       /// The value for this key is an NSNumber object. You can use this value to determine whether
       /// a peripheral is connectable at a particular moment.
       public var isConnectable: Bool? {
           return advertisementData[CBAdvertisementDataIsConnectable] as? Bool
       }

       /// An array of one or more CBUUID objects, representing CBService UUIDs.
       public var solicitedServiceUUIDs: [CBUUID]? {
           return advertisementData[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID]
       }
}

extension AdvertisingInfo: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        return """
        Name: \(localName ?? "Not available")
        Manufacturer: \(manufacturerData?.description ?? "Not available")
        Service Data: \(serviceData ?? [:])
        ServiceUUID: \(serviceUUIDs ?? [])
        OverflowService: \(overflowServiceUUIDs ?? [])
        TX: \(txPowerLevel?.stringValue ?? "Not available")
        Connectable: \(isConnectable?.description ?? "Not available")
        SolicitedService: \(solicitedServiceUUIDs ?? [])
        """
    }
}
