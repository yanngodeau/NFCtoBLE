//
//  Logger.swift
//  NFCtoBLETests
//
//  Created by Yann Godeau on 30/05/2021.
//

import OSLog

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!

    static let nfctag = Logger(subsystem: subsystem, category: "nfctag")
    static let peripheral = Logger(subsystem: subsystem, category: "peripheral")
    static let peripheralManager = Logger(subsystem: subsystem, category: "peripheralManager")
}
