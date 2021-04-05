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
    
    lazy var  peripheralDiscoveredServicesPublisher = { _peripheralDiscoveredServicesPublisher.share().eraseToAnyPublisher()
    }()
    let _peripheralDiscoveredServicesPublisher = PassthroughSubject<([CBService]?, LittleBluetoothError?), Never>()
    
    lazy var  peripheralDiscoveredIncludedServicesPublisher = { _peripheralDiscoveredIncludedServicesPublisher.share().eraseToAnyPublisher()
    }()
    let _peripheralDiscoveredIncludedServicesPublisher = PassthroughSubject<(CBService, Error?), Never>()
    
    lazy var peripheralDiscoveredCharacteristicsForServicePublisher = { _peripheralDiscoveredCharacteristicsForServicePublisher.share().eraseToAnyPublisher()
    }()
    let _peripheralDiscoveredCharacteristicsForServicePublisher = PassthroughSubject<(CBService, LittleBluetoothError?), Never>()
    
    lazy var peripheralUpdatedNotificationStateForCharacteristicPublisher = { _peripheralUpdatedNotificationStateForCharacteristicPublisher.share().eraseToAnyPublisher()
    }()
    let _peripheralUpdatedNotificationStateForCharacteristicPublisher =
        PassthroughSubject<(CBCharacteristic, LittleBluetoothError?), Never>()
    
    let peripheralUpdatedValueForCharacteristicPublisher = PassthroughSubject<(CBCharacteristic, LittleBluetoothError?), Never>()
    let peripheralUpdatedValueForNotifyCharacteristicPublisher = PassthroughSubject<(CBCharacteristic, LittleBluetoothError?), Never>()
    let peripheralWrittenValueForCharacteristicPublisher = PassthroughSubject<(CBCharacteristic, LittleBluetoothError?), Never>()
    let peripheralIsReadyToSendWriteWithoutResponse = PassthroughSubject<Void, Never>()
    
    let peripheralDiscoveredDescriptorsForCharacteristicPublisher =
        PassthroughSubject<(CBCharacteristic, LittleBluetoothError?), Never>()
    let peripheralUpdatedValueForDescriptor = PassthroughSubject<(CBDescriptor, LittleBluetoothError?), Never>()
    let peripheralWrittenValueForDescriptor = PassthroughSubject<(CBDescriptor, LittleBluetoothError?), Never>()
    
    var isLogEnabled: Bool = false

}

extension CBPeripheralDelegateProxy: CBPeripheralDelegate {
    
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral){
        log("[LBT: CBPD] ReadyToSendWRiteWOResp",
            log: OSLog.LittleBT_Log_Peripheral,
            type: .debug, arg: [])
        peripheralIsReadyToSendWriteWithoutResponse.send()
    }

    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        log("[LBT: CBPD] DidUpdateName %{public}@",
            log: OSLog.LittleBT_Log_Peripheral,
            type: .debug,
            arg: [peripheral.name ?? "na"])
        peripheralChangesPublisher.send(.name(peripheral.name))
    }

    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]){
        log("[LBT: CBPD] DidModifyServices %{public}@",
            log: OSLog.LittleBT_Log_Peripheral,
            type: .debug,
            arg: [invalidatedServices.description])
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
        log("[LBT: CBPD] DidDiscoverServices, Error %{public}@",
            log: OSLog.LittleBT_Log_Peripheral,
            type: .debug,
            arg: [error?.localizedDescription ?? "None"])
        if let error = error {
            _peripheralDiscoveredServicesPublisher.send((nil,.serviceNotFound(error)))
        } else {
            _peripheralDiscoveredServicesPublisher.send((peripheral.services, nil))
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        log("[LBT: CBPD] DidDiscoverIncludedServices %{public}@, Error %{public}@",
            log: OSLog.LittleBT_Log_Peripheral,
            type: .debug,
            arg: [service.description,
            (error?.localizedDescription ?? "None")])
        if let error = error {
            _peripheralDiscoveredIncludedServicesPublisher.send((service, error))
        } else {
            _peripheralDiscoveredIncludedServicesPublisher.send((service, nil))
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?){
        log("[LBT: CBPD] DidDiscoverCharacteristic %{public}@, Error %{public}@",
            log: OSLog.LittleBT_Log_Peripheral,
            type: .debug,
            arg: [service.description,
            (error?.localizedDescription ?? "None")])
        if let error = error {
            _peripheralDiscoveredCharacteristicsForServicePublisher.send((service,  .characteristicNotFound(error)))
        } else {
            _peripheralDiscoveredCharacteristicsForServicePublisher.send((service, nil))
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?){
        log("[LBT: CBPD] DidUpdateValue %{public}@, Error %{public}@",
            log: OSLog.LittleBT_Log_Peripheral,
            type: .debug,
            arg: [characteristic.description,
            (error?.localizedDescription ?? "None")])
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
        log("[LBT: CBPD] DidWriteValue %{public}@, Error %{public}@",
            log: OSLog.LittleBT_Log_Peripheral,
            type: .debug,
            arg: [characteristic.description,
            (error?.localizedDescription ?? "None")])
        if let error = error {
            peripheralWrittenValueForCharacteristicPublisher.send((characteristic, .couldNotWriteFromCharacteristic(characteristic: characteristic.uuid, error: error)))
        } else {
            peripheralWrittenValueForCharacteristicPublisher.send((characteristic, nil))
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?){
        log("[LBT: CBPD] DidUpdateNotifState %{public}@, Error %{public}@",
            log: OSLog.LittleBT_Log_Peripheral,
            type: .debug,
            arg: [characteristic.description,
            (error?.localizedDescription ?? "None")])
        if let error = error {
            _peripheralUpdatedNotificationStateForCharacteristicPublisher.send((characteristic, .couldNotUpdateListenState(characteristic: characteristic.uuid, error: error)))
        } else {
            _peripheralUpdatedNotificationStateForCharacteristicPublisher.send((characteristic, nil))
        }
    }

    // MARK: - Descriptors
//    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?){}
//    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?){}
//    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?){}
}

extension CBPeripheralDelegateProxy: Loggable {}
