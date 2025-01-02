//
//  LittleBlueToothTests.swift
//  LittleBlueToothTests
//
//  Created by Andrea Finollo on 10/06/2020.
//  Copyright © 2020 Andrea Finollo. All rights reserved.
//

import XCTest
@preconcurrency import CoreBluetoothMock
import Combine
@testable import LittleBlueToothForTest

class LittleBlueToothTests: XCTestCase {
    var littleBT: LittleBlueTooth!
    var disposeBag: Set<AnyCancellable> = []
    static var testInitialized: Bool = false
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        if !Self.testInitialized {
            CBMCentralManagerMock.simulatePeripherals([blinky, blinkyWOR])
            Self.testInitialized = true
        }
        CBMCentralManagerMock.simulateInitialState(.poweredOn)

    }
}
