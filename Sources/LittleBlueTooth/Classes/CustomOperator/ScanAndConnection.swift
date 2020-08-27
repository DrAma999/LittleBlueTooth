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

extension Publisher where Self.Failure == LittleBluetoothError {
    
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
        return startDiscovery(upstream: self,
                              for: littleBluetooth,
                              withServices: services,
                              timeout: timeout,
                              options: options)
    }
}

extension Publisher where Self.Output == PeripheralDiscovery, Self.Failure == LittleBluetoothError {
    
    public func connect(for littleBluetooth: LittleBlueTooth,
                 timeout: TimeInterval? = nil,
                 options: [String : Any]? = nil) -> AnyPublisher<Peripheral, LittleBluetoothError> {
        
        func connect<Upstream: Publisher>(upstream: Upstream,
                                          for littleBluetooth: LittleBlueTooth,
                                          timeout: TimeInterval? = nil,
                                          options: [String : Any]? = nil) -> AnyPublisher<Peripheral, LittleBluetoothError> where Upstream.Output == PeripheralDiscovery, Upstream.Failure == LittleBluetoothError {
            return upstream
            .flatMapLatest { (periph) in
                littleBluetooth.connect(to: periph, options: options)
            }.eraseToAnyPublisher()
        }
        
        return connect(upstream: self,
                       for: littleBluetooth,
                       timeout: timeout,
                       options: options)
    }
}

extension Publisher where Self.Output == PeripheralIdentifier, Self.Failure == LittleBluetoothError {

    public func connect(for littleBluetooth: LittleBlueTooth,
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
        
        return connect(upstream: self,
                       for: littleBluetooth,
                       timeout: timeout,
                       options: options)
    }
}

extension Publisher where Self.Failure == LittleBluetoothError {
    
    @discardableResult
    public func disconnect(for littleBluetooth: LittleBlueTooth) -> AnyPublisher<Peripheral, LittleBluetoothError> {
        func disconnect<Upstream: Publisher>(upstream: Upstream,
                                             for littleBluetooth: LittleBlueTooth) -> AnyPublisher<Peripheral, LittleBluetoothError> where  Upstream.Failure == LittleBluetoothError {
            return upstream
            .flatMapLatest { _ in
                littleBluetooth.disconnect()
            }
        }
        return disconnect(upstream: self,
                          for: littleBluetooth)
    }


    public func stopDiscovery(for littleBluetooth: LittleBlueTooth) -> AnyPublisher<Void, LittleBluetoothError> {
        func stopDiscovery<Upstream: Publisher>(upstream: Upstream,
                                                for littleBluetooth: LittleBlueTooth) -> AnyPublisher<Void, LittleBluetoothError>where  Upstream.Failure == LittleBluetoothError {
            return upstream
            .flatMapLatest { _ in
                littleBluetooth.stopDiscovery()
            }
        }
        return stopDiscovery(upstream: self,
                                 for: littleBluetooth)
    }
}
