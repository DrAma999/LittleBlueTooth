//
//  CBPeripheralProxy.swift
//  LittleBlueTooth
//
//  Created by Andrea Finollo on 10/06/2020.
//  Copyright © 2020 Andrea Finollo. All rights reserved.
//

import Foundation
import Combine
import os.log
#if TEST
import CoreBluetoothMock
#else
import CoreBluetooth
#endif

class CBPeripheralDelegateProxy: NSObject {
    
    let peripheralChangesPublisher = PassthroughSubject<PeripheralChanges, Never>()
    let peripheralRSSIPublisher = PassthroughSubject<(Int, LittleBluetoothError?), Never>()
    let peripheralDiscoveredServicesPublisher = PassthroughSubject<([CBService]?, LittleBluetoothError?), Never>()
    let peripheralDiscoveredIncludedServicesPublisher = PassthroughSubject<(CBService, Error?), Never>()
    let peripheralDiscoveredCharacteristicsForServicePublisher = PassthroughSubject<(CBService, LittleBluetoothError?), Never>()
    let peripheralUpdatedValueForCharacteristicPublisher = PassthroughSubject<(CBCharacteristic, LittleBluetoothError?), Never>()
    let peripheralUpdatedValueForNotifyCharacteristicPublisher = PassthroughSubject<(CBCharacteristic, LittleBluetoothError?), Never>()
    let peripheralWrittenValueForCharacteristicPublisher = PassthroughSubject<(CBCharacteristic, LittleBluetoothError?), Never>()
    let peripheralIsReadyToSendWriteWithoutResponse = PassthroughSubject<Void, Never>()

    let peripheralUpdatedNotificationStateForCharacteristicPublisher =
        PassthroughSubject<(CBCharacteristic, LittleBluetoothError?), Never>()
    
    let peripheralDiscoveredDescriptorsForCharacteristicPublisher =
        PassthroughSubject<(CBCharacteristic, LittleBluetoothError?), Never>()
    let peripheralUpdatedValueForDescriptor = PassthroughSubject<(CBDescriptor, LittleBluetoothError?), Never>()
    let peripheralWrittenValueForDescriptor = PassthroughSubject<(CBDescriptor, LittleBluetoothError?), Never>()
    
}

extension CBPeripheralDelegateProxy: CBPeripheralDelegate {
    
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral){
        os_log("CBPD ReadyToSendWRiteWOResp", log: OSLog.BT_Log_Peripheral, type: .debug)

        peripheralIsReadyToSendWriteWithoutResponse.send()
    }

    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        os_log("CBPD DidUpdateName %{public}@", log: OSLog.BT_Log_Peripheral, type: .debug, peripheral.name ?? "na")

        peripheralChangesPublisher.send(.name(peripheral.name))
    }

    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]){
        os_log("CBPD DidModifyServices %{public}@", log: OSLog.BT_Log_Peripheral, type: .debug, invalidatedServices.description)

        peripheralChangesPublisher.send(.invalidatedServices(invalidatedServices))
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if let error = error {
            peripheralRSSIPublisher.send((RSSI.intValue,.couldNotReadRSSI(error)))
        } else {
            peripheralRSSIPublisher.send((RSSI.intValue, nil))
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?){
        os_log("CBPD DidDiscoverServices, Error %{public}@", log: OSLog.BT_Log_Peripheral, type: .debug, error?.localizedDescription ?? "")
        if let error = error {
            peripheralDiscoveredServicesPublisher.send((nil,.serviceNotFound(error)))
        } else {
            peripheralDiscoveredServicesPublisher.send((peripheral.services, nil))
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        os_log("CBPD DidDiscoverIncludedServices %{public}@, Error %{public}@", log: OSLog.BT_Log_Peripheral, type: .debug, service.description, error?.localizedDescription ?? "")

        if let error = error {
            peripheralDiscoveredIncludedServicesPublisher.send((service, error))
        } else {
            peripheralDiscoveredIncludedServicesPublisher.send((service, nil))
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?){
        os_log("CBPD DidDiscoverCharacteristic %{public}@, Error %{public}@", log: OSLog.BT_Log_Peripheral, type: .debug, service.description, error?.localizedDescription ?? "")

        if let error = error {
            peripheralDiscoveredCharacteristicsForServicePublisher.send((service,  .characteristicNotFound(error)))
        } else {
            peripheralDiscoveredCharacteristicsForServicePublisher.send((service, nil))
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?){
        os_log("CBPD DidUpdateValue %{public}@, Error %{public}@", log: OSLog.BT_Log_Peripheral, type: .debug, characteristic.description, error?.localizedDescription ?? "")

        if let error = error {
            peripheralUpdatedValueForCharacteristicPublisher.send((characteristic, .couldNotReadFromCharacteristic(characteristic: characteristic.uuid, error: error)))
        } else {
            if !characteristic.isNotifying {
                peripheralUpdatedValueForCharacteristicPublisher.send((characteristic, nil))
            } else {
                peripheralUpdatedValueForNotifyCharacteristicPublisher.send((characteristic, nil))
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        os_log("CBPD DidWriteValue %{public}@, Error %{public}@", log: OSLog.BT_Log_Peripheral, type: .debug, characteristic.description, error?.localizedDescription ?? "")

        if let error = error {
            peripheralWrittenValueForCharacteristicPublisher.send((characteristic, .couldNotWriteFromCharacteristic(characteristic: characteristic.uuid, error: error)))
        } else {
            peripheralWrittenValueForCharacteristicPublisher.send((characteristic, nil))
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?){
        os_log("CBPD DidUpdateNotifState %{public}@, Error %{public}@", log: OSLog.BT_Log_Peripheral, type: .debug, characteristic.description, error?.localizedDescription ?? "")

        if let error = error {
            peripheralUpdatedNotificationStateForCharacteristicPublisher.send((characteristic, .couldNotUpdateListenState(characteristic: characteristic.uuid, error: error)))
        } else {
            peripheralUpdatedNotificationStateForCharacteristicPublisher.send((characteristic, nil))
        }
    }

    // MARK: - Descriptors
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?){}
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?){}
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?){}
}
