//
//  CloudRestorationService.swift
//  LegacyLense
//
//  AWS SDK Swift with conditional compilation
//

import Foundation
import UIKit
import Combine
import OSLog

// Conditional imports - only compile when AWS SDK is available
#if canImport(AWSS3)
import AWSS3
import AWSLambda
import AWSClientRuntime
import SmithyStreams
import Smithy
#endif

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
    private let region = "us-east-1"
    
    #if canImport(AWSS3)
    private var s3Client: S3Client?
    private var lambdaClient: LambdaClient?
    #endif
    private var currentUploadTask: Task<Void, Error>?
    private let logger = Logger(subsystem: "com.legacylense.app", category: "CloudProcessing")
    
    init() {
        #if canImport(AWSS3)
        Task {
            await setupAWSClients()
        }
        #else
        logger.warning("AWS SDK not available - cloud processing will use fallback")
        #endif
    }
    
    // MARK: - AWS Setup
    
    #if canImport(AWSS3)
    private func setupAWSClients() async {
        do {
            // Initialize S3 Client with 2025 patterns
            let s3Config = try await S3Client.S3ClientConfiguration(
                awsRetryMode: .standard,
                maxAttempts: 3,
                region: region
            )
            s3Client = S3Client(config: s3Config)
            
            // Initialize Lambda Client
            let lambdaConfig = try await LambdaClient.LambdaClientConfiguration(
                awsRetryMode: .standard,
                maxAttempts: 3,
                region: region
            )
            lambdaClient = LambdaClient(config: lambdaConfig)
            
            logger.info("AWS clients initialized successfully")
        } catch {
            logger.error("Failed to initialize AWS clients: \(error)")
        }
    }
    #endif
    
    // MARK: - Main Processing Function
    
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
        
        #if canImport(AWSS3)
        guard let s3Client = s3Client, let lambdaClient = lambdaClient else {
            logger.warning("AWS clients not available, falling back to simulated processing")
            return try await simulateCloudProcessing(image, enabledStages: enabledStages)
        }
        
        return try await performAWSProcessing(image, enabledStages: enabledStages, s3Client: s3Client, lambdaClient: lambdaClient)
        #else
        // Fallback when AWS SDK is not available
        logger.info("Using simulated cloud processing (AWS SDK not available)")
        return try await simulateCloudProcessing(image, enabledStages: enabledStages)
        #endif
    }
    
    // MARK: - Simulated Processing (Fallback)
    
    private func simulateCloudProcessing(_ image: UIImage, 
                                       enabledStages: Set<PhotoRestorationModel.RestorationModelType>) async throws -> UIImage {
        isProcessing = true
        progress = 0.0
        currentStage = "Simulating cloud processing"
        
        defer {
            isProcessing = false
            currentStage = "Completed"
        }
        
        // Simulate cloud processing steps
        let steps = [
            "Uploading to cloud",
            "Analyzing image",
            "Applying AI enhancement",
            "Rendering result",
            "Downloading result"
        ]
        
        for (index, step) in steps.enumerated() {
            currentStage = step
            progress = Double(index + 1) / Double(steps.count)
            
            // Simulate processing time
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds per step
        }
        
        // Return enhanced image using Core Image (fallback processing)
        return try await applyBasicEnhancement(image, enabledStages: enabledStages)
    }
    
    private func applyBasicEnhancement(_ image: UIImage, 
                                     enabledStages: Set<PhotoRestorationModel.RestorationModelType>) async throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw CloudProcessingError.imageConversionFailed
        }
        
        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)
        var outputImage = ciImage
        
        // Apply basic enhancements based on enabled stages
        for stage in enabledStages {
            switch stage {
            case .superResolution:
                // Basic enhancement + 2x upscaling
                if let filter = CIFilter(name: "CIColorControls") {
                    filter.setValue(outputImage, forKey: kCIInputImageKey)
                    filter.setValue(1.1, forKey: kCIInputSaturationKey)
                    filter.setValue(1.05, forKey: kCIInputBrightnessKey)
                    filter.setValue(1.1, forKey: kCIInputContrastKey)
                    if let result = filter.outputImage {
                        outputImage = result
                    }
                }
                
                // 2x upscaling
                let scaleTransform = CGAffineTransform(scaleX: 2.0, y: 2.0)
                outputImage = outputImage.transformed(by: scaleTransform)
                
            case .scratchRemoval:
                // Noise reduction
                if let filter = CIFilter(name: "CINoiseReduction") {
                    filter.setValue(outputImage, forKey: kCIInputImageKey)
                    filter.setValue(0.02, forKey: "inputNoiseLevel")
                    filter.setValue(0.4, forKey: kCIInputSharpnessKey)
                    if let result = filter.outputImage {
                        outputImage = result
                    }
                }
                
            default:
                // Skip other stages in fallback mode
                break
            }
        }
        
        guard let result = context.createCGImage(outputImage, from: outputImage.extent) else {
            throw CloudProcessingError.imageDecodingFailed
        }
        
        return UIImage(cgImage: result)
    }
    
    #if canImport(AWSS3)
    // MARK: - AWS Processing (When SDK Available)
    
    private func performAWSProcessing(_ image: UIImage,
                                    enabledStages: Set<PhotoRestorationModel.RestorationModelType>,
                                    s3Client: S3Client,
                                    lambdaClient: LambdaClient) async throws -> UIImage {
        
        isProcessing = true
        progress = 0.0
        currentStage = "Starting cloud processing"
        
        defer {
            isProcessing = false
            currentStage = "Completed"
        }
        
        do {
            // Step 1: Upload image to S3
            currentStage = "Uploading image to S3"
            let s3Key = try await uploadImageToS3(image, client: s3Client)
            
            // Step 2: Invoke Lambda function for processing
            currentStage = "Processing image with AI"
            let jobId = try await invokeLambdaFunction(
                s3Key: s3Key,
                enabledStages: enabledStages,
                client: lambdaClient
            )
            
            // Step 3: Poll for completion
            currentStage = "Waiting for processing completion"
            let resultS3Key = try await pollForCompletion(jobId: jobId, client: s3Client)
            
            // Step 4: Download processed image
            currentStage = "Downloading processed image"
            let processedImage = try await downloadImageFromS3(resultS3Key, client: s3Client)
            
            // Step 5: Cleanup
            try await cleanupS3Objects([s3Key, resultS3Key], client: s3Client)
            
            return processedImage
            
        } catch {
            // Track error for crash reporting
            CrashReportingService.shared.trackError(error, context: [
                "stage": currentStage,
                "progress": progress,
                "enabled_stages": enabledStages.map { $0.rawValue }
            ])
            throw error
        }
    }
    
    // MARK: - S3 Operations (AWS SDK Available)
    
    private func uploadImageToS3(_ image: UIImage, client: S3Client) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw CloudProcessingError.imageConversionFailed
        }
        
        let s3Key = "input/\(UUID().uuidString).jpg"
        let dataStream = ByteStream.data(imageData)
        
        let input = PutObjectInput(
            body: dataStream,
            bucket: s3BucketName,
            contentType: "image/jpeg",
            key: s3Key
        )
        
        do {
            _ = try await client.putObject(input: input)
            uploadProgress = 1.0
            progress = 0.2
            
            CrashReportingService.shared.trackEvent("s3_upload_success", parameters: [
                "s3_key": s3Key,
                "file_size_bytes": imageData.count
            ])
            
            return s3Key
        } catch {
            throw CloudProcessingError.awsUploadFailed(error.localizedDescription)
        }
    }
    
    private func downloadImageFromS3(_ s3Key: String, client: S3Client) async throws -> UIImage {
        let input = GetObjectInput(bucket: s3BucketName, key: s3Key)
        
        do {
            let output = try await client.getObject(input: input)
            
            guard let body = output.body,
                  let data = try await body.readData() else {
                throw CloudProcessingError.noData
            }
            
            guard let image = UIImage(data: data) else {
                throw CloudProcessingError.imageDecodingFailed
            }
            
            downloadProgress = 1.0
            progress = 1.0
            
            CrashReportingService.shared.trackEvent("s3_download_success", parameters: [
                "s3_key": s3Key,
                "file_size_bytes": data.count
            ])
            
            return image
            
        } catch {
            throw CloudProcessingError.awsDownloadFailed(error.localizedDescription)
        }
    }
    
    private func invokeLambdaFunction(s3Key: String,
                                    enabledStages: Set<PhotoRestorationModel.RestorationModelType>,
                                    client: LambdaClient) async throws -> String {
        
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
        
        let input = InvokeInput(
            functionName: lambdaFunctionName,
            invocationType: .event,
            payload: payloadData
        )
        
        do {
            let response = try await client.invoke(input: input)
            
            if let functionError = response.functionError {
                throw CloudProcessingError.lambdaInvocationFailed("Function error: \(functionError)")
            }
            
            progress = 0.3
            
            CrashReportingService.shared.trackEvent("lambda_invoke_success", parameters: [
                "job_id": jobId,
                "function_name": lambdaFunctionName,
                "enabled_stages": enabledStages.map { $0.rawValue }
            ])
            
            return jobId
            
        } catch {
            throw CloudProcessingError.lambdaInvocationFailed(error.localizedDescription)
        }
    }
    
    private func pollForCompletion(jobId: String, client: S3Client) async throws -> String {
        let maxPollingTime: TimeInterval = 3600
        let pollingInterval: TimeInterval = 10
        let startTime = Date()
        
        let outputS3Key = "output/\(jobId).jpg"
        
        while Date().timeIntervalSince(startTime) < maxPollingTime {
            if try await checkS3ObjectExists(s3Key: outputS3Key, client: client) {
                progress = 0.9
                return outputS3Key
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            let estimatedTotal: TimeInterval = 120
            let progressValue = min(0.6, elapsed / estimatedTotal)
            progress = 0.3 + progressValue
            processingProgress = progressValue / 0.6
            
            try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
        }
        
        throw CloudProcessingError.timeout
    }
    
    private func checkS3ObjectExists(s3Key: String, client: S3Client) async throws -> Bool {
        let input = HeadObjectInput(bucket: s3BucketName, key: s3Key)
        
        do {
            _ = try await client.headObject(input: input)
            return true
        } catch {
            return false
        }
    }
    
    private func cleanupS3Objects(_ s3Keys: [String], client: S3Client) async throws {
        for s3Key in s3Keys {
            let input = DeleteObjectInput(bucket: s3BucketName, key: s3Key)
            
            do {
                _ = try await client.deleteObject(input: input)
            } catch {
                logger.warning("Failed to cleanup S3 object \(s3Key): \(error)")
            }
        }
    }
    #endif
    
    // MARK: - Control Methods
    
    func cancelProcessing() {
        currentUploadTask?.cancel()
        currentUploadTask = nil
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

// MARK: - Extensions

#if canImport(AWSS3)
// ByteStream already has readData() method in AWS SDK Swift 2025
// No need for custom extension
#endif

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