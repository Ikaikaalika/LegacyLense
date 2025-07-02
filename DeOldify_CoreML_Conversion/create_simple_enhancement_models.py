#!/usr/bin/env python3
"""
Simple CoreML Model Creation for LegacyLense
Creates lightweight AI models for photo enhancement
"""

import torch
import torch.nn as nn
import coremltools as ct
import numpy as np
from pathlib import Path
import argparse

class SimpleEnhancementCNN(nn.Module):
    """Lightweight CNN for photo enhancement"""
    
    def __init__(self, in_channels=3, out_channels=3, base_filters=32):
        super(SimpleEnhancementCNN, self).__init__()
        
        # Encoder
        self.conv1 = nn.Conv2d(in_channels, base_filters, 3, padding=1)
        self.conv2 = nn.Conv2d(base_filters, base_filters * 2, 3, padding=1)
        self.conv3 = nn.Conv2d(base_filters * 2, base_filters * 4, 3, padding=1)
        
        # Decoder
        self.conv4 = nn.Conv2d(base_filters * 4, base_filters * 2, 3, padding=1)
        self.conv5 = nn.Conv2d(base_filters * 2, base_filters, 3, padding=1)
        self.conv6 = nn.Conv2d(base_filters, out_channels, 3, padding=1)
        
        # Activation
        self.relu = nn.ReLU(inplace=True)
        self.sigmoid = nn.Sigmoid()
        
    def forward(self, x):
        # Normalize input to 0-1 range
        x = x / 255.0
        
        # Encoder
        x1 = self.relu(self.conv1(x))
        x2 = self.relu(self.conv2(x1))
        x3 = self.relu(self.conv3(x2))
        
        # Decoder with skip connections
        x4 = self.relu(self.conv4(x3) + x2)
        x5 = self.relu(self.conv5(x4) + x1)
        output = self.sigmoid(self.conv6(x5))
        
        # Scale back to 0-255 range
        output = output * 255.0
        
        return output

