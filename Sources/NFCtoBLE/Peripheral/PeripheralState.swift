//
//  PeripheralState.swift
//  NFCtoBLE
//
//  Created by Yann Godeau on 24/05/2021.
//

/// - Tag: PeripheralState
public enum PeripheralState {
    case disconnecting
    case disconnected
    case connecting
    case connected
    case unavailable
    case ready
    case failedToConnect
    case discoveringServices
    case discoveringCharacteristics
}
