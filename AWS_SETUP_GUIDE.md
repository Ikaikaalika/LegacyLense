# 🔧 **AWS Setup Guide for LegacyLense Cloud Processing**

## **🎯 Overview**

This guide covers setting up AWS infrastructure for LegacyLense's premium cloud processing features. Subscribers get access to powerful cloud-based AI processing using AWS services.

## **📋 AWS Services Used**

### **1. Amazon S3**
- **Purpose**: Store input/output images securely
- **Bucket**: `legacylense-processing`
- **Regions**: us-east-1 (primary)

### **2. AWS Lambda**
- **Purpose**: Serverless image processing with AI models
- **Function**: `legacylense-photo-processor`
- **Runtime**: Python 3.9+ with custom container
- **Memory**: 3008 MB (maximum for CPU-intensive tasks)
- **Timeout**: 15 minutes

### **3. Amazon Cognito**
- **Purpose**: User authentication and temporary AWS credentials
- **Identity Pool**: For mobile app access
- **Unauthenticated access**: Disabled

### **4. Amazon Rekognition** (Optional)
- **Purpose**: Content moderation and face detection
- **Usage**: Pre-processing validation

## **🛠️ Infrastructure Setup**

### **Step 1: Create S3 Bucket**

```bash
# Create S3 bucket
aws s3 mb s3://legacylense-processing --region us-east-1

# Set up bucket policy for processing
aws s3api put-bucket-policy --bucket legacylense-processing --policy file://bucket-policy.json

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket legacylense-processing \
    --versioning-configuration Status=Enabled

# Set lifecycle policy to auto-delete after 7 days
aws s3api put-bucket-lifecycle-configuration \
    --bucket legacylense-processing \
    --lifecycle-configuration file://lifecycle-policy.json
```

### **Step 2: Create Cognito Identity Pool**

```bash
# Create identity pool
aws cognito-identity create-identity-pool \
    --identity-pool-name "LegacyLenseUsers" \
    --allow-unauthenticated-identities false \
    --region us-east-1

# Note the Identity Pool ID for your app configuration
```

### **Step 3: Deploy Lambda Function**

```bash
# Build container image
docker build -t legacylense-processor .

# Tag for ECR
docker tag legacylense-processor:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/legacylense-processor:latest

# Push to ECR
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/legacylense-processor:latest

# Create Lambda function
aws lambda create-function \
    --function-name legacylense-photo-processor \
    --role arn:aws:iam::123456789012:role/LegacyLenseLambdaRole \
    --code ImageUri=123456789012.dkr.ecr.us-east-1.amazonaws.com/legacylense-processor:latest \
    --timeout 900 \
    --memory-size 3008 \
    --package-type Image
```

## **🐳 Lambda Container Setup**

### **Dockerfile**

```dockerfile
FROM public.ecr.aws/lambda/python:3.9

# Install system dependencies
RUN yum update -y && yum install -y \
    gcc \
    g++ \
    make \
    libffi-devel \
    openssl-devel

# Copy requirements and install Python packages
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy function code
COPY lambda_function.py .
COPY models/ ./models/

# Set the CMD to your handler
CMD ["lambda_function.lambda_handler"]
```

### **requirements.txt**

```txt
torch==1.13.0
torchvision==0.14.0
pillow==9.3.0
numpy==1.24.0
opencv-python-headless==4.6.0
boto3==1.26.0
```

### **lambda_function.py**

