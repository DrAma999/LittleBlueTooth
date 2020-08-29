//
//  Listen.swift
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


// MARK: - Listen

extension Publisher where Self.Failure == LittleBluetoothError {

    /// Returns a  publisher with the `LittleBlueToothCharacteristic` where the notify command has been activated.
    /// After starting the listen command you should subscribe to the `listenPublisher` to be notified.
    /// - parameter littleBluetooth: the `LittleBlueTooth` instance
    /// - parameter characteristic: Characteristc you want to be notified.
    /// - returns: A  publisher with the `LittleBlueToothCharacteristic` where the notify command has been activated.
    /// - important: This publisher only activate the notification on a specific characteristic, it will not send notified values.
    /// After starting the listen command you should subscribe to the `listenPublisher` to be notified.
    public func enableListen(for littleBluetooth: LittleBlueTooth,
                             from characteristic: LittleBlueToothCharacteristic) -> AnyPublisher<LittleBlueToothCharacteristic, LittleBluetoothError> {
        
        func enableListen<Upstream: Publisher>(upstream: Upstream,
                                               for littleBluetooth: LittleBlueTooth,
                                               from characteristic: LittleBlueToothCharacteristic) -> AnyPublisher<LittleBlueToothCharacteristic, LittleBluetoothError> where Upstream.Failure == LittleBluetoothError {
            return upstream
                .flatMapLatest { _ in
                    littleBluetooth.enableListen(from: characteristic)
            }
        }
        
        return enableListen(upstream: self,
                            for: littleBluetooth,
                            from: characteristic)
    }
    
    /// Returns a shared publisher for listening to a specific characteristic.
    /// - parameter littleBluetooth: the `LittleBlueTooth` instance
    /// - parameter characteristic: Characteristc you want to be notified.
    /// - returns: A shared publisher that will send out values of the type defined by the generic type.
    /// - important: The type of the value must be conform to `Readable`
    public func startListen<T: Readable>(for littleBluetooth: LittleBlueTooth,
                                         from charact: LittleBlueToothCharacteristic) -> AnyPublisher<T, LittleBluetoothError> {
        
        func startListen<T: Readable, Upstream: Publisher>(upstream: Upstream,
                                                           for littleBluetooth: LittleBlueTooth,
                                                           from charact: LittleBlueToothCharacteristic) -> AnyPublisher<T, LittleBluetoothError> where Upstream.Failure == LittleBluetoothError {
            return upstream
                .flatMapLatest { _ in
                    littleBluetooth.startListen(from: charact)
            }
        }
        
        return startListen(upstream: self,
                           for: littleBluetooth,
                           from: charact)
    }

    /// Disable listen from a specific characteristic
    /// - parameter characteristic: characteristic you want to stop listen
    /// - returns: A publisher with that informs you about the successful or failed task
    public func disableListen(for littleBluetooth: LittleBlueTooth,
                              from characteristic: LittleBlueToothCharacteristic) -> AnyPublisher<LittleBlueToothCharacteristic, LittleBluetoothError> {
        func disableListen<Upstream: Publisher>(upstream: Upstream,
                                                for littleBluetooth: LittleBlueTooth,
                                                from characteristic: LittleBlueToothCharacteristic) -> AnyPublisher<LittleBlueToothCharacteristic, LittleBluetoothError> where Upstream.Failure == LittleBluetoothError {
            return upstream
                .flatMapLatest { _ in
                    littleBluetooth.disableListen(from: characteristic)
            }
        }
        return disableListen(upstream: self,
                             for: littleBluetooth,
                             from: characteristic)
    }
}
