# 🛠️ LegacyLense Development Guide

## 📁 Project Structure

```
LegacyLense/
├── LegacyLense/                    # Main iOS Application
│   ├── LegacyLenseApp.swift        # App entry point
│   ├── ContentView.swift           # Main content view
│   │
│   ├── Models/                     # Data Models & Business Logic
│   │   ├── RealMLModelManager.swift      # AI model management
│   │   ├── PhotoRestorationModel.swift  # Photo restoration data model
│   │   ├── DeviceCapabilityManager.swift # Device capability detection
│   │   ├── ModelDownloader.swift        # Model download utilities
│   │   ├── PremiumPhotoEffects.swift    # Premium effects processing
│   │   └── RealPhotoProcessor.swift     # Core photo processing
│   │
│   ├── Services/                   # Business Services
│   │   ├── SubscriptionManager.swift       # StoreKit subscriptions
│   │   ├── CrashReportingService.swift     # Analytics & crash reporting
│   │   ├── CloudRestorationService.swift  # Cloud processing (future)
│   │   └── HybridPhotoRestorationService.swift # Local/cloud hybrid
│   │
│   ├── ViewModels/                 # MVVM View Models
│   │   └── PhotoRestorationViewModel.swift # Main photo processing VM
│   │
│   ├── Views/                      # SwiftUI Views
│   │   ├── OnboardingView.swift         # App onboarding flow
│   │   ├── PhotoComparisonView.swift    # Before/after comparison
│   │   ├── PhotoSelectionArea.swift     # Photo picker UI
│   │   ├── ModelDownloadView.swift      # AI model downloads
│   │   ├── ProcessingSettingsView.swift # Processing options
│   │   ├── SubscriptionView.swift       # Subscription management
│   │   ├── LaunchScreenView.swift       # Launch screen
│   │   ├── CompatibilityContentView.swift # iOS compatibility
│   │   │
│   │   ├── Premium/                     # Premium Feature Views
│   │   │   ├── PremiumSubscriptionView.swift # Subscription purchase
│   │   │   ├── MLModelManagerView.swift      # AI model management
│   │   │   ├── PremiumSettingsView.swift     # Premium settings
│   │   │   ├── BatchProcessingView.swift     # Batch processing
│   │   │   └── PremiumUIComponents.swift     # Reusable premium UI
│   │   │
│   │   ├── Settings/                    # Settings Views
│   │   │   └── CrashReportingSettingsView.swift # Analytics settings
│   │   │
│   │   └── Legal/                       # Legal Documents
│   │       └── LegalDocumentView.swift  # Privacy policy viewer
│   │
│   ├── Extensions/                 # Swift Extensions
│   │   ├── UIImage+Extensions.swift     # Image processing utilities
│   │   └── StoreKitExtensions.swift     # StoreKit helpers
│   │
│   ├── Utilities/                  # Helper Utilities
│   │   └── ErrorTypes.swift             # Error definitions
│   │
│   ├── Legal/                      # Legal Documents
│   │   ├── PrivacyPolicy.md             # Privacy policy
│   │   └── TermsOfService.md            # Terms of service
│   │
│   ├── Assets.xcassets/            # App Assets
│   │   ├── AppIcon.appiconset/          # App icons (all sizes)
│   │   └── AccentColor.colorset/        # App accent color
│   │
│   └── MobileNetV2.mlmodel         # Bundled AI model (24MB)
│
├── LegacyLenseTests/               # Unit Tests
├── LegacyLenseUITests/             # UI Tests
├── Configuration.storekit          # StoreKit testing configuration
├── AppStore_Screenshots/           # App Store marketing assets
├── Documentation/                  # Project Documentation
└── Development/                    # Development Tools & Guides
```

## 🏗️ Architecture

### MVVM Pattern
- **Models**: Data structures and business logic
- **Views**: SwiftUI user interface components
- **ViewModels**: Binding layer between Views and Models

### Key Components

#### AI Model Management
- `RealMLModelManager`: Handles CoreML model loading, downloading, and processing
- `MobileNetV2.mlmodel`: 24MB bundled AI model for instant processing
- Core Image fallbacks for reliability

#### Subscription System
- `SubscriptionManager`: StoreKit integration with 7-day free trial
- `Configuration.storekit`: Local testing configuration
- Premium features gated behind subscription

