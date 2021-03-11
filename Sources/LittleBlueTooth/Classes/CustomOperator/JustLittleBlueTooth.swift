//
//  JustLittleBlueTooth.swift
//  LittleBlueTooth
//
//  Created by Andrea Finollo on 28/08/2020.
//

import Foundation
import Combine
/// Syntactic sugar to start a `LittleBlueTooth` pipeline
public var StartLittleBlueTooth: Result<(), LittleBluetoothError>.Publisher {
    Just(()).setFailureType(to: LittleBluetoothError.self)
}
