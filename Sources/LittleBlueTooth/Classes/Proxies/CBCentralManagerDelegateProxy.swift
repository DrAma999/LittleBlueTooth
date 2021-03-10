//
//  CBManagerDelegateProxy.swift
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
/// An enum representing the connection event that has occurred
public enum ConnectionEvent {
    /// Peripheral is connected but not ready to receive command
    case connected(CBPeripheral)
    /// Peripheral is connected after a disconnection automatically but not ready to receive command
    case autoConnected(CBPeripheral)
    /// Peripheral is ready to receive command
    case ready(CBPeripheral)
    /// Peripheral is not ready probaly due to some unexpected disconnection
    case notReady(CBPeripheral, error: LittleBluetoothError?)
    /// Process of connection has failed
    case connectionFailed(CBPeripheral, error: LittleBluetoothError?)
    /// Peripheral has been disconnected, if it was unexpected a `LittleBluetoothError` is returned
    case disconnected(CBPeripheral, error: LittleBluetoothError?)
}

/// An enumeration representing the state of the bluetooth stack of the device
public enum BluetoothState {
    /// Unknown, probably transient
    case unknown
    /// Bluetooth is resetting
    case resetting
    /// Bluetooth is not supported for this device
    case unsupported
    /// The application is not authorized to use bluetooth
    case unauthorized
    /// The bluetooth is off
    case poweredOff
    /// The bluetooth is on and ready
    case poweredOn
    
    /// Inizialize using a `CBManagerState`
    init(_ state: CBManagerState) {
        switch state {
        case .unknown:
            self = .unknown
        case .resetting:
            self = .resetting
        case .unsupported:
            self = .unsupported
        case .unauthorized:
            self = .unauthorized
        case .poweredOff:
            self = .poweredOff
        case .poweredOn:
            self = .poweredOn
        #if !TEST
        @unknown default:
            fatalError()
        #endif
        }
    }
}

class CBCentralManagerDelegateProxy: NSObject {
    
    let centralDiscoveriesPublisher = PassthroughSubject<PeripheralDiscovery, Never>()
    let connectionEventPublisher = PassthroughSubject<ConnectionEvent, Never>()
    lazy var centralStatePublisher: AnyPublisher<BluetoothState, Never>
        = {
            self._centralStatePublisher.eraseToAnyPublisher()
    }()

    lazy var willRestoreStatePublisher: AnyPublisher<CentralRestorer, Never> = {
        _willRestoreStatePublisher.shareReplay(1).eraseToAnyPublisher()
    }()
    
    let _centralStatePublisher = CurrentValueSubject<BluetoothState, Never>(.unknown)
    let _willRestoreStatePublisher = PassthroughSubject<CentralRestorer, Never>()

    var isLogEnabled: Bool = false
    var isAutoconnectionActive = false
    var stateRestorationCancellable: AnyCancellable!
    
    override init() {
        super.init()
        self.stateRestorationCancellable = willRestoreStatePublisher.sink { _ in }
    }
   
}

extension CBCentralManagerDelegateProxy: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        log("[LBT: CBCMD] DidUpdateState %{public}d",
            log: OSLog.LittleBT_Log_CentralManager,
            type: .debug,
            arg: central.state.rawValue)
       _centralStatePublisher.send(BluetoothState(central.state))
    }
    
    /// Scan
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        log("[LBT: CBCMD] DidDiscover %{public}@",
            log: OSLog.LittleBT_Log_CentralManager,
            type: .debug,
            arg: peripheral.description)
        let peripheraldiscovery = PeripheralDiscovery(peripheral, advertisement: advertisementData, rssi: RSSI)
        centralDiscoveriesPublisher.send(peripheraldiscovery)
    }
    
    /// Monitoring connection
    func centralManager(_ central: CBCentralManager, didConnect: CBPeripheral) {
        log("[LBT: CBCMD] DidConnect %{public}@",
            log: OSLog.LittleBT_Log_CentralManager,
            type: .debug,
            arg: didConnect.description)
        if isAutoconnectionActive {
            isAutoconnectionActive = false
            let event = ConnectionEvent.autoConnected(didConnect)
            connectionEventPublisher.send(event)
        } else {
            let event = ConnectionEvent.connected(didConnect)
            connectionEventPublisher.send(event)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral: CBPeripheral, error: Error?) {
        log("[LBT: CBCMD] DidDisconnect %{public}@, Error %{public}@",
            log: OSLog.LittleBT_Log_CentralManager,
            type: .debug,
            arg: didDisconnectPeripheral.description,
            error?.localizedDescription ?? "")
        isAutoconnectionActive = false
        var lttlError: LittleBluetoothError?
        if let error = error {
            lttlError = .peripheralDisconnected(PeripheralIdentifier(peripheral: didDisconnectPeripheral), error)
        }
        let event = ConnectionEvent.disconnected(didDisconnectPeripheral, error: lttlError)
        connectionEventPublisher.send(event)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect: CBPeripheral, error: Error?) {
        isAutoconnectionActive = false
        var lttlError: LittleBluetoothError?
        if let error = error {
            lttlError = .couldNotConnectToPeripheral(PeripheralIdentifier(peripheral: didFailToConnect), error)
        }
        let event = ConnectionEvent.connectionFailed(didFailToConnect, error: lttlError)
        connectionEventPublisher.send(event)
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        log("[LBT: CBCMD] WillRestoreState %{public}@",
            log: OSLog.LittleBT_Log_Restore,
            type: .debug,
            arg: dict.description)
        _willRestoreStatePublisher.send(CentralRestorer(centralManager: central, restoredInfo: dict))
    }
    
    #if !os(macOS)
    func centralManager(_ central: CBCentralManager, connectionEventDidOccur event: CBConnectionEvent, for peripheral: CBPeripheral) {}
    #endif
    
}

extension CBCentralManagerDelegateProxy: Loggable {}
