//
//  PeripheralManagerState.swift
//  NFCtoBLE
//
//  Created by Yann Godeau on 24/05/2021.
//

/// - Tag: PeripheralManagerState
public enum PeripheralManagerState {
    case idle
    case ready
    case scanning
    case unavailable

    var localizedState: String {
        switch self {
        case .idle:
            return ".idle"
        case .ready:
            return ".ready"
        case .scanning:
            return ".scanning"
        case .unavailable:
            return "unavailable"
        }
    }
}
