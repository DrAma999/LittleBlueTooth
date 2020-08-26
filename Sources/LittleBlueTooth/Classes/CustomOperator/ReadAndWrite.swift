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

extension Publisher {
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
        
        let head = self.mapError {$0 as! LittleBluetoothError}
        return read(upstream: head,
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
        
        let head = self.mapError {$0 as! LittleBluetoothError}
        return write(upstream: head,
                     for: littleBluetooth,
                     from: characteristic,
                     value: value,
                     response: response,
                     timeout: timeout)
    }
    
}

