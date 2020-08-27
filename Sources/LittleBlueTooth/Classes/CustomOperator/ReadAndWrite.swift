//
//  ReadAndWrite.swift
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
    
    public func readRSSI(for littleBluetooth: LittleBlueTooth) -> AnyPublisher<Int, LittleBluetoothError> {
        
        func readRSSI<Upstream: Publisher>(upstream: Upstream,
                                           for littleBluetooth: LittleBlueTooth) -> AnyPublisher<Int, LittleBluetoothError> where Upstream.Failure == LittleBluetoothError {
            return upstream
                .flatMapLatest { _ in
                    littleBluetooth.readRSSI()
            }
        }
        return readRSSI(upstream: self,
                        for: littleBluetooth)
    }
    
    
    public func read<T: Readable>(for littleBluetooth: LittleBlueTooth,
                                  from characteristic: LittleBlueToothCharacteristic,
                                  timeout: TimeInterval? = nil) -> AnyPublisher<T, LittleBluetoothError> {
        
        func read<T: Readable, Upstream: Publisher>(upstream: Upstream,
                                                    for littleBluetooth: LittleBlueTooth,
                                                    from characteristic: LittleBlueToothCharacteristic,
                                                    timeout: TimeInterval? = nil) -> AnyPublisher<T, LittleBluetoothError> where Upstream.Failure == LittleBluetoothError {
            return upstream
                .flatMapLatest { _ in
                    littleBluetooth.read(from: characteristic, timeout: timeout)
            }
        }
        
        return read(upstream: self,
                    for: littleBluetooth,
                    from: characteristic,
                    timeout: timeout)
    }
    
    
    public func write<T: Writable>(for littleBluetooth: LittleBlueTooth,
                                   from characteristic: LittleBlueToothCharacteristic,
                                   value: T,
                                   response: Bool = true,
                                   timeout: TimeInterval? = nil) -> AnyPublisher<Void, LittleBluetoothError> {
        
        func write<T: Writable, Upstream: Publisher>(upstream: Upstream,
                                                     for littleBluetooth: LittleBlueTooth,
                                                     from characteristic: LittleBlueToothCharacteristic,
                                                     value: T,
                                                     response: Bool = true,
                                                     timeout: TimeInterval? = nil) -> AnyPublisher<Void, LittleBluetoothError> where  Upstream.Failure == LittleBluetoothError {
            return upstream
                .flatMapLatest { _ in
                    littleBluetooth.write(to: characteristic, timeout: timeout, value: value, response: response)
            }
        }
        
        return write(upstream: self,
                     for: littleBluetooth,
                     from: characteristic,
                     value: value,
                     response: response,
                     timeout: timeout)
    }
    
    public func writeAndListen<W: Writable, R: Readable>(for littleBluetooth: LittleBlueTooth,
                                                         from characteristic: LittleBlueToothCharacteristic,
                                                         timeout: TimeInterval? = nil,
                                                         value: W) -> AnyPublisher<R, LittleBluetoothError> {
        func writeAndListen<W: Writable, R: Readable, Upstream: Publisher>(upstream: Upstream,
                                                                           for littleBluetooth: LittleBlueTooth,
                                                                           from characteristic: LittleBlueToothCharacteristic,
                                                                           timeout: TimeInterval? = nil,
                                                                           value: W) -> AnyPublisher<R, LittleBluetoothError> where  Upstream.Failure == LittleBluetoothError {
           return upstream
                .flatMapLatest { _ in
                    littleBluetooth.writeAndListen(from: characteristic,
                                                   timeout: timeout,
                                                   value: value)
            }
        }
        return writeAndListen(upstream: self,
                              for: littleBluetooth,
                              from: characteristic,
                              value: value)
    }
    
}

