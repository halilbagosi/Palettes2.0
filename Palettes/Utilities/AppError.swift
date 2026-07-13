//
//  AppError.swift
//  Palettes
//
//  Created by Halil Bagosi on 28.2.26.
//

import Foundation

enum AppError: LocalizedError {
    case imageProcessingFailed
    case colorExtractionFailed
    case aiUnavailable
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "Failed to process the image. Please try another one."
        case .colorExtractionFailed:
            return "Could not extract distinct colors from the image. It might be too uniform."
        case .aiUnavailable:
            return "Apple Intelligence is not available on this device right now."
        case .generationFailed:
            return "Couldn't generate a palette. Please try again."
        }
    }
}