#### Photo Processing Pipeline
1. Photo selection via `PhotoSelectionArea`
2. Processing via `RealMLModelManager` or Core Image
3. Before/after comparison in `PhotoComparisonView`
4. Save enhanced photo back to library

## 🔧 Development Setup

### Prerequisites
- **Xcode 15.0+** (latest recommended)
- **iOS 15.0+** deployment target
- **macOS 12.0+** for development
- **Apple Developer Account** for device testing

### Getting Started
1. Clone the repository
2. Open `LegacyLense.xcodeproj` in Xcode
3. Configure your development team in project settings
4. Build and run on simulator (⌘+R)

### Device Testing
1. Connect iPhone/iPad via USB
2. Select device in Xcode scheme selector
3. Configure automatic code signing
4. Build and install on device
5. Trust developer certificate in Settings → General → VPN & Device Management

## 🧪 Testing

### Unit Tests (`LegacyLenseTests/`)
- `PhotoRestorationModelTests.swift`: Core model testing
- `RealMLModelManagerTests.swift`: AI model management testing
- `SubscriptionManagerTests.swift`: StoreKit functionality testing
- `TestHelpers.swift`: Testing utilities

### UI Tests (`LegacyLenseUITests/`)
- `LegacyLenseUITests.swift`: General UI flow testing
- `PremiumFlowUITests.swift`: Premium subscription flow testing
- `LegacyLenseUITestsLaunchTests.swift`: Launch performance testing

### Running Tests
```bash
# Unit tests only
⌘+U in Xcode

# UI tests
⌘+U with UI Test scheme selected

# All tests
Product → Test in Xcode
```

## 🤖 AI Models

### Bundled Models
- **MobileNetV2**: 24MB real neural network for instant AI processing
- Always available, no download required

### Downloadable Models
- **ESRGAN**: 64MB super resolution model (4x upscaling)
- **ResNet50**: 98MB feature extraction model
- Downloaded on-demand from public repositories

### Core Image Fallbacks
- Always-available high-quality processing
- Used when AI models aren't available
- Provides consistent user experience

## 💻 Code Standards

### Swift Style Guide
- Follow Apple's Swift API Design Guidelines
- Use descriptive variable and function names
- Prefer `let` over `var` when possible
- Use SwiftUI best practices

### File Organization
- Group related functionality in directories
- Keep files focused and under 500 lines when possible
- Use meaningful file names that describe their purpose

### Error Handling
- Use proper error types from `ErrorTypes.swift`
- Provide meaningful error messages
- Track errors with `CrashReportingService`

### Performance
- Optimize image processing for device capabilities
- Use async/await for heavy operations
- Monitor memory usage during AI processing

## 🔒 Privacy & Security

### Data Handling
- All photo processing happens locally on device
- No photos uploaded to external servers
- Anonymous usage analytics only

### Privacy Compliance
- Proper usage descriptions for photo library access
- GDPR-compliant privacy policy
- User consent for analytics

## 📱 App Store Preparation

### Required Assets
- ✅ App icons (all sizes in AppIcon.appiconset)
- ✅ Screenshots for all device sizes
- ✅ Privacy policy and terms of service
- ✅ App Store metadata and descriptions

### Code Signing
- Configure development team in Xcode
- Use automatic signing for development
- Archive for distribution when ready

### Testing Checklist
- [ ] App builds without warnings
- [ ] Runs on multiple device sizes
- [ ] Photo library permissions work
- [ ] AI models load correctly
- [ ] Subscription flow works
- [ ] Premium features unlock properly

## 🚀 Deployment

### TestFlight
1. Archive the app (Product → Archive)
2. Upload to App Store Connect
3. Add to TestFlight for beta testing
4. Invite internal/external testers

### App Store Release
1. Complete metadata in App Store Connect
2. Upload final build
3. Submit for review
4. Monitor review status

## 🐛 Debugging

### Common Issues
- **Model loading failures**: Check device storage and memory
- **Subscription issues**: Verify StoreKit configuration
- **Photo processing errors**: Check image format and size
- **Performance problems**: Monitor memory usage in Instruments

### Debugging Tools
- Xcode Instruments for performance profiling
- Console app for device logs
- CrashReportingService for error tracking

## 🤝 Contributing

### Code Reviews
- Ensure code follows style guide
- Test on multiple devices
- Document complex algorithms
- Update tests for new features

### Version Control
- Use descriptive commit messages
- Keep commits focused and atomic
- Test before pushing changes

---

**Happy coding! 🚀**