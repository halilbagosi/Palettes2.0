//
//  IntentErrors.swift
//  Palettes
//

import AppIntents
import Foundation
import FoundationModels

@available(iOS 26.0, *)
enum PalettesIntentError: Error, Equatable, CustomLocalizedStringResourceConvertible {
    case aiUnavailable
    case aiDisabled
    case aiModelDownloading
    case aiDeviceIneligible
    case invalidHex(String)
    case paletteNotFound
    case colorNotFound
    case nameTaken(String, String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .aiUnavailable:
            return "Apple Intelligence isn't available on this device, so palettes can't be generated."
        case .aiDisabled:
            return "Apple Intelligence is turned off. Turn it on in Settings, then try again."
        case .aiModelDownloading:
            return "Apple Intelligence is still getting ready (the model is downloading). Try again in a little while."
        case .aiDeviceIneligible:
            return "This device doesn't support Apple Intelligence, so palettes can't be generated."
        case .invalidHex(let value):
            return "'\(value)' isn't a valid hex color. Try something like #4A90D9."
        case .paletteNotFound:
            return "That palette couldn't be found in your library."
        case .colorNotFound:
            return "That color couldn't be found in your library."
        case .nameTaken(let name, let hex):
            return "A color named '\(name)' already exists (\(hex)). Choose a different name."
        }
    }
}

@available(iOS 26.0, *)
extension PalettesIntentError {
    /// Maps model availability to a specific, actionable error; nil when available.
    static func error(for availability: SystemLanguageModel.Availability) -> PalettesIntentError? {
        switch availability {
        case .available:
            return nil
        case .unavailable(let reason):
            return error(for: reason)
        }
    }

    static func error(for reason: SystemLanguageModel.Availability.UnavailableReason) -> PalettesIntentError {
        switch reason {
        case .appleIntelligenceNotEnabled: return .aiDisabled
        case .modelNotReady: return .aiModelDownloading
        case .deviceNotEligible: return .aiDeviceIneligible
        @unknown default: return .aiUnavailable
        }
    }
}
