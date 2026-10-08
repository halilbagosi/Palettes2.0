//
//  IntentErrors.swift
//  Palettes
//

import AppIntents
import Foundation

@available(iOS 26.0, *)
enum PalettesIntentError: Error, CustomLocalizedStringResourceConvertible {
    case aiUnavailable
    case invalidHex(String)
    case paletteNotFound
    case colorNotFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .aiUnavailable:
            return "Apple Intelligence isn't available on this device, so palettes can't be generated."
        case .invalidHex(let value):
            return "'\(value)' isn't a valid hex color. Try something like #4A90D9."
        case .paletteNotFound:
            return "That palette couldn't be found in your library."
        case .colorNotFound:
            return "That color couldn't be found in your library."
        }
    }
}
