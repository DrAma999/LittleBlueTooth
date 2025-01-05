//
//  LittleBlueToothError.swift
//  LittleBlueTooth
//
//  Created by Andrea Finollo on 10/06/2020.
//  Copyright © 2020 Andrea Finollo. All rights reserved.
//

import Foundation
#if TEST
@preconcurrency import  CoreBluetoothMock
#else
@preconcurrency import CoreBluetooth
#endif


/// Collection of errors that can be returned by LittleBlueTooth
public enum LittleBluetoothError: Error {
    case bluetoothPoweredOff
    case bluetoothUnauthorized
    case bluetoothUnsupported
    case alreadyScanning
    case scanTimeout
    case connectTimeout
    case writeAndListenTimeout
    case readTimeout
    case writeTimeout
    case operationTimeout
    case invalidUUID(String)
    case serviceNotFound(Error?)
    case characteristicNotFound(Error?)
    case couldNotConnectToPeripheral(PeripheralIdentifier, Error?)
    case couldNotReadRSSI(Error)
    case couldNotReadFromCharacteristic(characteristic: CBUUID, error: Error)
    case couldNotWriteFromCharacteristic(characteristic: CBUUID, error: Error)
    case couldNotUpdateListenState(characteristic: CBUUID, error: Error)
    case emptyData
    case couldNotConvertDataToRead(data: Data, type: String)
    case peripheralNotConnected(state: PeripheralState)
    case peripheralAlreadyConnectedOrConnecting(Peripheral)
    case peripheralNotConnectedOrAlreadyDisconnected
    case peripheralNotFound
    case peripheralDisconnected(PeripheralIdentifier, Error?)
    case fullfillConditionNotRespected
    case deserializationFailedDataOfBounds(start: Int, length: Int, count: Int)
}
