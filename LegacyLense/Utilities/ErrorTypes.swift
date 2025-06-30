//
//  ErrorTypes.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import Foundation

// MARK: - General Application Errors

enum LegacyLenseError: LocalizedError {
    case invalidConfiguration
    case serviceUnavailable
    case operationCancelled
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Application configuration is invalid"
        case .serviceUnavailable:
            return "Service is currently unavailable"
        case .operationCancelled:
            return "Operation was cancelled"
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidConfiguration:
            return "Please restart the app or contact support"
        case .serviceUnavailable:
            return "Please check your internet connection and try again"
        case .operationCancelled:
            return "You can restart the operation if needed"
        case .unknownError:
            return "Please try again or contact support if the problem persists"
        }
    }
}

// MARK: - Photo Processing Errors

enum PhotoProcessingError: LocalizedError {
    case invalidImageFormat
    case imageTooLarge(maxSize: String)
    case imageTooSmall(minSize: String)
    case corruptedImage
    case processingTimeout
    case insufficientMemory
    case processingFailed(stage: String)
    case modelNotLoaded(modelName: String)
    case unsupportedOperation
    
    var errorDescription: String? {
        switch self {
        case .invalidImageFormat:
            return "Unsupported image format"
        case .imageTooLarge(let maxSize):
            return "Image is too large (max: \(maxSize))"
        case .imageTooSmall(let minSize):
            return "Image is too small (min: \(minSize))"
        case .corruptedImage:
            return "Image file is corrupted"
        case .processingTimeout:
            return "Processing timed out"
        case .insufficientMemory:
            return "Not enough memory to process this image"
        case .processingFailed(let stage):
            return "Processing failed at stage: \(stage)"
        case .modelNotLoaded(let modelName):
            return "AI model '\(modelName)' is not loaded"
        case .unsupportedOperation:
            return "This operation is not supported on your device"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidImageFormat:
            return "Please use JPEG, PNG, or HEIC format"
        case .imageTooLarge:
            return "Please reduce image size or resolution"
        case .imageTooSmall:
            return "Please use a higher resolution image"
        case .corruptedImage:
            return "Please try a different image"
        case .processingTimeout:
            return "Try processing with a smaller image or check your connection"
        case .insufficientMemory:
            return "Close other apps and try again with a smaller image"
        case .processingFailed:
            return "Try processing again or contact support"
        case .modelNotLoaded:
            return "Download the required AI model in Settings"
        case .unsupportedOperation:
            return "This feature requires a newer device or iOS version"
        }
    }
}

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case noConnection
    case timeout
    case serverError(code: Int)
    case invalidResponse
    case rateLimited
    case authenticationFailed
    case paymentRequired
    case serviceOverloaded
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection"
        case .timeout:
            return "Request timed out"
        case .serverError(let code):
            return "Server error (\(code))"
        case .invalidResponse:
            return "Invalid server response"
        case .rateLimited:
            return "Too many requests"
        case .authenticationFailed:
            return "Authentication failed"
        case .paymentRequired:
            return "Payment required"
        case .serviceOverloaded:
            return "Service is overloaded"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noConnection:
            return "Check your internet connection and try again"
        case .timeout:
            return "Check your connection and try again"
        case .serverError:
            return "Please try again later"
        case .invalidResponse:
            return "Please try again or contact support"
        case .rateLimited:
            return "Please wait a moment before trying again"
        case .authenticationFailed:
            return "Please sign in again"
        case .paymentRequired:
            return "Please upgrade your subscription or purchase credits"
        case .serviceOverloaded:
            return "Please try again in a few minutes"
        }
    }
}

// MARK: - Storage Errors

enum StorageError: LocalizedError {
    case insufficientSpace(required: String)
    case accessDenied
    case fileNotFound
    case corruptedData
    case writeError
    case readError
    