class SimpleSuperResolutionCNN(nn.Module):
    """Lightweight CNN for 2x super resolution"""
    
    def __init__(self, scale_factor=2, in_channels=3, out_channels=3, base_filters=32):
        super(SimpleSuperResolutionCNN, self).__init__()
        
        self.scale_factor = scale_factor
        
        # Feature extraction
        self.conv1 = nn.Conv2d(in_channels, base_filters, 9, padding=4)
        self.conv2 = nn.Conv2d(base_filters, base_filters // 2, 1)
        self.conv3 = nn.Conv2d(base_filters // 2, out_channels * (scale_factor ** 2), 5, padding=2)
        
        # Pixel shuffle for upsampling
        self.pixel_shuffle = nn.PixelShuffle(scale_factor)
        
        # Activation
        self.relu = nn.ReLU(inplace=True)
        self.tanh = nn.Tanh()
        
    def forward(self, x):
        # Normalize input
        x = (x / 255.0) * 2.0 - 1.0  # Scale to [-1, 1]
        
        # Feature extraction
        x = self.relu(self.conv1(x))
        x = self.relu(self.conv2(x))
        x = self.conv3(x)
        
        # Upsampling
        x = self.pixel_shuffle(x)
        
        # Final activation
        output = self.tanh(x)
        
        # Scale back to [0, 255]
        output = ((output + 1.0) / 2.0) * 255.0
        
        return output

class SimpleColorizationCNN(nn.Module):
    """Lightweight CNN for colorization"""
    
    def __init__(self, base_filters=32):
        super(SimpleColorizationCNN, self).__init__()
        
        # Grayscale to Lab color space conversion layers
        self.feature_extractor = nn.Sequential(
            nn.Conv2d(1, base_filters, 3, padding=1),
            nn.ReLU(inplace=True),
            nn.Conv2d(base_filters, base_filters * 2, 3, padding=1),
            nn.ReLU(inplace=True),
            nn.Conv2d(base_filters * 2, base_filters * 4, 3, padding=1),
            nn.ReLU(inplace=True),
        )
        
        # Color prediction layers (predict a and b channels)
        self.color_predictor = nn.Sequential(
            nn.Conv2d(base_filters * 4, base_filters * 2, 3, padding=1),
            nn.ReLU(inplace=True),
            nn.Conv2d(base_filters * 2, base_filters, 3, padding=1),
            nn.ReLU(inplace=True),
            nn.Conv2d(base_filters, 2, 3, padding=1),  # a and b channels
            nn.Tanh()
        )
        
    def forward(self, x):
        # Convert RGB to grayscale if needed
        if x.shape[1] == 3:
            # Convert to grayscale using standard weights
            gray = 0.299 * x[:, 0:1, :, :] + 0.587 * x[:, 1:2, :, :] + 0.114 * x[:, 2:3, :, :]
        else:
            gray = x
            
        # Normalize to [0, 1]
        gray = gray / 255.0
        
        # Extract features
        features = self.feature_extractor(gray)
        
        # Predict color channels
        ab_channels = self.color_predictor(features)
        
        # Convert back to RGB (simplified conversion)
        # In practice, you'd want proper Lab to RGB conversion
        # For this demo, we'll create a sepia-like effect
        r = gray + 0.3 * ab_channels[:, 0:1, :, :] * 0.5
        g = gray + 0.1 * ab_channels[:, 1:2, :, :] * 0.5
        b = gray - 0.2 * ab_channels[:, 0:1, :, :] * 0.5
        
        # Combine channels and scale back to [0, 255]
        rgb = torch.cat([r, g, b], dim=1)
        rgb = torch.clamp(rgb * 255.0, 0, 255)
        
        return rgb

def create_enhancement_model():
    """Create and export enhancement model"""
    model = SimpleEnhancementCNN(base_filters=16)  # Smaller for mobile
    model.eval()
    
    # Create example input (256x256 RGB image)
    example_input = torch.randn(1, 3, 256, 256)
    
    # Trace the model
    traced_model = torch.jit.trace(model, example_input)
    
    # Convert to CoreML
    coreml_model = ct.convert(
        traced_model,
        inputs=[ct.ImageType(name="input_image", shape=example_input.shape, scale=1.0)],
        outputs=[ct.ImageType(name="enhanced_image")],
        convert_to="mlprogram"
    )
    
    # Add metadata
    coreml_model.short_description = "Lightweight photo enhancement model for LegacyLense"
    coreml_model.author = "LegacyLense Team"
    coreml_model.license = "MIT"
    coreml_model.version = "1.0"
    
    return coreml_model

def create_super_resolution_model():
    """Create and export 2x super resolution model"""
    model = SimpleSuperResolutionCNN(scale_factor=2, base_filters=16)
    model.eval()
    
    # Create example input (128x128 RGB image -> 256x256)
    example_input = torch.randn(1, 3, 128, 128)
    
    # Trace the model
    traced_model = torch.jit.trace(model, example_input)
    
    # Convert to CoreML
    coreml_model = ct.convert(
        traced_model,
        inputs=[ct.ImageType(name="input_image", shape=example_input.shape, scale=1.0)],
        outputs=[ct.ImageType(name="upscaled_image")],
        convert_to="mlprogram"
    )
    
    # Add metadata
    coreml_model.short_description = "2x Super Resolution model for LegacyLense"
    coreml_model.author = "LegacyLense Team"
    coreml_model.license = "MIT"
    coreml_model.version = "1.0"
    
    return coreml_model

def create_colorization_model():
    """Create and export colorization model"""
    model = SimpleColorizationCNN(base_filters=16)
    model.eval()
    
    # Create example input (256x256 grayscale or RGB image)
    example_input = torch.randn(1, 3, 256, 256)
    
    # Trace the model
    traced_model = torch.jit.trace(model, example_input)
    
    # Convert to CoreML
    coreml_model = ct.convert(
        traced_model,
        inputs=[ct.ImageType(name="input_image", shape=example_input.shape, scale=1.0)],
        outputs=[ct.ImageType(name="colorized_image")],
        convert_to="mlprogram"
    )
    
    # Add metadata
    coreml_model.short_description = "Photo colorization model for LegacyLense"
    coreml_model.author = "LegacyLense Team"
    coreml_model.license = "MIT"
    coreml_model.version = "1.0"
    
    return coreml_model

def main():
    parser = argparse.ArgumentParser(description="Create CoreML models for LegacyLense")
    parser.add_argument("--model", type=str, choices=["enhancement", "super_resolution", "colorization", "all"], 
                       default="all", help="Which model to create")
    parser.add_argument("--output_dir", type=str, default="./models", help="Output directory for models")
    
    args = parser.parse_args()
    
    # Create output directory
    output_dir = Path(args.output_dir)
    output_dir.mkdir(exist_ok=True)
    
    print(f"Creating CoreML models in {output_dir}")
    
    models_to_create = []
    if args.model == "all":
        models_to_create = ["enhancement", "super_resolution", "colorization"]
    else:
        models_to_create = [args.model]
    
    for model_type in models_to_create:
        print(f"\nCreating {model_type} model...")
        
        try:
            if model_type == "enhancement":
                model = create_enhancement_model()
                output_path = output_dir / "PhotoEnhancement.mlpackage"
                
            elif model_type == "super_resolution":
                model = create_super_resolution_model()
                output_path = output_dir / "SuperResolution2x.mlpackage"
                
            elif model_type == "colorization":
                model = create_colorization_model()
                output_path = output_dir / "PhotoColorization.mlpackage"
            
            # Save the model
            model.save(str(output_path))
            print(f"✅ Successfully created {model_type} model: {output_path}")
            
            # Print model info
            print(f"   - Input shape: {model.input_description}")
            print(f"   - Output shape: {model.output_description}")
            
        except Exception as e:
            print(f"❌ Failed to create {model_type} model: {e}")
    
    print(f"\n🎉 Model creation complete! Models saved in {output_dir}")
    print("\nTo use these models in your iOS app:")
    print("1. Copy the .mlpackage files to your Xcode project")
    print("2. Ensure they're added to your app target")
    print("3. Update the model URLs in RealMLModelManager.swift")

if __name__ == "__main__":
    main()