```python
import json
import boto3
import torch
import torchvision.transforms as transforms
from PIL import Image
import io
import base64
import os

s3_client = boto3.client('s3')

# Load AI models on cold start
MODEL_CACHE = {}

def load_model(model_type):
    """Load and cache AI models"""
    if model_type not in MODEL_CACHE:
        model_path = f"./models/{model_type}.pth"
        MODEL_CACHE[model_type] = torch.jit.load(model_path, map_location='cpu')
    return MODEL_CACHE[model_type]

def lambda_handler(event, context):
    """Main Lambda handler for photo processing"""
    try:
        # Parse input
        job_id = event['jobId']
        input_s3_key = event['inputS3Key']
        output_s3_key = event['outputS3Key']
        bucket = event['bucket']
        enabled_stages = event.get('enabledStages', [])
        
        # Download image from S3
        response = s3_client.get_object(Bucket=bucket, Key=input_s3_key)
        image_data = response['Body'].read()
        image = Image.open(io.BytesIO(image_data))
        
        # Process with AI models
        processed_image = process_image(image, enabled_stages)
        
        # Convert back to bytes
        output_buffer = io.BytesIO()
        processed_image.save(output_buffer, format='JPEG', quality=95)
        output_data = output_buffer.getvalue()
        
        # Upload to S3
        s3_client.put_object(
            Bucket=bucket,
            Key=output_s3_key,
            Body=output_data,
            ContentType='image/jpeg'
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'jobId': job_id,
                'status': 'completed',
                'outputS3Key': output_s3_key
            })
        }
        
    except Exception as e:
        print(f"Error processing image: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'jobId': job_id,
                'status': 'failed',
                'error': str(e)
            })
        }

def process_image(image, enabled_stages):
    """Process image with specified AI models"""
    processed = image
    
    for stage in enabled_stages:
        if stage == 'super_resolution':
            model = load_model('esrgan')
            processed = apply_super_resolution(processed, model)
        elif stage == 'colorization':
            model = load_model('deoldify')
            processed = apply_colorization(processed, model)
        elif stage == 'noise_reduction':
            model = load_model('dncnn')
            processed = apply_noise_reduction(processed, model)
        elif stage == 'enhancement':
            model = load_model('dped')
            processed = apply_enhancement(processed, model)
    
    return processed

def apply_super_resolution(image, model):
    """Apply ESRGAN super resolution"""
    # Convert PIL to tensor
    transform = transforms.Compose([
        transforms.ToTensor(),
    ])
    
    input_tensor = transform(image).unsqueeze(0)
    
    with torch.no_grad():
        output_tensor = model(input_tensor)
    
    # Convert back to PIL
    output_image = transforms.ToPILImage()(output_tensor.squeeze(0))
    return output_image

def apply_colorization(image, model):
    """Apply DeOldify colorization"""
    # Convert to grayscale first
    grayscale = image.convert('L')
    
    # Process with model
    transform = transforms.Compose([
        transforms.Resize((256, 256)),
        transforms.ToTensor(),
    ])
    
    input_tensor = transform(grayscale).unsqueeze(0)
    
    with torch.no_grad():
        output_tensor = model(input_tensor)
    
    # Convert back to PIL and resize to original dimensions
    colorized = transforms.ToPILImage()(output_tensor.squeeze(0))
    return colorized.resize(image.size, Image.LANCZOS)

def apply_noise_reduction(image, model):
    """Apply DnCNN noise reduction"""
    transform = transforms.Compose([
        transforms.ToTensor(),
    ])
    
    input_tensor = transform(image).unsqueeze(0)
    
    with torch.no_grad():
        output_tensor = model(input_tensor)
    
    output_image = transforms.ToPILImage()(output_tensor.squeeze(0))
    return output_image

def apply_enhancement(image, model):
    """Apply DPED enhancement"""
    transform = transforms.Compose([
        transforms.Resize((256, 256)),
        transforms.ToTensor(),
    ])
    
    input_tensor = transform(image).unsqueeze(0)
    
    with torch.no_grad():
        output_tensor = model(input_tensor)
    
    enhanced = transforms.ToPILImage()(output_tensor.squeeze(0))
    return enhanced.resize(image.size, Image.LANCZOS)
```

## **🔒 Security Configuration**

### **IAM Roles**

#### **Lambda Execution Role**

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject"
            ],
            "Resource": "arn:aws:s3:::legacylense-processing/*"
        }
    ]
}
```

#### **Cognito Authenticated Role**

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject"
            ],
            "Resource": "arn:aws:s3:::legacylense-processing/input/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction"
            ],
            "Resource": "arn:aws:lambda:us-east-1:*:function:legacylense-photo-processor"
        }
    ]
}
```

### **S3 Bucket Policy**

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "LegacyLenseProcessingAccess",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::123456789012:role/LegacyLenseLambdaRole"
            },
            "Action": [
                "s3:GetObject",
                "s3:PutObject"
            ],
            "Resource": "arn:aws:s3:::legacylense-processing/*"
        }
    ]
}
```

## **💰 Cost Optimization**

### **Pricing Estimates**

#### **Per Image Processing (Subscribers)**
- **S3 Storage**: $0.0001 (temporary storage)
- **Lambda Compute**: $0.05-0.15 (depends on processing time)
- **Data Transfer**: $0.001-0.005
- **Total per image**: ~$0.05-0.20

#### **Monthly Costs (1000 subscribers)**
- **S3**: ~$10/month
- **Lambda**: ~$200-500/month  
- **Cognito**: ~$5/month
- **Data Transfer**: ~$50/month
- **Total**: ~$265-565/month

### **Cost Optimization Strategies**

1. **Image Compression**: Compress uploads to reduce transfer costs
2. **Batch Processing**: Process multiple images in single Lambda invocation
3. **Caching**: Cache common model outputs
4. **Reserved Capacity**: Use Lambda provisioned concurrency for high traffic
5. **Regional Optimization**: Deploy in regions closest to users

## **📊 Monitoring & Analytics**

### **CloudWatch Metrics**

- **Lambda Duration**: Processing time per image
- **Error Rate**: Failed processing attempts  
- **Memory Usage**: Peak memory utilization
- **S3 Requests**: Upload/download volume
- **Cost Tracking**: Daily spending by service

### **Custom Metrics**

```python
import boto3

