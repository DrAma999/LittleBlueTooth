//
//  Connection.swift
//  LittleBlueTooth
//
//  Created by Andrea Finollo on 26/08/2020.
//

import Foundation
import Combine
import os.log
#if TEST
import CoreBluetoothMock
#else
import CoreBluetooth
#endif

extension Publisher {
    
    public func startDiscovery(for littleBluetooth: LittleBlueTooth, withServices services: [CBUUID]?, timeout: TimeInterval? = nil, options: [String : Any]? = nil) -> AnyPublisher<PeripheralDiscovery, LittleBluetoothError> {
        func startDiscovery<Upstream: Publisher>(upstream: Upstream,
                                                 for littleBluetooth: LittleBlueTooth,
                                                 withServices services: [CBUUID]?,
                                                 timeout: TimeInterval? = nil,
                                                 options: [String : Any]? = nil) -> AnyPublisher<PeripheralDiscovery, LittleBluetoothError> where Upstream.Failure == LittleBluetoothError {
            return upstream
                .flatMapLatest { _ in
                    littleBluetooth.startDiscovery(withServices: services, timeout: timeout, options: options)
            }
        }
        let head = self.mapError { $0 as! LittleBluetoothError}
        return startDiscovery(upstream: head,
                              for: littleBluetooth,
                              withServices: services,
                              timeout: timeout,
                              options: options)
    }
    
    public func connectToDiscovery(for littleBluetooth: LittleBlueTooth,
                 timeout: TimeInterval? = nil,
                 options: [String : Any]? = nil) -> AnyPublisher<Peripheral, LittleBluetoothError> {
        
        func connect<Upstream: Publisher>(upstream: Upstream,
                                          for littleBluetooth: LittleBlueTooth,
                                          timeout: TimeInterval? = nil,
                                          options: [String : Any]? = nil) -> AnyPublisher<Peripheral, LittleBluetoothError> where Upstream.Output == PeripheralDiscovery, Upstream.Failure == LittleBluetoothError {
            return upstream
            .flatMapLatest { (periph) in
                littleBluetooth.connect(to: PeripheralIdentifier(peripheral: periph.cbPeripheral), options: options)
            }.eraseToAnyPublisher()
        }
        
        let head = self.mapError { $0 as! LittleBluetoothError}.map{$0 as! PeripheralDiscovery}
        return connect(upstream: head,
                       for: littleBluetooth,
                       timeout: timeout,
                       options: options)
    }
    
    public func connectToIdentifier(for littleBluetooth: LittleBlueTooth,
                 timeout: TimeInterval? = nil,
                 options: [String : Any]? = nil) -> AnyPublisher<Peripheral, LittleBluetoothError> {
        
        func connect<Upstream: Publisher>(upstream: Upstream,
                                          for littleBluetooth: LittleBlueTooth,
                                          timeout: TimeInterval? = nil,
                                          options: [String : Any]? = nil) -> AnyPublisher<Peripheral, LittleBluetoothError> where Upstream.Output == PeripheralIdentifier, Upstream.Failure == LittleBluetoothError {
            return upstream
            .flatMapLatest { (periph) in
                littleBluetooth.connect(to: periph, options: options)
            }.eraseToAnyPublisher()
        }
        
        let head = self.mapError { $0 as! LittleBluetoothError}.map{$0 as! PeripheralIdentifier}
        return connect(upstream: head,
                       for: littleBluetooth,
                       timeout: timeout,
                       options: options)
    }
    // Disconnect
    @discardableResult
    public func disconnect(for littleBluetooth: LittleBlueTooth) -> AnyPublisher<Peripheral, LittleBluetoothError> {
        func disconnect<Upstream: Publisher>(upstream: Upstream,
                                             for littleBluetooth: LittleBlueTooth) -> AnyPublisher<Peripheral, LittleBluetoothError> where  Upstream.Failure == LittleBluetoothError {
            return upstream
            .flatMapLatest { _ in
                littleBluetooth.disconnect()
            }
        }
        let head = self.mapError { $0 as! LittleBluetoothError}
        return disconnect(upstream: head,
                          for: littleBluetooth)
    }
    // STOP Discovery
    public func stopDiscovery(for littleBluetooth: LittleBlueTooth) -> AnyPublisher<Void, LittleBluetoothError> {
        func stopDiscovery<Upstream: Publisher>(upstream: Upstream,
                                                for littleBluetooth: LittleBlueTooth) -> AnyPublisher<Void, LittleBluetoothError>where  Upstream.Failure == LittleBluetoothError {
            return upstream
            .flatMapLatest { _ in
                littleBluetooth.stopDiscovery()
            }
        }
        let head = self.mapError { $0 as! LittleBluetoothError}
               return stopDiscovery(upstream: head,
                                 for: littleBluetooth)
    }
}
