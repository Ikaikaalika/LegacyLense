# 🔧 **Xcode Project Settings Configuration**

## **⚠️ Info.plist Build Error Fix**

The build error occurs because modern Xcode projects auto-generate Info.plist from build settings. Follow these steps to configure your project correctly:

## **📋 Required Xcode Configuration Steps**

### **1. Open Project Settings**
1. Open `LegacyLense.xcodeproj` in Xcode
2. Select the **LegacyLense** project in the navigator
3. Select the **LegacyLense** target
4. Go to the **Info** tab

### **2. Configure Bundle Settings**
```
Bundle Identifier: com.tylergee.legacylense
Bundle Name: LegacyLense
Bundle Display Name: LegacyLense
Bundle Version: 1
Bundle Short Version String: 1.0
```

### **3. Configure Info.plist Key-Value Pairs**
Add these entries in the **Custom iOS Target Properties** section:

#### **Privacy Permissions**
```
NSPhotoLibraryUsageDescription = "LegacyLense needs access to your photo library to restore and enhance your precious memories. We only access the photos you specifically select for restoration."

NSCameraUsageDescription = "LegacyLense can access your camera to take photos for immediate restoration and enhancement."

NSPhotoLibraryAddUsageDescription = "LegacyLense needs permission to save your restored and enhanced photos back to your photo library."
```

#### **App Configuration**
```
LSApplicationCategoryType = "public.app-category.photography"

UILaunchScreen = {
    UIColorName = "AccentColor"
}

UISupportedInterfaceOrientations = [
    "UIInterfaceOrientationPortrait",
    "UIInterfaceOrientationLandscapeLeft", 
    "UIInterfaceOrientationLandscapeRight"
]

UISupportedInterfaceOrientations~ipad = [
    "UIInterfaceOrientationPortrait",
    "UIInterfaceOrientationPortraitUpsideDown",
    "UIInterfaceOrientationLandscapeLeft",
    "UIInterfaceOrientationLandscapeRight"
]

UIRequiredDeviceCapabilities = ["armv7"]

UIApplicationSupportsIndirectInputEvents = YES

ITSAppUsesNonExemptEncryption = NO
```

#### **Background Modes** (if needed)
```
UIBackgroundModes = ["background-processing"]

BGTaskSchedulerPermittedIdentifiers = [
    "com.tylergee.legacylense.photo-processing",
    "com.tylergee.legacylense.model-download"
]
```

### **4. Deployment Info**
- **iOS Deployment Target:** 15.0
- **Supported Device Families:** iPhone, iPad
- **Requires Full Screen:** No

### **5. Build Settings to Verify**
Go to **Build Settings** tab and ensure:
- **Product Bundle Identifier:** `com.tylergee.legacylense`
- **Generate Info.plist File:** YES (this should be enabled by default)
- **Info.plist File:** (should be empty/automatic)

## **🔨 Alternative: Project.pbxproj Direct Edit**

If you prefer command-line configuration, you can manually edit the project file:

### **Quick Fix Commands**
```bash
# Navigate to project directory
cd /Users/tylergee/Documents/LegacyLense

# Edit the project file to add Info.plist keys
# This requires careful editing of the .xcodeproj/project.pbxproj file
```

## **✅ Test Build After Configuration**

1. **Clean Build Folder:** Product → Clean Build Folder (⌘+Shift+K)
2. **Build Project:** Product → Build (⌘+B)
3. **Run on Simulator:** Product → Run (⌘+R)

## **🚨 Common Issues & Solutions**

### **Issue: "Multiple commands produce Info.plist"**
**Solution:** Ensure no manual Info.plist file exists in the project folder. Xcode should auto-generate it.

### **Issue: Missing App Icons**
**Solution:** The app icons should be automatically detected from `Assets.xcassets/AppIcon.appiconset/`

### **Issue: Permissions not working**
**Solution:** Verify the privacy descriptions are added to the target's Info settings.

### **Issue: StoreKit not working**
**Solution:** Ensure `Configuration.storekit` is added to the project target.

## **📱 Testing Checklist**

After configuration:
- [ ] App builds without errors
- [ ] App icons appear correctly
- [ ] Photo library permission prompt works
- [ ] Camera permission prompt works  
- [ ] AI models load correctly
- [ ] Subscription flow works
- [ ] No crash on launch

## **🔄 Next Steps After Fix**

1. Build and test the app
2. Take actual screenshots on simulator/device
3. Configure code signing for device testing
4. Test StoreKit subscriptions on real device
5. Prepare for App Store upload

---

**Quick Command to check project structure:**
```bash
find LegacyLense -name "*.plist" -type f
# Should return empty (no manual Info.plist files)
```