cloudwatch = boto3.client('cloudwatch')

def put_custom_metric(metric_name, value, unit='Count'):
    cloudwatch.put_metric_data(
        Namespace='LegacyLense/Processing',
        MetricData=[
            {
                'MetricName': metric_name,
                'Value': value,
                'Unit': unit,
                'Dimensions': [
                    {
                        'Name': 'Environment',
                        'Value': 'Production'
                    }
                ]
            }
        ]
    )

# Track processing success/failure
put_custom_metric('ProcessingSuccess', 1)
put_custom_metric('ProcessingTime', processing_duration, 'Seconds')
```

## **🚀 Deployment**

### **Automated Deployment with CDK**

```python
from aws_cdk import (
    aws_lambda as _lambda,
    aws_s3 as s3,
    aws_cognito as cognito,
    aws_iam as iam,
    Stack, App
)

class LegacyLenseStack(Stack):
    def __init__(self, scope, id, **kwargs):
        super().__init__(scope, id, **kwargs)
        
        # S3 bucket
        bucket = s3.Bucket(
            self, "ProcessingBucket",
            bucket_name="legacylense-processing",
            lifecycle_rules=[
                s3.LifecycleRule(
                    expiration=Duration.days(7)
                )
            ]
        )
        
        # Lambda function
        lambda_fn = _lambda.Function(
            self, "ProcessorFunction",
            function_name="legacylense-photo-processor",
            runtime=_lambda.Runtime.FROM_IMAGE,
            code=_lambda.Code.from_asset_image("./lambda"),
            timeout=Duration.minutes(15),
            memory_size=3008
        )
        
        # Grant permissions
        bucket.grant_read_write(lambda_fn)

app = App()
LegacyLenseStack(app, "LegacyLenseStack")
app.synth()
```

### **Environment Variables**

```bash
# Set in Lambda function
AWS_REGION=us-east-1
S3_BUCKET=legacylense-processing
MODEL_CACHE_SIZE=3
PROCESSING_TIMEOUT=900
```

## **🧪 Testing**

### **Local Testing**

```python
# test_lambda.py
import json
from lambda_function import lambda_handler

def test_processing():
    event = {
        'jobId': 'test-123',
        'inputS3Key': 'input/test.jpg',
        'outputS3Key': 'output/test-processed.jpg',
        'bucket': 'legacylense-processing',
        'enabledStages': ['super_resolution', 'enhancement']
    }
    
    context = {}
    result = lambda_handler(event, context)
    print(json.dumps(result, indent=2))

if __name__ == '__main__':
    test_processing()
```

### **Integration Testing**

```bash
# Test full pipeline
aws lambda invoke \
    --function-name legacylense-photo-processor \
    --payload file://test-event.json \
    response.json

# Check response
cat response.json
```

## **🔧 iOS App Configuration**

### **Update CloudRestorationService.swift**

```swift
private func setupAWS() {
    let credentialsProvider = AWSCognitoCredentialsProvider(
        regionType: .USEast1,
        identityPoolId: "us-east-1:12345678-1234-1234-1234-123456789012" // Your actual pool ID
    )
    
    let configuration = AWSServiceConfiguration(
        region: .USEast1,
        credentialsProvider: credentialsProvider
    )
    
    AWSServiceManager.default().defaultServiceConfiguration = configuration
}
```

### **Add AWS Dependencies to Package.swift**

```swift
dependencies: [
    .package(url: "https://github.com/aws-amplify/aws-sdk-ios", from: "2.27.0"),
]
```

---

**🎉 Your AWS infrastructure is now ready for premium cloud processing!**

With this setup, LegacyLense subscribers get access to powerful cloud-based AI processing while free users are limited to on-device models. The system automatically handles subscription verification, secure image transfer, and cost-effective processing.