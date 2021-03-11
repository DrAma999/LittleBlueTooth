//
//  Peripheral.swift
//  LittleBlueTooth
//
//  Created by Andrea Finollo on 10/06/2020.
//  Copyright © 2020 Andrea Finollo. All rights reserved.
//

import Foundation
import Combine

#if TEST
import CoreBluetoothMock
#else
import CoreBluetooth
#endif

/// An enumeration that represent the changes in peripheral services or name
public enum PeripheralChanges {
    /// The name has been changed
    case name(String?)
    /// Some services have been invalidated
    case invalidatedServices([CBService])
}

/// The state of the peripheral
public enum PeripheralState {
    /// Peripheral is disconnected
    case disconnected
    /// Peripheral is connecting
    case connecting
    /// Peripheral is connected
    case connected
    /// Peripheral is disconnecting
    case disconnecting
    /// The peripheral state is not know, could be transitory
    case unknown
    
    /// Initilize a Peripheral state using a `CBPeripheralState`
    init(state: CBPeripheralState) {
        switch state {
        case .disconnected:
            self = .disconnected
        case .connected:
            self = .connected
        case .disconnecting:
            self = .disconnecting
        case .connecting:
            self = .connecting
        default:
            self = .unknown
        }
    }
}

/// It represents a peripheral along with its properties
public class Peripheral: Identifiable {
    /// An identifier for the peripheral it is the same as the wrapped `CBPeripheral`
    public var id: UUID {
        cbPeripheral.identifier
    }
    /// The name of the peripheral it is the same as the wrapped `CBPeripheral`
    public var name: String? {
        cbPeripheral.name
    }
    /// The state of the peripheral it is the same as the wrapped `CBPeripheral`
    public var state: PeripheralState {
        PeripheralState(state: cbPeripheral.state)
    }
    
    /// The wrapped `CBPeripheral`
    public let cbPeripheral: CBPeripheral
    /// The rssi value of the peripheral
    public var rssi: Int?
    
    /// Logging on the peripheral can be disable or enabled acting of that property
    var isLogEnabled: Bool {
        get {
            return _isLogEnabled
        }
        set {
            _isLogEnabled = newValue
            peripheralProxy.isLogEnabled = newValue
        }
    }
    
    /// The publisher that listen to changes in peripheral name or services
    lazy var changesPublisher: AnyPublisher<PeripheralChanges, Never> =
               peripheralProxy.peripheralChangesPublisher
               .share()
               .eraseToAnyPublisher()
    /// The publisher that listen to characteristic notifications
    lazy var listenPublisher: AnyPublisher<CBCharacteristic, LittleBluetoothError> =
            peripheralProxy.peripheralUpdatedValueForNotifyCharacteristicPublisher
            .tryMap { (value) -> CBCharacteristic in
                switch value {
                case let (_, error?):
                    throw error
                case let (charact, _):
                    return charact
                }
            }
            .mapError {$0 as! LittleBluetoothError}
            .share()
            .eraseToAnyPublisher()
    
    let peripheralStatePublisher: AnyPublisher<PeripheralState, Never>
    
    private let peripheralProxy = CBPeripheralDelegateProxy()
    private var _isLogEnabled: Bool = false

    /// Initialize a `Peripheral` using a `CBperipheral`
    /// It also attach the publisher to monitor the state of the peripheral
    init(_ peripheral: CBPeripheral) {
        self.cbPeripheral = peripheral
        self.cbPeripheral.delegate = self.peripheralProxy
        #if !TEST
        self.peripheralStatePublisher = self.cbPeripheral.publisher(for: \.state)
            .map{ (state) -> PeripheralState in
                PeripheralState(state: state)
            }
            .share()
            .eraseToAnyPublisher()
        // Using a timer to poll peripheral state for test to simulate KVO
        #else
        self.peripheralStatePublisher = Timer.publish(every: 0.2, on: .main, in: .common)
        .autoconnect()
        .map {_ in
            PeripheralState(state: peripheral.state)
        }
        .eraseToAnyPublisher()
        #endif
    }
    
