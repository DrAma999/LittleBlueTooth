//
//  CentralRestorer.swift
//  LittleBlueTooth
//
//  Created by Andrea Finollo on 15/07/2020.
//

import Foundation
import Combine
#if TEST
import CoreBluetoothMock
#else
import CoreBluetooth
#endif
/**
 This object contains parsed information passed from the `centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any])` method of `CBCentralManagerDelegate` dictionary
 */
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
    public var scanOptions: [String: AnyObject] {
        if let info = restoredInfo[CBCentralManagerRestoredStateScanOptionsKey] as? [String: AnyObject] {
            return info
        }
        return [:]
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

extension CentralRestorer: CustomDebugStringConvertible {
    public var debugDescription: String {
        return """
        Peripherals: \(peripherals)
        Scan options: \(scanOptions)
        Services: \(services)
        """
    }
}

/**
This object contains the restored action during state restoration
*/
public enum Restored: CustomDebugStringConvertible {
    /// Peripherals scan has been restored
    case scan(discoveryPublisher: AnyPublisher<PeripheralDiscovery, LittleBluetoothError>)
    /// Peripheral has been restored
    case peripheral(Peripheral)
    /// Nothing has been restored
    case nothing
    
    public var debugDescription: String {
        switch self {
        case .scan(_):
            return "Restored Scan"
        case .peripheral(let periph):
            return "Restored \(periph.debugDescription)"
        case .nothing:
            return "Nothing to be restored"
        }
    }
}
