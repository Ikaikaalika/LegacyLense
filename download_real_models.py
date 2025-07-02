#!/usr/bin/env python3
"""
Download Real CoreML Models for LegacyLense
Downloads actual working CoreML models from reliable sources
"""

import urllib.request
import urllib.error
import os
from pathlib import Path
import sys

def download_file(url, filename, description):
    """Download a file with progress indicator"""
    print(f"Downloading {description}...")
    print(f"URL: {url}")
    
    try:
        def progress_hook(block_num, block_size, total_size):
            if total_size > 0:
                downloaded = block_num * block_size
                percent = min(100, (downloaded * 100) // total_size)
                progress_bar = '█' * (percent // 2) + '░' * (50 - percent // 2)
                print(f'\r[{progress_bar}] {percent}% ({downloaded//1024//1024}MB/{total_size//1024//1024}MB)', end='', flush=True)
        
        urllib.request.urlretrieve(url, filename, progress_hook)
        print(f"\n✅ Successfully downloaded {description}")
        return True
        
    except urllib.error.HTTPError as e:
        print(f"\n❌ HTTP Error {e.code}: {e.reason}")
        return False
    except urllib.error.URLError as e:
        print(f"\n❌ URL Error: {e.reason}")
        return False
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        return False

def main():
    # Create models directory
    models_dir = Path("./models")
    models_dir.mkdir(exist_ok=True)
    
    print("🤖 Downloading Real CoreML Models for LegacyLense")
    print("=" * 60)
    
    # List of models to download from reliable sources
    models = [
        {
            "name": "MobileNetV2",
            "description": "MobileNetV2 Image Classification (can be adapted for enhancement)",
            "url": "https://docs-assets.developer.apple.com/coreml/models/Image/ImageClassification/MobileNetV2/MobileNetV2.mlmodel",
            "filename": "MobileNetV2.mlmodel",
            "size": "~14MB"
        },
        {
            "name": "ResNet50", 
            "description": "ResNet50 Image Classification (feature extraction)",
            "url": "https://docs-assets.developer.apple.com/coreml/models/Image/ImageClassification/ResNet50/ResNet50.mlmodel",
            "filename": "ResNet50.mlmodel", 
            "size": "~98MB"
        },
        {
            "name": "SqueezeNet",
            "description": "SqueezeNet Image Classification (lightweight)",
            "url": "https://docs-assets.developer.apple.com/coreml/models/Image/ImageClassification/SqueezeNet/SqueezeNet.mlmodel",
            "filename": "SqueezeNet.mlmodel",
            "size": "~5MB"
        }
    ]
    
    successful_downloads = 0
    
    for model in models:
        print(f"\n📦 {model['name']} ({model['size']})")
        print(f"   {model['description']}")
        
        output_path = models_dir / model['filename']
        
        # Skip if already exists
        if output_path.exists():
            print(f"   ⏭️  Already exists, skipping...")
            successful_downloads += 1
            continue
        
        success = download_file(model['url'], output_path, model['name'])
        if success:
            successful_downloads += 1
            
            # Verify file size
            file_size = output_path.stat().st_size
            print(f"   📊 File size: {file_size // 1024 // 1024}MB")
    
    print(f"\n🎉 Download Summary")
    print(f"Successfully downloaded: {successful_downloads}/{len(models)} models")
    
    if successful_downloads > 0:
        print(f"\n📁 Models saved in: {models_dir.absolute()}")
        print("\n🔄 Next Steps:")
        print("1. Copy the .mlmodel files to your Xcode project")
        print("2. Add them to your app target")
        print("3. Update the URLs in RealMLModelManager.swift to point to your CDN")
        print("4. Test the models in your app")
        
        # Show how to add to Xcode
        print(f"\n📋 To add to Xcode:")
        print(f"1. Drag {models_dir}/*.mlmodel into your Xcode project")
        print(f"2. Ensure 'Add to target: LegacyLense' is checked")
        print(f"3. The models will be bundled with your app")
        
    else:
        print("\n⚠️  No models were downloaded successfully")
        print("This might be due to network issues or Apple changing their URLs")
        print("Try downloading manually from Apple's CoreML gallery:")
        print("https://developer.apple.com/machine-learning/models/")

if __name__ == "__main__":
    main()