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

struct CentralRestorer {
    unowned let centralManager: CBCentralManager
    let restoredInfo: [String : Any]
    

    /// Array of `PeripheralIdentifier` objects which have been restored.
    /// These are peripherals that were connected to the central manager (or had a connection pending)
    /// at the time the app was terminated by the system.
    var peripherals: [PeripheralIdentifier] {
        if let peripherals = restoredInfo[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            return centralManager.retrievePeripherals(withIdentifiers: peripherals.map{$0.identifier}).map {PeripheralIdentifier(peripheral: $0)}
        }
        return []
    }
    
    /// Dictionary that contains all of the peripheral scan options that were being used
    /// by the central manager at the time the app was terminated by the system.
    var scanOptions: [String: AnyObject] {
        if let info = restoredInfo[CBCentralManagerRestoredStateScanOptionsKey] as? [String: AnyObject] {
            return info
        }
        return [:]
      }

      /// Array of `CBUUID` objects of services which have been restored.
      /// These are all the services the central manager was scanning for at the time the app
      /// was terminated by the system.
      var services: [CBUUID] {
        if let servicesUUID = restoredInfo[CBCentralManagerRestoredStateScanServicesKey] as? [CBUUID] {
            return servicesUUID
        }
        return []
      }
}

extension CentralRestorer: CustomDebugStringConvertible {
    public var debugDescription: String {
        return """
        Peripherals: \(peripherals)
        Scan options: \(scanOptions)
        Services: \(services)
        """
    }
    
    
}
