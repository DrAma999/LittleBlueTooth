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

public enum ConnectionEvent {
    case connected(CBPeripheral)
    case autoConnected(CBPeripheral)
    case ready(CBPeripheral)
    case notReady(CBPeripheral, error: LittleBluetoothError?)
    case connectionFailed(CBPeripheral, error: LittleBluetoothError?)
    case disconnected(CBPeripheral, error: LittleBluetoothError?)
}

public enum BluetoothState {

    case unknown
    case resetting
    case unsupported
    case unauthorized
    case poweredOff
    case poweredOn
    
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
        @unknown default:
            fatalError()
        }
    }
}

class CBCentralManagerDelegateProxy: NSObject {
    
    let centralDiscoveriesPublisher = PassthroughSubject<PeripheralDiscovery, Never>()
    let connectionEventPublisher = PassthroughSubject<ConnectionEvent, Never>()
    lazy var centralStatePublisher: AnyPublisher<BluetoothState, Never> = {
        _centralStatePublisher.shareReplay(1).eraseToAnyPublisher()
    }()
    lazy var willRestoreStatePublisher: AnyPublisher<CentralRestorer, Never> = {
        _willRestoreStatePublisher.shareReplay(1).eraseToAnyPublisher()
    }()
    
    let _centralStatePublisher = CurrentValueSubject<BluetoothState, Never>(BluetoothState.unknown)
    let _willRestoreStatePublisher = PassthroughSubject<CentralRestorer, Never>()

    
    var isAutoconnectionActive = false
    var stateRestorationCancellable: AnyCancellable!
    
    override init() {
        super.init()
        self.stateRestorationCancellable = willRestoreStatePublisher.sink { _ in }
    }
   
}

extension CBCentralManagerDelegateProxy: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
//        os_log("CBCMD DidUpdateState %{public}d", log: OSLog.LittleBT_Log_General, type: .debug, central.state.rawValue)
       _centralStatePublisher.send(BluetoothState(central.state))
    }
    
    /// Scan
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
//        os_log("CBCMD DidDiscover %{public}@", log: OSLog.LittleBT_Log_General, type: .debug, peripheral.description)
        let peripheraldiscovery = PeripheralDiscovery(peripheral, advertisement: advertisementData, rssi: RSSI)
        centralDiscoveriesPublisher.send(peripheraldiscovery)
    }
    
    /// Monitoring connection
    func centralManager(_ central: CBCentralManager, didConnect: CBPeripheral) {
//        os_log("CBCMD DidConnect %{public}@", log: OSLog.LittleBT_Log_General, type: .debug, didConnect.description)
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
//        #if !TEST
//        os_log("CBCMD DidDisconnect %{public}@, Error %{public}@", log: OSLog.LittleBT_Log_General, type: .debug, didDisconnectPeripheral.description, error?.localizedDescription ?? "")
//        #endif
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
//        os_log("CBCMD WillRestoreState %{public}@", log: OSLog.LittleBT_Log_General, type: .debug, dict.description)
        _willRestoreStatePublisher.send(CentralRestorer(centralManager: central, restoredInfo: dict))
    }
    
    #if !os(macOS)
    func centralManager(_ central: CBCentralManager, connectionEventDidOccur event: CBConnectionEvent, for peripheral: CBPeripheral) {}
    #endif
    
}
