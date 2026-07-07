//
//  AppError.swift
//  Palettes
//
//  Created by Halil Bagosi on 28.2.26.
//

import Foundation

enum AppError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidData
    case unableToComplete
    case imageProcessingFailed
    case colorExtractionFailed
    case invalidHex(String)
    case emptyPaletteName
    case aiUnavailable
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL provided was invalid."
        case .invalidResponse:
            return "Invalid response from the server. Please try again."
        case .invalidData:
            return "The data received from the server was invalid. Please try again."
        case .unableToComplete:
            return "Unable to complete your request. Please check your internet connection."
        case .imageProcessingFailed:
            return "Failed to process the image. Please try another one."
        case .colorExtractionFailed:
            return "Could not extract distinct colors from the image. It might be too uniform."
        case .invalidHex(let hex):
            return "The hex code '\(hex)' is invalid."
        case .emptyPaletteName:
            return "Palette name cannot be empty."
        case .aiUnavailable:
            return "Apple Intelligence is not available on this device right now."
        case .generationFailed:
            return "Couldn't generate a palette. Please try again."
        }
    }
}
