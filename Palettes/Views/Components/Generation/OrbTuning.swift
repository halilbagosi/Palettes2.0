//
//  OrbTuning.swift
//  Palettes
//
//  Every tunable number of the orb (generate + onboarding).
//

import SwiftUI

struct OrbTuning: Equatable {
    // Idle wobble
    var wobbleSpeed = 1.0
    var idleOval = 0.024
    var idleOvalSwell = 0.024
    var idleLobe = 0.008
    var idleDrift = 0.0075
    // Pull + release spring
    var pullAmount = 0.42
    var pullShift = 0.22
    var releaseResponse = 0.42
    var releaseDamping = 0.26
    // Rim refraction
    var glassRefraction = 0.7
    var refractionPower = 10.0
    // Shadow under the drop
    var shadowOpacity = 1.0
    var shadowBlur = 1.0
    // Color drops inside
    var dropSpeed = 0.7
    var dropOrbit = 0.2
    var dropSize = 0.52
    var dropOpacity = 0.7
    var dropBlur = 0.07
    var dropSaturation = 1.2
    // Onboarding window
    var windowSize = 0.86
    var featherStart = 0.2
    var featherReach = 0.8

    static let live = OrbTuning()
}
