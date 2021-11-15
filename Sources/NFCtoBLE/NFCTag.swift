//
//  NFCTag.swift
//  NFCtoBLE
//
//  Created by Yann Godeau on 05/05/2021.
//

import CoreNFC
import SwiftUI
import SimplyNFC
import CoreBluetooth
import OSLog

/// Represents the NFC tag used to establish a connection with a BLE device.
@propertyWrapper
public class NFCTag<T: Codable> {
    public typealias DidRead = (NFCManager, Result<CodableTag<T>, Error>) -> Void

    // MARK: - Properties
    public var wrappedValue: T?
    public var pairingKey: String?

    private var connectedPeripheral: Peripheral?
    private let nfcManager         = NFCManager()
    private var peripheralManager  = PeripheralManager()

    // MARK: - Initializer
    public init(pairingKey: String) {
        self.pairingKey           = pairingKey
    }

    public init(wrappedValue value: T?, pairingKey: String?) {
        self.wrappedValue         = value
        self.pairingKey           = pairingKey
    }

    // MARK: - Functions

    /// Starts reading NFC tag
    /// - Parameter didBecomeActive: Gets called when the nfc session  has started.
    /// - Parameter didRead: Gets called when the manager has read NFC tag or occurs some errors.
    public func read(didBecomeActive: NFCManager.DidBecomeActive? = nil, didRead: @escaping DidRead) {
        nfcManager.read(didBecomeActive: didBecomeActive) { [weak self] _, result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                didRead(self.nfcManager, .failure(error))
            case .success:
                guard let payload = try? result.get()?.records.first?.payload,
                      let decoded = try? JSONDecoder().decode(CodableTag<T>.self, from: payload) else {
                    return
                }
                self.pairingKey = decoded.pairingKey
                self.wrappedValue = decoded.value

                didRead(self.nfcManager, .success(decoded))
            }
        }
    }

    /// Starts writing the `@NFCTag`  property as [CodableTag](x-source-tag://CodableTag) on NFC tag
    /// - Parameter didBecomeActive:  Gets called when the nfc session  has started.
    /// - Parameter didWrite: Gets called when the manager has written NFC tag or occurs some errors.
    public func write(didBecomeActive: NFCManager.DidBecomeActive? = nil, didWrite: @escaping DidRead) {
        let codable = CodableTag<T>(pairingKey: self.pairingKey, value: self.wrappedValue)

        guard let data = try? JSONEncoder().encode(codable) else {
            return
        }

        let payload = NFCNDEFPayload( format: .unknown,
                                      type: Data(),
                                      identifier: Data(),
                                      payload: data)
        let message = NFCNDEFMessage(records: [payload])

        nfcManager.write(message: message, didBecomeActive: didBecomeActive) { manager, result in
            switch result {
            case .failure(let error):
                Logger.nfctag.error("Failed to write tag : \(error.localizedDescription)")
                didWrite(manager, .failure(error))
            case .success:
                Logger.nfctag.error("Successfully write tag")
                didWrite(manager, .success(codable))
            }
        }
    }

    /// Scans an NFC tag and tries to connect to the associated peripheral using the readed pairing key
    /// - Parameter services: Target services to be used
    /// - Parameter didBecomeActive: Gets called when the NFC session has becomes active
    /// - Parameter didRead: Gets called when the manager has read  a tag or occurs some errors
    /// - Parameter didConnect: Gets called when the manager has paired  with a peripheral
    public func scanToConnect(withServices services: [CBUUID]? = nil,
                              didBecomeActive: NFCManager.DidBecomeActive? = nil,
                              didRead: DidRead? = nil,
                              didConnect: @escaping DidConnect) {
        nfcManager.read(didBecomeActive: didBecomeActive) { [weak self] _, result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                Logger.nfctag.error("Failed to read tag: \(error.localizedDescription)")
                didRead?(self.nfcManager, .failure(error))
            case .success:
                guard let payload = try? result.get()?.records.first?.payload,
                      let decoded = try? JSONDecoder().decode(CodableTag<T>.self, from: payload) else {
                    Logger.nfctag.error("Failed to connect to peripheral: unable to decode payload")
                    didRead?(self.nfcManager, .failure(TagError.decodingError))
                    return
                }
                guard let pairingKey = decoded.pairingKey else {
                    Logger.nfctag.error("Failed to connect to peripheral: nil pairing key found")
                    didRead?(self.nfcManager, .failure(TagError.nilPairingKey))
                    return
                }
                self.pairingKey = pairingKey
                self.wrappedValue = decoded.value
                Logger.nfctag.info("Successfully read tag")
                didRead?(self.nfcManager, .success(decoded))
                self.connectToPeripheral(withPairingKey: pairingKey,
                                         withServices: services,
                                         didConnect: didConnect)
            }
        }
    }

    public func disconnect(didDisconnect: @escaping () -> Void) {
        guard let peripheral = self.connectedPeripheral else {
            didDisconnect()
            return
        }
        peripheralManager.disconnect(from: peripheral)
        self.connectedPeripheral = nil
        didDisconnect()
    }

    // MARK: - Private functions
    private func connectToPeripheral(withPairingKey pairingKey: String,
                                     withServices services: [CBUUID]?,
                                     didConnect: @escaping DidConnect) {
        peripheralManager.scanForPeripherals { [weak self] manager, discoveredPeripheral, discoveredPairingKey in
            if pairingKey == discoveredPairingKey {
                self?.peripheralManager.stopScan()
                self?.peripheralManager.connect(to: discoveredPeripheral, withServices: services) { _, result in
                    switch result {
                    case .failure(let error):
                        Logger.nfctag.error("Failed to connect to a peripheral \(error.localizedDescription)")
                        didConnect(manager, .failure(error))
                    case .success:
                        Logger.nfctag.info("Connected to peripheral \(discoveredPeripheral.name)")
                        self?.connectedPeripheral = discoveredPeripheral
                        didConnect(manager, .success(discoveredPeripheral))
                    }
                }
            }
        }
    }
}

public enum TagError: Error {
    case nilPairingKey
    case decodingError
}

/// - Tag: CodableTag
public struct CodableTag<T: Codable>: Codable {
    var pairingKey: String?
    var value: T?

    init(pairingKey: String?, value: T? = nil) {
        self.pairingKey = pairingKey
        self.value = value
    }
}
