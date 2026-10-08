//
//  AppleIntelligenceCompat.swift
//  Palettes
//
//  Availability shim for Apple Intelligence–backed features (palette
//  generation). Gates on both the OS version and the hardware.
//

import Foundation
import FoundationModels

enum AppleIntelligence {
    /// Whether this device can run Apple Intelligence at all: iOS 26+ on
    /// eligible hardware. Devices that are eligible but have Apple
    /// Intelligence turned off (or the model still downloading) count as
    /// supported — GenerateView explains how to enable it there.
    ///
    /// The simulator always reports supported so the Generate flow stays
    /// developable, matching `GenerateView.isModelAvailable`.
    static var isDeviceSupported: Bool {
        #if targetEnvironment(simulator)
        if #available(iOS 26.0, *) { return true }
        return false
        #else
        guard #available(iOS 26.0, *) else { return false }
        if case .unavailable(.deviceNotEligible) = SystemLanguageModel.default.availability {
            return false
        }
        return true
        #endif
    }
}
