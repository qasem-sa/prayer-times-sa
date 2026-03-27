#!/bin/bash
# setup-android-build.sh - Complete Android build environment setup
# Run this on a machine with internet access and Java 17+

set -e

echo "🕌 Prayer Times APK - Build Environment Setup"
echo "=============================================="

# Check prerequisites
if ! command -v java &> /dev/null; then
    echo "❌ Java not found. Install JDK 17+ first:"
    echo "   Ubuntu: sudo apt install openjdk-17-jdk"
    echo "   macOS:  brew install openjdk@17"
    echo "   Windows: download from https://adoptium.net"
    exit 1
fi

echo "✅ Java: $(java -version 2>&1 | head -1)"

if ! command -v gradle &> /dev/null; then
    echo "📦 Installing Gradle wrapper..."
    # Use gradle wrapper instead of system gradle
    USE_GRADLEW=true
else
    echo "✅ Gradle: $(gradle --version 2>/dev/null | head -1)"
    USE_GRADLEW=false
fi

# Check/set Android SDK
if [ -z "$ANDROID_HOME" ]; then
    # Common locations
    for dir in "$HOME/Android/Sdk" "$HOME/Library/Android/sdk" "$LOCALAPPDATA/Android/Sdk" "/opt/android-sdk"; do
        if [ -d "$dir" ]; then
            export ANDROID_HOME="$dir"
            break
        fi
    done
fi

if [ -z "$ANDROID_HOME" ]; then
    echo "📥 Downloading Android Command Line Tools..."
    mkdir -p "$HOME/android-sdk"
    cd "$HOME/android-sdk"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        URL="https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip"
    elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* ]]; then
        URL="https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
    else
        URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
    fi
    
    wget -q "$URL" -O cmdline-tools.zip
    unzip -qo cmdline-tools.zip
    mkdir -p cmdline-tools/latest
    mv cmdline-tools/* cmdline-tools/latest/ 2>/dev/null || true
    
    export ANDROID_HOME="$HOME/android-sdk"
    export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
    
    echo "📦 Installing Android SDK components..."
    yes | sdkmanager --licenses > /dev/null 2>&1
    sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
    
    echo "✅ Android SDK installed at: $ANDROID_HOME"
else
    echo "✅ Android SDK: $ANDROID_HOME"
fi

echo ""
echo "🏗️ Building APK..."
cd "$(dirname "$0")/build/app"

if [ "$USE_GRADLEW" = true ]; then
    # Generate gradle wrapper
    if command -v gradle &> /dev/null; then
        gradle wrapper --gradle-version 8.4
    else
        # Download gradle wrapper manually
        echo "📥 Downloading Gradle..."
        wget -q "https://services.gradle.org/distributions/gradle-8.4-bin.zip" -O /tmp/gradle.zip
        unzip -qo /tmp/gradle.zip -d /tmp/
        /tmp/gradle-8.4/bin/gradle wrapper --gradle-version 8.4
    fi
    chmod +x gradlew
    ./gradlew assembleRelease
else
    gradle assembleRelease
fi

APK_PATH="app/build/outputs/apk/release/app-release-unsigned.apk"

if [ -f "$APK_PATH" ]; then
    echo ""
    echo "✅ APK built successfully!"
    echo "📍 Location: $APK_PATH"
    echo ""
    
    # Sign the APK
    if command -v apksigner &> /dev/null || [ -f "$ANDROID_HOME/build-tools/34.0.0/apksigner" ]; then
        echo "🔏 Signing APK..."
        KEYSTORE="$HOME/.android/debug.keystore"
        if [ ! -f "$KEYSTORE" ]; then
            keytool -genkey -v -keystore "$KEYSTORE" -alias androiddebugkey \
                -keyalg RSA -keysize 2048 -validity 10000 \
                -storepass android -keypass android \
                -dname "CN=Debug, OU=Debug, O=Debug, L=Debug, S=Debug, C=US" 2>/dev/null
        fi
        
        SIGNED_APK="app/build/outputs/apk/release/prayer-times-signed.apk"
        "$ANDROID_HOME/build-tools/34.0.0/apksigner" sign \
            --ks "$KEYSTORE" \
            --ks-key-alias androiddebugkey \
            --ks-pass pass:android \
            --key-pass pass:android \
            --out "$SIGNED_APK" \
            "$APK_PATH"
        
        echo "✅ Signed APK: $SIGNED_APK"
    fi
    
    echo ""
    echo "📲 Install on device:"
    echo "   adb install $APK_PATH"
    echo ""
    echo "🕌 Done!"
else
    echo "❌ Build failed. Check the output above for errors."
    exit 1
fi
