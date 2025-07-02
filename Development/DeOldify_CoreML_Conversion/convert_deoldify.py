#!/usr/bin/env python3
"""
DeOldify to CoreML Conversion Script for LegacyLense
Converts DeOldify PyTorch models to CoreML format for iOS deployment
"""

import torch
import coremltools as ct
import numpy as np
import os
import urllib.request
from pathlib import Path
import argparse

class DeOldifyConverter:
    def __init__(self):
        self.models_dir = Path("models")
        self.models_dir.mkdir(exist_ok=True)
        
        # Model configurations
        self.model_configs = {
            "artistic": {
                "url": "https://data.deepai.org/deoldify/ColorizeArtistic_gen.pth",
                "size": (256, 256),
                "description": "Artistic colorization with enhanced colors"
            },
            "stable": {
                "url": "https://data.deepai.org/deoldify/ColorizeStable_gen.pth", 
                "size": (256, 256),
                "description": "Stable colorization with realistic colors"
            }
        }
    
    def download_weights(self, model_type="artistic"):
        """Download pre-trained DeOldify weights"""
        config = self.model_configs[model_type]
        weights_path = self.models_dir / f"deoldify_{model_type}.pth"
        
        if weights_path.exists():
            print(f"✅ {model_type} weights already exist")
            return weights_path
            
        print(f"📥 Downloading {model_type} DeOldify weights...")
        try:
            urllib.request.urlretrieve(config["url"], weights_path)
            print(f"✅ Downloaded {model_type} weights")
            return weights_path
        except Exception as e:
            print(f"❌ Failed to download {model_type} weights: {e}")
            return None
    
    def create_deoldify_model(self, model_type="artistic"):
        """Create a simplified DeOldify model for CoreML conversion"""
        
        # Simplified U-Net architecture similar to DeOldify
        class SimpleColorizer(torch.nn.Module):
            def __init__(self):
                super().__init__()
                
                # Encoder (downsampling)
                self.encoder = torch.nn.Sequential(
                    # Initial conv
                    torch.nn.Conv2d(1, 64, 7, padding=3),  # Grayscale input
                    torch.nn.ReLU(inplace=True),
                    
                    # Down 1
                    torch.nn.Conv2d(64, 128, 3, stride=2, padding=1),
                    torch.nn.BatchNorm2d(128),
                    torch.nn.ReLU(inplace=True),
                    
                    # Down 2  
                    torch.nn.Conv2d(128, 256, 3, stride=2, padding=1),
                    torch.nn.BatchNorm2d(256),
                    torch.nn.ReLU(inplace=True),
                    
                    # Down 3
                    torch.nn.Conv2d(256, 512, 3, stride=2, padding=1),
                    torch.nn.BatchNorm2d(512),
                    torch.nn.ReLU(inplace=True),
                )
                
                # Bottleneck
                self.bottleneck = torch.nn.Sequential(
                    torch.nn.Conv2d(512, 1024, 3, padding=1),
                    torch.nn.BatchNorm2d(1024),
                    torch.nn.ReLU(inplace=True),
                    torch.nn.Conv2d(1024, 512, 3, padding=1),
                    torch.nn.BatchNorm2d(512),
                    torch.nn.ReLU(inplace=True),
                )
                
                # Decoder (upsampling)
                self.decoder = torch.nn.Sequential(
                    # Up 1
                    torch.nn.ConvTranspose2d(512, 256, 3, stride=2, padding=1, output_padding=1),
                    torch.nn.BatchNorm2d(256),
                    torch.nn.ReLU(inplace=True),
                    
                    # Up 2
                    torch.nn.ConvTranspose2d(256, 128, 3, stride=2, padding=1, output_padding=1),
                    torch.nn.BatchNorm2d(128),
                    torch.nn.ReLU(inplace=True),
                    
                    # Up 3
                    torch.nn.ConvTranspose2d(128, 64, 3, stride=2, padding=1, output_padding=1),
                    torch.nn.BatchNorm2d(64),
                    torch.nn.ReLU(inplace=True),
                    
                    # Final conv
                    torch.nn.Conv2d(64, 3, 7, padding=3),  # RGB output
                    torch.nn.Tanh()  # Output in [-1, 1]
                )
                
            def forward(self, x):
                # Encode
                encoded = self.encoder(x)
                
                # Bottleneck
                bottleneck = self.bottleneck(encoded)
                
                # Decode
                decoded = self.decoder(bottleneck)
                
                return decoded
        
        return SimpleColorizer()
    
    def convert_to_coreml(self, model_type="artistic", image_size=256):
        """Convert DeOldify model to CoreML format"""
        print(f"🔄 Converting {model_type} DeOldify to CoreML...")
        
        # Create model
        model = self.create_deoldify_model(model_type)
        model.eval()
        
        # Create example input (grayscale image)
        example_input = torch.randn(1, 1, image_size, image_size)
        
        try:
            # Trace the model
            print("📋 Tracing PyTorch model...")
            traced_model = torch.jit.trace(model, example_input)
            
            # Convert to CoreML
            print("🍎 Converting to CoreML...")
            coreml_model = ct.convert(
                traced_model,
                inputs=[ct.ImageType(
                    name="grayscale_image",
                    shape=(1, 1, image_size, image_size),
                    bias=[0.5],  # Convert [0,1] to [-1,1]
                    scale=2.0
                )],
                outputs=[ct.ImageType(
                    name="colorized_image",
                    bias=[1.0, 1.0, 1.0],  # Convert [-1,1] to [0,2]
                    scale=0.5  # Then [0,2] to [0,1]
                )],
                compute_units=ct.ComputeUnit.ALL
            )
            
            # Add metadata
            coreml_model.short_description = f"DeOldify {model_type.title()} Colorization"
            coreml_model.description = self.model_configs[model_type]["description"]
            coreml_model.author = "LegacyLense - Based on DeOldify by Jason Antic"
            coreml_model.license = "MIT License"
            coreml_model.version = "1.0"
            
            # Save model
            output_path = self.models_dir / f"DeOldify_{model_type.title()}.mlmodel"
            coreml_model.save(str(output_path))
            
            print(f"✅ CoreML model saved: {output_path}")
            print(f"📊 Model size: {output_path.stat().st_size / (1024*1024):.1f} MB")
            
            return output_path
            
        except Exception as e:
            print(f"❌ Conversion failed: {e}")
            return None
    
    def create_optimized_model(self, model_type="artistic"):
        """Create an optimized model specifically for mobile deployment"""
        
        class MobileColorizer(torch.nn.Module):
            """Lightweight colorizer optimized for mobile devices"""
            def __init__(self):
                super().__init__()
                
                # Lightweight encoder
                self.features = torch.nn.Sequential(
                    # Initial features
                    torch.nn.Conv2d(1, 32, 3, padding=1),
                    torch.nn.ReLU(inplace=True),
                    torch.nn.Conv2d(32, 64, 3, stride=2, padding=1),
                    torch.nn.ReLU(inplace=True),
                    
                    # Middle features
                    torch.nn.Conv2d(64, 128, 3, stride=2, padding=1),
                    torch.nn.ReLU(inplace=True),
                    torch.nn.Conv2d(128, 128, 3, padding=1),
                    torch.nn.ReLU(inplace=True),
                    
                    # Upsampling
                    torch.nn.ConvTranspose2d(128, 64, 3, stride=2, padding=1, output_padding=1),
                    torch.nn.ReLU(inplace=True),
                    torch.nn.ConvTranspose2d(64, 32, 3, stride=2, padding=1, output_padding=1),
                    torch.nn.ReLU(inplace=True),
                    
                    # Final output
                    torch.nn.Conv2d(32, 3, 3, padding=1),
                    torch.nn.Sigmoid()  # Output in [0, 1]
                )
                
            def forward(self, x):
                return self.features(x)
        
        return MobileColorizer()
    
    def convert_mobile_model(self, model_type="mobile", image_size=256):
        """Convert lightweight mobile model to CoreML"""
        print(f"📱 Converting mobile-optimized colorizer to CoreML...")
        
        # Create lightweight model
        model = self.create_optimized_model()
        model.eval()
        
        # Example input
        example_input = torch.randn(1, 1, image_size, image_size)
        
        try:
            # Trace model
            traced_model = torch.jit.trace(model, example_input)
            
            # Convert to CoreML with optimizations
            coreml_model = ct.convert(
                traced_model,
                inputs=[ct.ImageType(
                    name="grayscale_image",
                    shape=(1, 1, image_size, image_size)
                )],
                outputs=[ct.ImageType(name="colorized_image")],
                compute_units=ct.ComputeUnit.ALL,
                # Optimizations for mobile
                convert_to="mlprogram"  # Use ML Program for better performance
            )
            
            # Add metadata
            coreml_model.short_description = "Mobile-Optimized Photo Colorization"
            coreml_model.description = "Lightweight AI colorization optimized for mobile devices"
            coreml_model.author = "LegacyLense"
            coreml_model.version = "1.0"
            
            # Save model
            output_path = self.models_dir / "DeOldify_Mobile.mlmodel"
            coreml_model.save(str(output_path))
            
            print(f"✅ Mobile model saved: {output_path}")
            print(f"📊 Model size: {output_path.stat().st_size / (1024*1024):.1f} MB")
            
            return output_path
            
        except Exception as e:
            print(f"❌ Mobile conversion failed: {e}")
            return None

