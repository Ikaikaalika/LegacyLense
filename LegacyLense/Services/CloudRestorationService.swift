//
//  CloudRestorationService.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import Foundation
import UIKit
import Combine
import AWSCore
import AWSS3
import AWSLambda

@MainActor
class CloudRestorationService: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var currentStage = "Ready"
    @Published var uploadProgress: Double = 0.0
    @Published var processingProgress: Double = 0.0
    @Published var downloadProgress: Double = 0.0
    
    // AWS Configuration
    private let s3BucketName = "legacylense-processing"
    private let lambdaFunctionName = "legacylense-photo-processor"
    private let region = AWSRegionType.USEast1
    
    private var currentTask: URLSessionDataTask?
    private let urlSession: URLSession
    private var s3TransferUtility: AWSS3TransferUtility?
    private var lambdaInvoker: AWSLambdaInvoker?
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 3600.0 // 1 hour for processing
        self.urlSession = URLSession(configuration: config)
        
        setupAWS()
    }
    
    private func setupAWS() {
        // Configure AWS services
        let credentialsProvider = AWSCognitoCredentialsProvider(
            regionType: region,
            identityPoolId: "us-east-1:your-identity-pool-id" // TODO: Replace with actual pool ID
        )
        
        let configuration = AWSServiceConfiguration(
            region: region,
            credentialsProvider: credentialsProvider
        )
        
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        // Initialize S3 Transfer Utility
        s3TransferUtility = AWSS3TransferUtility.default()
        
        // Initialize Lambda Invoker
        lambdaInvoker = AWSLambdaInvoker.default()
    }
    
    func restorePhoto(_ image: UIImage, 
                     enabledStages: Set<PhotoRestorationModel.RestorationModelType>,
                     subscriptionManager: SubscriptionManager) async throws -> UIImage {
        
        // Check subscription access for cloud processing
        guard subscriptionManager.hasCloudProcessingAccess() else {
            throw CloudProcessingError.subscriptionRequired
        }
        
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
            // Step 1: Upload image to S3
            currentStage = "Uploading to AWS"
            let s3Key = try await uploadImageToS3(image)
            progress = 0.2
            
            // Step 2: Invoke Lambda function for processing
            currentStage = "Processing with AWS AI"
            let jobId = try await invokeLambdaFunction(s3Key: s3Key, enabledStages: enabledStages)
            progress = 0.3
            
            // Step 3: Poll for processing completion
            currentStage = "AI processing in progress"
            let resultS3Key = try await pollForAWSCompletion(jobId: jobId)
            
            // Step 4: Download processed image from S3
            currentStage = "Downloading result"
            let processedImage = try await downloadImageFromS3(s3Key: resultS3Key)
            
            return processedImage
            
        } catch {
            currentStage = "Error: \(error.localizedDescription)"
            throw error
        }
    }
    
    private func uploadImageToS3(_ image: UIImage) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw CloudProcessingError.imageConversionFailed
        }
        
        guard let s3TransferUtility = s3TransferUtility else {
            throw CloudProcessingError.awsNotConfigured
        }
        
        let s3Key = "input/\(UUID().uuidString).jpg"
        
        return try await withCheckedThrowingContinuation { continuation in
            let uploadExpression = AWSS3TransferUtilityUploadExpression()
            uploadExpression.progressBlock = { _, progress in
                DispatchQueue.main.async {
                    self.uploadProgress = progress.fractionCompleted
                    self.progress = progress.fractionCompleted * 0.2 // Upload is 20% of total
                }
            }
            
            s3TransferUtility.uploadData(
                imageData,
                bucket: s3BucketName,
                key: s3Key,
                contentType: "image/jpeg",
                expression: uploadExpression
            ) { task, error in
                DispatchQueue.main.async {
                    if let error = error {
                        continuation.resume(throwing: CloudProcessingError.awsUploadFailed(error.localizedDescription))
                    } else {
                        continuation.resume(returning: s3Key)
                    }
                }
            }
        }
    }
    
    private func invokeLambdaFunction(s3Key: String, enabledStages: Set<PhotoRestorationModel.RestorationModelType>) async throws -> String {
        guard let lambdaInvoker = lambdaInvoker else {
            throw CloudProcessingError.awsNotConfigured
        }
        
        let jobId = UUID().uuidString
        
        let payload: [String: Any] = [
            "jobId": jobId,
            "inputS3Key": s3Key,
            "bucket": s3BucketName,
            "enabledStages": enabledStages.map { $0.rawValue },
            "outputS3Key": "output/\(jobId).jpg"
        ]
        
        guard let payloadData = try? JSONSerialization.data(withJSONObject: payload) else {
            throw CloudProcessingError.invalidPayload
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = AWSLambdaInvocationRequest()
            request?.functionName = lambdaFunctionName
            request?.invocationType = .event // Async invocation
            request?.payload = payloadData
            
            lambdaInvoker.invoke(request!) { response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        continuation.resume(throwing: CloudProcessingError.lambdaInvocationFailed(error.localizedDescription))
                    } else {
                        continuation.resume(returning: jobId)
                    }
                }
            }
        }
    }
    
    private func pollForAWSCompletion(jobId: String) async throws -> String {
        let maxPollingTime: TimeInterval = 3600 // 1 hour
        let pollingInterval: TimeInterval = 10 // 10 seconds for AWS
        let startTime = Date()
        
        let outputS3Key = "output/\(jobId).jpg"
        
        while Date().timeIntervalSince(startTime) < maxPollingTime {
            // Check if output file exists in S3
            let exists = try await checkS3ObjectExists(s3Key: outputS3Key)
            
            if exists {
                progress = 1.0
                return outputS3Key
            }
            
            // Update progress based on time elapsed (rough estimate)
            let elapsed = Date().timeIntervalSince(startTime)
            let estimatedTotal: TimeInterval = 120 // 2 minutes average
            let progressValue = min(0.9, elapsed / estimatedTotal) // Cap at 90% until done
            progress = 0.3 + (progressValue * 0.6) // 30-90% of total progress
            processingProgress = progressValue
            
            try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
        }
        
        throw CloudProcessingError.timeout
    }
    
    private func checkS3ObjectExists(s3Key: String) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            let s3 = AWSS3.default()
            let headRequest = AWSS3HeadObjectRequest()
            headRequest?.bucket = s3BucketName
            headRequest?.key = s3Key
            
            s3.headObject(headRequest!) { response, error in
                DispatchQueue.main.async {
                    if error != nil {
                        // Object doesn't exist or error occurred
                        continuation.resume(returning: false)
                    } else {
                        // Object exists
                        continuation.resume(returning: true)
                    }
                }
            }
        }
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
    
    private func downloadImageFromS3(s3Key: String) async throws -> UIImage {
        guard let s3TransferUtility = s3TransferUtility else {
            throw CloudProcessingError.awsNotConfigured
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let downloadExpression = AWSS3TransferUtilityDownloadExpression()
            downloadExpression.progressBlock = { _, progress in
                DispatchQueue.main.async {
                    self.downloadProgress = progress.fractionCompleted
                    self.progress = 0.9 + (progress.fractionCompleted * 0.1) // Final 10%
                }
            }
            
            s3TransferUtility.downloadData(
                fromBucket: s3BucketName,
                key: s3Key,
                expression: downloadExpression
            ) { task, location, data, error in
                DispatchQueue.main.async {
                    if let error = error {
                        continuation.resume(throwing: CloudProcessingError.awsDownloadFailed(error.localizedDescription))
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
    case subscriptionRequired
    case awsNotConfigured
    case awsUploadFailed(String)
    case awsDownloadFailed(String)
    case lambdaInvocationFailed(String)
    case invalidPayload
    
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
        case .subscriptionRequired:
            return "Cloud processing requires a subscription. Please upgrade to access this feature."
        case .awsNotConfigured:
            return "AWS services not properly configured"
        case .awsUploadFailed(let message):
            return "Failed to upload to AWS: \(message)"
        case .awsDownloadFailed(let message):
            return "Failed to download from AWS: \(message)"
        case .lambdaInvocationFailed(let message):
            return "AWS processing failed: \(message)"
        case .invalidPayload:
            return "Invalid processing request"
        }
    }
}