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

// MARK: - Discover
extension Publisher where Self.Failure == LittleBluetoothError {
    /// Starts scanning for `PeripheralDiscovery`
    /// - parameter littleBluetooth: the `LittleBlueTooth` instance
    /// - parameter services: Services for peripheral you are looking for
    /// - parameter options: Scanning options same as  CoreBluetooth  central manager option.
    /// - returns: A publisher with stream of disovered peripherals.
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
    
    /// Stops peripheral discovery
    /// - parameter littleBluetooth: the `LittleBlueTooth` instance
    /// - returns: A publisher when discovery has been stopped
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

// MARK: - Connect
extension Publisher where Self.Output == PeripheralDiscovery, Self.Failure == LittleBluetoothError {
        
    /// Starts connection for `PeripheralDiscovery`
    /// - parameter littleBluetooth: the `LittleBlueTooth` instance
    /// - parameter options: Connecting options same as  CoreBluetooth  central manager option.
    /// - returns: A publisher with the just connected `Peripheral`.
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
    
    /// Starts connection for `PeripheralIdentifier`
    /// - parameter littleBluetooth: the `LittleBlueTooth` instance
    /// - parameter options: Connecting options same as  CoreBluetooth  central manager option.
    /// - returns: A publisher with the just connected `Peripheral`.
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

// MARK: - Disconnect
extension Publisher where Self.Failure == LittleBluetoothError {
    
    /// Disconnect the connected `Peripheral`
    /// - returns: A publisher with the just disconnected `Peripheral` or a `LittleBluetoothError`
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

    /// Specialized timeout function to return a `LittleBluetoothError` error type. By default it returns `.operationTimeout`, but you can specify a different error such as `.connectionTimeout`,  `.scanTimeout`
    /// Terminates publishing if the upstream publisher exceeds the specified time interval without producing an element.
    /// - Parameters:
    ///   - interval: The maximum time interval the publisher can go without emitting an element, expressed in the time system of the scheduler.
    ///   - scheduler: The scheduler to deliver events on.
    ///   - options: Scheduler options that customize the delivery of elements.
    ///   - error: An error to be returned if the publisher times out, by default `LittleBluetoothError.connectionTimeout`
    /// - Returns: A publisher that terminates if the specified interval elapses with no events received from the upstream publisher.
    public func timeout<S>(_ interval: S.SchedulerTimeType.Stride, scheduler: S, options: S.SchedulerOptions? = nil, error: LittleBluetoothError = .operationTimeout) -> AnyPublisher<Self.Output, LittleBluetoothError> where S: Scheduler {
        func timeout<Upstream: Publisher, S>(upsstream: Upstream,_ interval: S.SchedulerTimeType.Stride, scheduler: S, options: S.SchedulerOptions? = nil, error: LittleBluetoothError = .operationTimeout) -> AnyPublisher<Upstream.Output, LittleBluetoothError> where S: Scheduler, Upstream.Failure == LittleBluetoothError {
            return upsstream
                .timeout(interval, scheduler: scheduler, options: options, customError: {error})
                .eraseToAnyPublisher()
        }
        
        return timeout(upsstream: self, interval, scheduler: scheduler, options: options, error: error)
    }
    
}