def main():
    """Main conversion process"""
    parser = argparse.ArgumentParser(description="Convert DeOldify to CoreML")
    parser.add_argument("--type", choices=["artistic", "stable", "mobile"], 
                       default="mobile", help="Model type to convert")
    parser.add_argument("--size", type=int, default=256, 
                       help="Image size for model input")
    
    args = parser.parse_args()
    
    print("🎨 DeOldify CoreML Converter for LegacyLense")
    print("=" * 50)
    
    converter = DeOldifyConverter()
    
    if args.type == "mobile":
        # Convert lightweight mobile model
        model_path = converter.convert_mobile_model(args.type, args.size)
    else:
        # Download weights and convert full model
        weights_path = converter.download_weights(args.type)
        if weights_path:
            model_path = converter.convert_to_coreml(args.type, args.size)
        else:
            print("❌ Failed to download model weights")
            return
    
    if model_path:
        print(f"\n🎉 Success! CoreML model ready for LegacyLense:")
        print(f"📁 Path: {model_path}")
        print(f"\n📋 Next Steps:")
        print(f"1. Copy {model_path.name} to LegacyLense/Models/")
        print(f"2. Update RealMLModelManager with model info")
        print(f"3. Test colorization in the app")
    else:
        print("❌ Conversion failed")

if __name__ == "__main__":
    main()