    fileprivate func getService(serviceUUID: CBUUID) -> AnyPublisher<[CBService]?, LittleBluetoothError> {
        if let services = self.cbPeripheral.services, services.contains(where: { (service) -> Bool in
            return service.uuid == serviceUUID
        }) {
            return Result<[CBService]?, LittleBluetoothError>.Publisher(.success(services)).eraseToAnyPublisher()
        } else {
            let services = self.peripheralProxy.peripheralDiscoveredServicesPublisher
            .tryMap { (value) -> [CBService]? in
                switch value {
                case let (_, error?):
                    throw error
                case let (services?, _) where services.map{$0.uuid}.contains(serviceUUID):
                    return services
                case (_, .none):
                    throw LittleBluetoothError.serviceNotFound(nil)
                }
            }
            .mapError {$0 as! LittleBluetoothError}
            defer {
                self.cbPeripheral.discoverServices([serviceUUID])
            }
            return services.eraseToAnyPublisher()
        }
    }
    
    fileprivate func getCharateristic(characteristicUUID: CBUUID, from service: CBService) -> AnyPublisher<CBService, LittleBluetoothError> {
        if let characteristics = service.characteristics, characteristics.contains(where: { (charact) -> Bool in
            return charact.uuid == characteristicUUID
        }) {
            return Result<CBService, LittleBluetoothError>.Publisher(.success(service)).eraseToAnyPublisher()
        } else {
            let charact = self.peripheralProxy.peripheralDiscoveredCharacteristicsForServicePublisher
            .tryMap { (value) -> CBService in
                switch value {
                case let (_, error?):
                    throw error
                case let (service, _):
                    return service
                }
            }
            .mapError {$0 as! LittleBluetoothError}
            defer {
                self.cbPeripheral.discoverCharacteristics([characteristicUUID], for: service)
            }
            return charact.eraseToAnyPublisher()
        }
    }
    
    fileprivate func discoverCharacteristic(_ charateristicUUID: CBUUID, fromService serviceUUID: CBUUID) -> AnyPublisher<CBCharacteristic, LittleBluetoothError> {
        let discovery = self.getService(serviceUUID: serviceUUID)
        .customPrint("[LBT] Discover service", isEnabled: isLogEnabled)
        .flatMap { services -> AnyPublisher<CBService, LittleBluetoothError> in
                let service = services!.filter{ $0.uuid == serviceUUID}.first!
                return self.getCharateristic(characteristicUUID: charateristicUUID, from: service)
        }
        .customPrint("[LBT] Discover characteristic", isEnabled: isLogEnabled)
        .tryMap { (service) -> CBCharacteristic in
            guard let charact = service.characteristics?.filter({ $0.uuid == charateristicUUID}).first else {
                throw LittleBluetoothError.characteristicNotFound(nil)
            }
            return charact
        }
        .mapError{$0 as! LittleBluetoothError}
        .eraseToAnyPublisher()
        return discovery
    }
    
    func readRSSI() -> AnyPublisher<Int, LittleBluetoothError> {
        let readRSSI =
            peripheralProxy.peripheralRSSIPublisher
            .tryMap { (value) -> Int in
                switch value {
                case let (_, error?):
                    throw error
                case let (rssi, _):
                    return rssi
                }
            }
            .mapError {$0 as! LittleBluetoothError}
            .eraseToAnyPublisher()
        defer {
            cbPeripheral.readRSSI()
        }
        return readRSSI
    }
   
