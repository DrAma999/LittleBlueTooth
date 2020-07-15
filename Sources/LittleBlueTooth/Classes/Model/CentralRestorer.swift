//
//  CentralRestorer.swift
//  LittleBlueTooth
//
//  Created by Andrea Finollo on 15/07/2020.
//

import Foundation
#if TEST
import CoreBluetoothMock
#else
import CoreBluetooth
#endif

public struct CentralRestorer {
    public unowned let centralManager: CBCentralManager
    public let restoredInfo: [String : Any]
    

    /// Array of `PeripheralIdentifier` objects which have been restored.
    /// These are peripherals that were connected to the central manager (or had a connection pending)
    /// at the time the app was terminated by the system.
    public var peripherals: [PeripheralIdentifier] {
        if let peripherals = restoredInfo[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            return centralManager.retrievePeripherals(withIdentifiers: peripherals.map{$0.identifier}).map {PeripheralIdentifier(peripheral: $0)}
        }
        return []
    }
    
    /// Dictionary that contains all of the peripheral scan options that were being used
    /// by the central manager at the time the app was terminated by the system.
      public var scanOptions: [String: AnyObject]? {
          return restoredInfo[CBCentralManagerRestoredStateScanOptionsKey] as? [String: AnyObject]
      }

      /// Array of `CBUUID` objects of services which have been restored.
      /// These are all the services the central manager was scanning for at the time the app
      /// was terminated by the system.
      public var services: [CBUUID] {
        if let servicesUUID = restoredInfo[CBCentralManagerRestoredStateScanServicesKey] as? [CBUUID] {
            return servicesUUID
        }
        return []
      }
}
