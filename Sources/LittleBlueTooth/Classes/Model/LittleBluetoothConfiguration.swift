//
//  LittleBluetoothConfiguration.swift
//  LittleBlueTooth
//
//  Created by Andrea Finollo on 26/07/2020.
//

import Foundation

/// Pass a `Peripheral` and an evetual `LittleBluetoothError` and expect a boolean as an answer
public typealias AutoconnectionHandler = (PeripheralIdentifier, LittleBluetoothError?) -> Bool

/// Configuration object that must be passed during the `LittleBlueTooth` initialization
public struct LittleBluetoothConfiguration {
    /// `CBCentralManager` options dictionary for instance the restore identifier, thay are the same
    /// requested for `CBCentralManager`
    public var centralManagerOptions: [String : Any]?
    /// `CBCentralManager` queue
    public var centralManagerQueue: DispatchQueue?
    /// This handler must be used to handle connection process after a disconnession.
    /// You can inspect the error and decide if an automatic connection is necessary.
    /// If you return `true` the connection process will start, once the peripheral has been found a connection will be established.
    /// If you return `false` the system will not try to establish a connection
    /// Connection process will remain active also in background if the app has the right
    /// permission, to cancel just call `disconnect`.
    /// When a connection will be established an `.autoConnected(PeripheralIdentifier)` event will be streamed to
    /// the `connectionEventPublisher`
    public var autoconnectionHandler: AutoconnectionHandler?
    /// Handler used to manage state restoration. `Restored` object will contain the restored information
    /// could be a peripheral, a scan or nothing
    public var restoreHandler: ((Restored) -> Void)?
    /// Enable logging, log is made using os_log and it exposes some information even in release configuration
    public var isLogEnabled = false
    
    public init() {}
}
