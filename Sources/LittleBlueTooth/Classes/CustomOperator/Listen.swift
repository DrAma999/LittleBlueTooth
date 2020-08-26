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

extension Publisher {
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
        
        let head = self.mapError {$0 as! LittleBluetoothError}
        return startListen(upstream: head,
                           for: littleBluetooth,
                           from: charact)
    }
    
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
        
        let head = self.mapError {$0 as! LittleBluetoothError}
        return enableListen(upstream: head,
                            for: littleBluetooth,
                            from: characteristic)
    }

    
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
        let head = self.mapError {$0 as! LittleBluetoothError}
        return disableListen(upstream: head,
                             for: littleBluetooth,
                             from: characteristic)
    }
}
