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

extension Publisher where Self.Failure == LittleBluetoothError {

    
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
    
//    public func connectableListenPublisher<T: Readable>(for littleBluetooth: LittleBlueTooth,
//                                                        for characteristic: LittleBlueToothCharacteristic,
//                                                        valueType: T.Type) ->  Publishers.MakeConnectable<AnyPublisher<T, LittleBluetoothError>> {
//        
//        func connectableListenPublisher<T: Readable, Upstream: Publisher>(upstream: Upstream,
//                                                                          for littleBluetooth: LittleBlueTooth, for characteristic: LittleBlueToothCharacteristic, valueType: T.Type) ->  Publishers.MakeConnectable<AnyPublisher<T, LittleBluetoothError>> where Upstream.Failure == LittleBluetoothError {
//            let up = upstream
//                .flatMapLatest { _ in
//                    littleBluetooth.connectableListenPublisher(for: characteristic,
//                                                               valueType: valueType)
//            }.eraseToAnyPublisher()
//            return Publishers.MakeConnectable(upstream: up)
//            
//        }
//        return connectableListenPublisher(upstream: self,
//                                          for: littleBluetooth,
//                                          for: characteristic,
//                                          valueType: valueType)
//
//    }

    
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
