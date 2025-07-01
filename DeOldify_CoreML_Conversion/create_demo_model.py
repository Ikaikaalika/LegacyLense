#!/usr/bin/env python3
"""
Create a demo colorization model for testing LegacyLense integration
This creates a simple model that adds basic colors for demonstration
"""

import coremltools as ct
import numpy as np

def create_demo_colorization_model():
    """Create a simple demo model that adds basic colorization"""
    
    # Create a simple function that adds warm tones to grayscale images
    def colorize_demo(grayscale_image):
        # Convert grayscale to RGB with warm tones
        batch_size, channels, height, width = grayscale_image.shape
        
        # Create RGB output
        rgb_output = np.zeros((batch_size, 3, height, width), dtype=np.float32)
        
        # Add warm colorization
        rgb_output[:, 0, :, :] = grayscale_image[:, 0, :, :] * 1.1  # Red channel (warmer)
        rgb_output[:, 1, :, :] = grayscale_image[:, 0, :, :] * 1.0  # Green channel (neutral)
        rgb_output[:, 2, :, :] = grayscale_image[:, 0, :, :] * 0.8  # Blue channel (less blue)
        
        # Ensure values are in [0, 1]
        rgb_output = np.clip(rgb_output, 0.0, 1.0)
        
        return rgb_output
    
    # Create model using MIL (Model Intermediate Language)
    from coremltools.converters.mil import Builder as mb
    
    @mb.program(input_specs=[mb.TensorSpec(shape=(1, 1, 256, 256), dtype=np.float32)])
    def colorization_program(grayscale_image):
        # Repeat grayscale to 3 channels
        rgb_base = mb.concat(values=[grayscale_image, grayscale_image, grayscale_image], axis=1)
        
        # Apply color transformation for warm tones
        # Red channel: slightly enhanced
        red_mult = mb.const(val=np.array([1.1, 1.0, 0.8]).reshape(1, 3, 1, 1), name="color_multiplier")
        colorized = mb.mul(x=rgb_base, y=red_mult)
        
        # Ensure output is in valid range
        colorized = mb.clip(x=colorized, alpha=0.0, beta=1.0)
        
        return colorized
    
    # Convert to CoreML model
    model = ct.convert(
        colorization_program,
        inputs=[ct.ImageType(
            name="grayscale_image",
            shape=(1, 1, 256, 256)
        )],
        outputs=[ct.ImageType(name="colorized_image")],
        minimum_deployment_target=ct.target.iOS15
    )
    
    # Add metadata
    model.short_description = "Demo Photo Colorization"
    model.description = "Simple demo model that adds warm tones to grayscale photos"
    model.author = "LegacyLense Demo"
    model.license = "MIT License"
    model.version = "1.0"
    
    return model

def main():
    """Create and save the demo model"""
    print("🎨 Creating Demo Colorization Model...")
    
    try:
        model = create_demo_colorization_model()
        
        # Save model
        output_path = "DemoColorizer.mlmodel"
        model.save(output_path)
        
        print(f"✅ Demo model created: {output_path}")
        print(f"📊 This is a simple demo model for testing the colorization pipeline")
        print(f"🎯 It adds warm tones to grayscale images")
        print(f"\n📋 To use in LegacyLense:")
        print(f"1. Copy {output_path} to your Xcode project")
        print(f"2. Add it to the app bundle")
        print(f"3. Test the colorization feature")
        
    except Exception as e:
        print(f"❌ Failed to create demo model: {e}")

if __name__ == "__main__":
    main()