    var errorDescription: String? {
        switch self {
        case .insufficientSpace(let required):
            return "Insufficient storage space (need \(required))"
        case .accessDenied:
            return "Storage access denied"
        case .fileNotFound:
            return "File not found"
        case .corruptedData:
            return "Data is corrupted"
        case .writeError:
            return "Failed to write data"
        case .readError:
            return "Failed to read data"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .insufficientSpace:
            return "Free up storage space and try again"
        case .accessDenied:
            return "Please grant storage permissions in Settings"
        case .fileNotFound:
            return "The file may have been moved or deleted"
        case .corruptedData:
            return "Try downloading or creating the file again"
        case .writeError:
            return "Check available storage space and permissions"
        case .readError:
            return "Check if the file exists and is accessible"
        }
    }
}

// MARK: - Permission Errors

enum PermissionError: LocalizedError {
    case photoLibraryDenied
    case cameraDenied
    case notificationsDenied
    case locationDenied
    
    var errorDescription: String? {
        switch self {
        case .photoLibraryDenied:
            return "Photo library access denied"
        case .cameraDenied:
            return "Camera access denied"
        case .notificationsDenied:
            return "Notifications access denied"
        case .locationDenied:
            return "Location access denied"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .photoLibraryDenied:
            return "Please enable photo library access in Settings > Privacy & Security > Photos"
        case .cameraDenied:
            return "Please enable camera access in Settings > Privacy & Security > Camera"
        case .notificationsDenied:
            return "Please enable notifications in Settings > Notifications"
        case .locationDenied:
            return "Please enable location access in Settings > Privacy & Security > Location Services"
        }
    }
}

// MARK: - Error Handling Utilities

struct ErrorHandler {
    static func userFriendlyMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError {
            return localizedError.errorDescription ?? "An unknown error occurred"
        }
        
        // Handle common system errors
        let nsError = error as NSError
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet:
            return "No internet connection available"
        case NSURLErrorTimedOut:
            return "Request timed out"
        case NSURLErrorCannotFindHost:
            return "Cannot connect to server"
        case NSURLErrorNetworkConnectionLost:
            return "Network connection lost"
        default:
            return "An unexpected error occurred"
        }
    }
    
    static func recoverySuggestion(for error: Error) -> String? {
        if let localizedError = error as? LocalizedError {
            return localizedError.recoverySuggestion
        }
        
        let nsError = error as NSError
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet:
            return "Check your internet connection and try again"
        case NSURLErrorTimedOut:
            return "Check your connection and try again"
        case NSURLErrorCannotFindHost:
            return "Check your internet connection and try again later"
        case NSURLErrorNetworkConnectionLost:
            return "Please check your connection and try again"
        default:
            return "Please try again or contact support if the problem persists"
        }
    }
    
    static func shouldRetry(_ error: Error) -> Bool {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .timeout, .serverError, .serviceOverloaded:
                return true
            default:
                return false
            }
        }
        
        let nsError = error as NSError
        switch nsError.code {
        case NSURLErrorTimedOut,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorCannotConnectToHost:
            return true
        default:
            return false
        }
    }
    
    static func isTemporary(_ error: Error) -> Bool {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .timeout, .serviceOverloaded, .rateLimited:
                return true
            default:
                return false
            }
        }
        
        return shouldRetry(error)
    }
}

// MARK: - Error Reporting

protocol ErrorReporting {
    func reportError(_ error: Error, context: [String: Any]?)
}

class ErrorReporter: ErrorReporting {
    static let shared = ErrorReporter()
    
    private init() {}
    
    func reportError(_ error: Error, context: [String: Any]? = nil) {
        // In a real app, this would send error reports to a service like Crashlytics
        print("Error reported: \(error)")
        if let context = context {
            print("Context: \(context)")
        }
        
        // Log to console in debug mode
        #if DEBUG
        print("Error details: \(error.localizedDescription)")
        if let localizedError = error as? LocalizedError {
            print("Recovery suggestion: \(localizedError.recoverySuggestion ?? "None")")
        }
        #endif
    }
}

// MARK: - Result Extensions

extension Result {
    var error: Failure? {
        switch self {
        case .failure(let error):
            return error
        case .success:
            return nil
        }
    }
    
    var value: Success? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }
}