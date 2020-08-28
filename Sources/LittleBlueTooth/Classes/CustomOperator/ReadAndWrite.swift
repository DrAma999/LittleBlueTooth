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
    // MARK: - RSSI
    /// Returns a  publisher with the `Int`value of the RSSI.
    /// - parameter littleBluetooth: the `LittleBlueTooth` instance
    /// - returns: A  publisher with the `Int` value of the RSSI..
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
    
    // MARK: - Read
    
    /// Read a value from a specific charteristic
    /// - parameter littleBluetooth: the `LittleBlueTooth` instance
    /// - parameter characteristic: characteristic where you want to read
    /// - returns: A publisher with the value you want to read.
    /// - important: The type of the value must be conform to `Readable`
    public func read<T: Readable>(for littleBluetooth: LittleBlueTooth,
                                  from characteristic: LittleBlueToothCharacteristic) -> AnyPublisher<T, LittleBluetoothError> {
        
        func read<T: Readable, Upstream: Publisher>(upstream: Upstream,
                                                    for littleBluetooth: LittleBlueTooth,
                                                    from characteristic: LittleBlueToothCharacteristic) -> AnyPublisher<T, LittleBluetoothError> where Upstream.Failure == LittleBluetoothError {
            return upstream
                .flatMapLatest { _ in
                    littleBluetooth.read(from: characteristic)
            }
        }
        
        return read(upstream: self,
                    for: littleBluetooth,
                    from: characteristic)
    }
    
    // MARK: - Write

    /// Write a value to a specific charteristic
    /// - parameter littleBluetooth: the `LittleBlueTooth` instance
    /// - parameter characteristic: characteristic where you want to write
    /// - parameter value: The value you want to write
    /// - parameter response: An optional `Bool` value that will look for error after write operation
    /// - returns: A publisher with that informs you about eventual error
    /// - important: The type of the value must be conform to `Writable`
    public func write<T: Writable>(for littleBluetooth: LittleBlueTooth,
                                   from characteristic: LittleBlueToothCharacteristic,
                                   value: T,
                                   response: Bool = true) -> AnyPublisher<Void, LittleBluetoothError> {
        
        func write<T: Writable, Upstream: Publisher>(upstream: Upstream,
                                                     for littleBluetooth: LittleBlueTooth,
                                                     from characteristic: LittleBlueToothCharacteristic,
                                                     value: T,
                                                     response: Bool = true) -> AnyPublisher<Void, LittleBluetoothError> where  Upstream.Failure == LittleBluetoothError {
            return upstream
                .flatMapLatest { _ in
                    littleBluetooth.write(to: characteristic, value: value, response: response)
            }
        }
        
        return write(upstream: self,
                     for: littleBluetooth,
                     from: characteristic,
                     value: value,
                     response: response)
    }
    
    /// Write a value to a specific charteristic and wait for a response
    /// - parameter littleBluetooth: the `LittleBlueTooth` instance
    /// - parameter characteristic: characteristic where you want to write and listen
    /// - parameter value: The value you want to write must conform to `Writable`
    /// - returns: A publisher with that post and error or the response of the write requests.
    /// - important: Written value must conform to `Writable`, response must conform to `Readable`
    public func writeAndListen<W: Writable, R: Readable>(for littleBluetooth: LittleBlueTooth,
                                                         from characteristic: LittleBlueToothCharacteristic,
                                                         value: W) -> AnyPublisher<R, LittleBluetoothError> {
        func writeAndListen<W: Writable, R: Readable, Upstream: Publisher>(upstream: Upstream,
                                                                           for littleBluetooth: LittleBlueTooth,
                                                                           from characteristic: LittleBlueToothCharacteristic,
                                                                           value: W) -> AnyPublisher<R, LittleBluetoothError> where  Upstream.Failure == LittleBluetoothError {
           return upstream
                .flatMapLatest { _ in
                    littleBluetooth.writeAndListen(from: characteristic,
                                                   value: value)
            }
        }
        return writeAndListen(upstream: self,
                              for: littleBluetooth,
                              from: characteristic,
                              value: value)
    }
    
}