    func read(from charateristicUUID: CBUUID, of serviceUUID: CBUUID) -> AnyPublisher<Data?, LittleBluetoothError> {
        let read = discoverCharacteristic(charateristicUUID, fromService: serviceUUID)
        .flatMap { characteristic -> AnyPublisher<CBCharacteristic, LittleBluetoothError> in
            self.cbPeripheral.readValue(for: characteristic)
            return self.peripheralProxy.peripheralUpdatedValueForCharacteristicPublisher
            .tryMap { (value) -> CBCharacteristic in
                switch value {
                case let (_, error?):
                    throw error
                case let (charact, _):
                    return charact
                }
            }
            .mapError {$0 as! LittleBluetoothError}
            .eraseToAnyPublisher()
        }
        .map { (characteristic) -> Data? in
            characteristic.value
        }
        .eraseToAnyPublisher()
        return read
    }
    
    
    func write(to charateristicUUID: CBUUID, of serviceUUID: CBUUID, data: Data, response: Bool = true) -> AnyPublisher<CBCharacteristic, LittleBluetoothError> {
        let write = discoverCharacteristic(charateristicUUID, fromService: serviceUUID)
        .flatMap { characteristic -> AnyPublisher<CBCharacteristic, LittleBluetoothError> in
            if response {
                self.cbPeripheral.writeValue(data, for: characteristic, type: .withResponse)
                return self.peripheralProxy.peripheralWrittenValueForCharacteristicPublisher.tryMap { (value) -> CBCharacteristic in
                    switch value {
                    case let (_, error?):
                        throw error
                    case let (charact, _):
                        return charact
                    }
                }
                .mapError {$0 as! LittleBluetoothError}
                .eraseToAnyPublisher()
            } else {
                
                let writeWOResp = self.peripheralProxy.peripheralIsReadyToSendWriteWithoutResponse
                .map { _ -> Bool in
                    return true
                }
                .prepend([self.cbPeripheral.canSendWriteWithoutResponse])
                .filter{ $0 }
                .prefix(1)
                .map {_ in
                    self.cbPeripheral.writeValue(data, for: characteristic, type: .withoutResponse)
                }
                .setFailureType(to: LittleBluetoothError.self)
                .map { characteristic }
                .eraseToAnyPublisher()
                
                return writeWOResp
            }
        }
        .eraseToAnyPublisher()
        return write
    }

    
    func startListen(from charateristicUUID: CBUUID, of serviceUUID: CBUUID) -> AnyPublisher<CBCharacteristic, LittleBluetoothError> {
        let notifyStart = discoverCharacteristic(charateristicUUID, fromService: serviceUUID)
        .flatMap { (characteristic) -> AnyPublisher<CBCharacteristic, LittleBluetoothError> in
            if characteristic.isNotifying {
               return Result<CBCharacteristic, LittleBluetoothError>.Publisher(.success(characteristic)).eraseToAnyPublisher()
            }
            defer {
                self.cbPeripheral.setNotifyValue(true, for: characteristic)
            }
            return self.peripheralProxy.peripheralUpdatedNotificationStateForCharacteristicPublisher
            .tryMap { (value) -> CBCharacteristic in
                switch value {
                case let (_, error?):
                    throw error
                case let (charact, _):
                    return charact
                }
            }
            .mapError {$0 as! LittleBluetoothError}
            .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
        return notifyStart
    }
    
    func stopListen(from charateristicUUID: CBUUID, of serviceUUID: CBUUID) -> AnyPublisher<CBCharacteristic, LittleBluetoothError> {
        let notifyStop = discoverCharacteristic(charateristicUUID, fromService: serviceUUID)
        .flatMap { (characteristic) -> AnyPublisher<CBCharacteristic, LittleBluetoothError> in
            if !characteristic.isNotifying {
               return Result<CBCharacteristic, LittleBluetoothError>.Publisher(.success(characteristic)).eraseToAnyPublisher()
            }
            defer {
                self.cbPeripheral.setNotifyValue(false, for: characteristic)
            }
            return self.peripheralProxy.peripheralUpdatedNotificationStateForCharacteristicPublisher
            .tryMap { (value) -> CBCharacteristic in
                switch value {
                case let (_, error?):
                    throw error
                case let (charact, _):
                    return charact
                }
            }
            .mapError {$0 as! LittleBluetoothError}
            .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
        return notifyStop
    }
    
    func writeAndListen(from charateristicUUID: CBUUID, of serviceUUID: CBUUID, data: Data) -> AnyPublisher<Data?, LittleBluetoothError> {
        
        let writeListen = startListen(from: charateristicUUID, of: serviceUUID)
            .flatMap { (_) -> AnyPublisher<CBCharacteristic, LittleBluetoothError> in
                self.write(to: charateristicUUID, of: serviceUUID, data: data)
            }
            .flatMap { (_) -> AnyPublisher<CBCharacteristic, LittleBluetoothError> in
                self.peripheralProxy.peripheralUpdatedValueForNotifyCharacteristicPublisher
                .tryMap { (value) -> CBCharacteristic in
                    switch value {
                    case let (_, error?):
                        throw error
                    case let (charact, _):
                        return charact
                    }
                }
                .mapError {$0 as! LittleBluetoothError}
                .eraseToAnyPublisher()
            }
            .prefix(1)
            .filter { (charachteristic) -> Bool in
                if charachteristic.uuid == charateristicUUID {
                    return true
                }
                return false
            }
            .flatMap{ (_) -> AnyPublisher<CBCharacteristic, LittleBluetoothError> in
                self.stopListen(from: charateristicUUID, of: serviceUUID)
            }
            .map { charact -> Data? in
                charact.value
            }
            .eraseToAnyPublisher()
        return writeListen
    }
    
}

extension Peripheral: CustomDebugStringConvertible {
    /// Extended description of the peripheral
    public var debugDescription: String {
        return """
        Id: \(id)
        Name: \(name ?? "Not available")
        CBPeripheral: \(cbPeripheral)
        RSSI: \(rssi?.description ?? "Not available")
        """
    }
}

extension Peripheral: Loggable {}
