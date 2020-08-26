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

func applyDelayAndRetry<Upstream:Publisher>(upstream:Upstream)
    -> AnyPublisher<Upstream.Output, Upstream.Failure> {
        let share = Publishers.Share(upstream: upstream)
        return share
            .catch { _ in
                share.delay(for: 3, scheduler: DispatchQueue.main)
            }.retry(3)
            .eraseToAnyPublisher()
}

func connect<Upstream:Publisher>(upstream:Upstream) {
    
}
