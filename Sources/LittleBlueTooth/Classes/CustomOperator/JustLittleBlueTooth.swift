//
//  JustLittleBlueTooth.swift
//  LittleBlueTooth
//
//  Created by Andrea Finollo on 28/08/2020.
//

import Foundation
import Combine

public let StartLittleBlueTooth = Just(()).setFailureType(to: LittleBluetoothError.self)
