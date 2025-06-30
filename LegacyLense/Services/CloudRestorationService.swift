//
//  CloudRestorationService.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import Foundation
import UIKit
import Combine

@MainActor
class CloudRestorationService: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var currentStage = "Ready"
    @Published var uploadProgress: Double = 0.0
    @Published var processingProgress: Double = 0.0
    @Published var downloadProgress: Double = 0.0
    
    private let baseURL = "https://api.legacylense.com/v1"
    private var currentTask: URLSessionDataTask?
    private let urlSession: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 3600.0 // 1 hour for processing
        self.urlSession = URLSession(configuration: config)
    }
    
    func restorePhoto(_ image: UIImage, 
                     enabledStages: Set<PhotoRestorationModel.RestorationModelType>) async throws -> UIImage {
        
        guard !isProcessing else {
            throw CloudProcessingError.alreadyProcessing
        }
        
        isProcessing = true
        progress = 0.0
        currentStage = "Preparing upload"
        
        defer {
            isProcessing = false
            currentStage = "Completed"
        }
        
        do {
            // Step 1: Upload image
            currentStage = "Uploading image"
            let jobId = try await uploadImage(image, enabledStages: enabledStages)
            
            // Step 2: Poll for processing completion
            currentStage = "Processing image"
            let processedImageURL = try await pollForCompletion(jobId: jobId)
            
            // Step 3: Download processed image
            currentStage = "Downloading result"
            let processedImage = try await downloadProcessedImage(from: processedImageURL)
            
            return processedImage
            
        } catch {
            currentStage = "Error: \(error.localizedDescription)"
            throw error
        }
    }
    
    private func uploadImage(_ image: UIImage, 
                            enabledStages: Set<PhotoRestorationModel.RestorationModelType>) async throws -> String {
        
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw CloudProcessingError.imageConversionFailed
        }
        
        let url = URL(string: "\(baseURL)/restore")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var formData = Data()
        
        // Add image data
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        formData.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        formData.append(imageData)
        formData.append("\r\n".data(using: .utf8)!)
        
        // Add enabled stages
        for stage in enabledStages {
            formData.append("--\(boundary)\r\n".data(using: .utf8)!)
            formData.append("Content-Disposition: form-data; name=\"stages[]\"\r\n\r\n".data(using: .utf8)!)
            formData.append("\(stage.rawValue)\r\n".data(using: .utf8)!)
        }
        
        formData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = urlSession.uploadTask(with: request, from: formData) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.resume(throwing: CloudProcessingError.invalidResponse)
                        return
                    }
                    
                    guard httpResponse.statusCode == 200 else {
                        continuation.resume(throwing: CloudProcessingError.serverError(httpResponse.statusCode))
                        return
                    }
                    
                    guard let data = data else {
                        continuation.resume(throwing: CloudProcessingError.noData)
                        return
                    }
                    
                    do {
                        let response = try JSONDecoder().decode(UploadResponse.self, from: data)
                        continuation.resume(returning: response.jobId)
                    } catch {
                        continuation.resume(throwing: CloudProcessingError.decodingFailed)
                    }
                }
            }
            
            self.currentTask = task
            task.resume()
        }
    }
    
    private func pollForCompletion(jobId: String) async throws -> String {
        let maxPollingTime: TimeInterval = 3600 // 1 hour
        let pollingInterval: TimeInterval = 5 // 5 seconds
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < maxPollingTime {
            let status = try await checkJobStatus(jobId: jobId)
            
            switch status.status {
            case "completed":
                if let resultURL = status.resultURL {
                    return resultURL
                } else {
                    throw CloudProcessingError.missingResult
                }
                
            case "processing":
                progress = 0.3 + (status.progress * 0.4) // 30-70% of total progress
                processingProgress = status.progress
                
            case "failed":
                throw CloudProcessingError.processingFailed(status.error ?? "Unknown error")
                
            case "queued":
                currentStage = "Queued for processing"
                
            default:
                break
            }
            
            try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
        }
        
        throw CloudProcessingError.timeout
    }
    
    private func checkJobStatus(jobId: String) async throws -> JobStatusResponse {
        let url = URL(string: "\(baseURL)/status/\(jobId)")!
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = urlSession.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let data = data else {
                        continuation.resume(throwing: CloudProcessingError.noData)
                        return
                    }
                    
                    do {
                        let status = try JSONDecoder().decode(JobStatusResponse.self, from: data)
                        continuation.resume(returning: status)
                    } catch {
                        continuation.resume(throwing: CloudProcessingError.decodingFailed)
                    }
                }
            }
            
            task.resume()
        }
    }
    
    private func downloadProcessedImage(from urlString: String) async throws -> UIImage {
        guard let url = URL(string: urlString) else {
            throw CloudProcessingError.invalidURL
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = urlSession.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let data = data else {
                        continuation.resume(throwing: CloudProcessingError.noData)
                        return
                    }
                    
                    guard let image = UIImage(data: data) else {
                        continuation.resume(throwing: CloudProcessingError.imageDecodingFailed)
                        return
                    }
                    
                    self.progress = 1.0
                    self.downloadProgress = 1.0
                    continuation.resume(returning: image)
                }
            }
            
            task.resume()
        }
    }
    
    func cancelProcessing() {
        currentTask?.cancel()
        currentTask = nil
        isProcessing = false
        progress = 0.0
        uploadProgress = 0.0
        processingProgress = 0.0
        downloadProgress = 0.0
        currentStage = "Cancelled"
    }
    
    func getProcessingStatus() -> (stage: String, progress: Double) {
        return (currentStage, progress)
    }
}

// MARK: - Response Models
private struct UploadResponse: Codable {
    let jobId: String
    let status: String
}

private struct JobStatusResponse: Codable {
    let jobId: String
    let status: String
    let progress: Double
    let resultURL: String?
    let error: String?
    let estimatedTimeRemaining: Int?
}

// MARK: - Error Types
enum CloudProcessingError: LocalizedError {
    case alreadyProcessing
    case imageConversionFailed
    case invalidResponse
    case serverError(Int)
    case noData
    case decodingFailed
    case processingFailed(String)
    case timeout
    case missingResult
    case invalidURL
    case imageDecodingFailed
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .alreadyProcessing:
            return "Cloud processing is already in progress"
        case .imageConversionFailed:
            return "Failed to convert image for upload"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error: \(code)"
        case .noData:
            return "No data received from server"
        case .decodingFailed:
            return "Failed to decode server response"
        case .processingFailed(let message):
            return "Processing failed: \(message)"
        case .timeout:
            return "Processing timed out"
        case .missingResult:
            return "Processing completed but result is missing"
        case .invalidURL:
            return "Invalid download URL"
        case .imageDecodingFailed:
            return "Failed to decode processed image"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}