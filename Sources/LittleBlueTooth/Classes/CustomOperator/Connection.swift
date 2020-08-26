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

extension LittleBlueTooth {

func connect<Upstream: Publisher>(upstream: Upstream, timeout: TimeInterval? = nil, options: [String : Any]? = nil, queue: DispatchQueue = DispatchQueue.main) -> AnyPublisher<Peripheral, LittleBluetoothError> where Upstream.Output == PeripheralIdentifier, Upstream.Failure == LittleBluetoothError {
    return connect(to: Upstream.Output., options: options, queue: queue)
}
}
