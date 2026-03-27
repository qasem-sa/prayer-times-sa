#!/bin/bash
# build-apk.sh - Build Prayer Times APK
# Requirements: Java 17+, Android SDK, Node.js
# Usage: bash build-apk.sh

set -e

APP_NAME="PrayerTimes"
APP_ID="com.prayer.times.sa"
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$APP_DIR/build"
OUTPUT_DIR="$APP_DIR/dist"

echo "🕌 Building Prayer Times APK..."

# Clean
rm -rf "$BUILD_DIR" "$OUTPUT_DIR"
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

# 1. Create Android project structure
echo "📁 Creating Android project structure..."
PROJECT="$BUILD_DIR/app"
mkdir -p "$PROJECT/app/src/main/java/com/prayer/times/sa"
mkdir -p "$PROJECT/app/src/main/res/layout"
mkdir -p "$PROJECT/app/src/main/res/values"
mkdir -p "$PROJECT/app/src/main/res/xml"
mkdir -p "$PROJECT/app/src/main/res/drawable"
mkdir -p "$PROJECT/app/src/main/assets/www"

# Copy web assets
cp "$APP_DIR/index.html" "$PROJECT/app/src/main/assets/www/"
cp "$APP_DIR/manifest.json" "$PROJECT/app/src/main/assets/www/"
cp "$APP_DIR/sw.js" "$PROJECT/app/src/main/assets/www/"
cp -r "$APP_DIR/icons" "$PROJECT/app/src/main/assets/www/"

# 2. Create AndroidManifest.xml
cat > "$PROJECT/app/src/main/AndroidManifest.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.prayer.times.sa">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:theme="@style/AppTheme"
        android:supportsRtl="true">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:configChanges="orientation|screenSize|keyboardHidden">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <receiver android:name=".PrayerWidget" android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/prayer_widget_info" />
        </receiver>
    </application>
</manifest>
EOF

# 3. Create MainActivity.java
cat > "$PROJECT/app/src/main/java/com/prayer/times/sa/MainActivity.java" << 'JAVAEOF'
package com.prayer.times.sa;

import android.app.Activity;
import android.os.Bundle;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.WebView;
import android.webkit.WebSettings;
import android.webkit.WebViewClient;
import android.webkit.WebChromeClient;

public class MainActivity extends Activity {
    private WebView webView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        );

        webView = new WebView(this);
        setContentView(webView);

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setCacheMode(WebSettings.LOAD_DEFAULT);
        settings.setAllowFileAccess(true);

        webView.setWebViewClient(new WebViewClient());
        webView.setWebChromeClient(new WebChromeClient());

        webView.loadUrl("file:///android_asset/www/index.html");
    }

    @Override
    public void onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }
}
JAVAEOF

# 4. Create PrayerWidget.java
cat > "$PROJECT/app/src/main/java/com/prayer/times/sa/PrayerWidget.java" << 'JAVAEOF'
package com.prayer.times.sa;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.widget.RemoteViews;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.Locale;

public class PrayerWidget extends AppWidgetProvider {
    
    // Simplified prayer times for Riyadh (approximate)
    private static final String[][] PRAYER_TIMES = {
        {"الفجر", "04:25"},
        {"الظهر", "11:55"},
        {"العصر", "15:15"},
        {"المغرب", "18:10"},
        {"العشاء", "19:35"}
    };

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        for (int widgetId : appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId);
        }
    }

    private void updateWidget(Context context, AppWidgetManager manager, int widgetId) {
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.prayer_widget);
        
        // Find next prayer
        Calendar now = Calendar.getInstance();
        int currentMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE);
        
        String nextName = "الفجر";
        String nextTime = "04:25";
        int remainingMinutes = 0;
        boolean found = false;
        
        for (String[] prayer : PRAYER_TIMES) {
            String[] parts = prayer[1].split(":");
            int prayerMinutes = Integer.parseInt(parts[0]) * 60 + Integer.parseInt(parts[1]);
            
            if (prayerMinutes > currentMinutes && !found) {
                nextName = prayer[0];
                nextTime = prayer[1];
                remainingMinutes = prayerMinutes - currentMinutes;
                found = true;
            }
        }
        
        if (!found) {
            // Next prayer is Fajr tomorrow
            String[] parts = PRAYER_TIMES[0][1].split(":");
            remainingMinutes = (24 * 60 - currentMinutes) + Integer.parseInt(parts[0]) * 60 + Integer.parseInt(parts[1]);
            nextName = PRAYER_TIMES[0][0];
            nextTime = PRAYER_TIMES[0][1];
        }
        
        int hours = remainingMinutes / 60;
        int minutes = remainingMinutes % 60;
        String remaining = String.format(Locale.getDefault(), "%02d:%02d", hours, minutes);
        
        views.setTextViewText(R.id.widget_prayer_name, nextName);
        views.setTextViewText(R.id.widget_prayer_time, nextTime + " ص");
        views.setTextViewText(R.id.widget_remaining, remaining);
        views.setTextViewText(R.id.widget_remaining_label, "متبقي");
        
        // Open app on click
        Intent intent = new Intent(context, MainActivity.class);
        PendingIntent pending = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(R.id.widget_root, pending);
        
        manager.updateAppWidget(widgetId, views);
    }
}
JAVAEOF

# 5. Resources
cat > "$PROJECT/app/src/main/res/values/strings.xml" << 'EOF'
<resources>
    <string name="app_name">مواقيت الصلاة</string>
</resources>
EOF

cat > "$PROJECT/app/src/main/res/values/styles.xml" << 'EOF'
<resources>
    <style name="AppTheme" parent="android:Theme.Material.NoActionBar">
        <item name="android:windowBackground">@android:color/black</item>
        <item name="android:statusBarColor">@android:color/transparent</item>
    </style>
</resources>
EOF

# 6. Widget layout
cat > "$PROJECT/app/src/main/res/layout/prayer_widget.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/widget_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="#0f172a"
    android:orientation="vertical"
    android:padding="12dp"
    android:gravity="center">

    <TextView
        android:id="@+id/widget_prayer_name"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="الفجر"
        android:textColor="#38bdf8"
        android:textSize="18sp"
        android:textStyle="bold" />

    <TextView
        android:id="@+id/widget_prayer_time"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="04:25 ص"
        android:textColor="#94a3b8"
        android:textSize="14sp" />

    <TextView
        android:id="@+id/widget_remaining"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="02:30"
        android:textColor="#fbbf24"
        android:textSize="20sp"
        android:textStyle="bold"
        android:layout_marginTop="4dp" />

    <TextView
        android:id="@+id/widget_remaining_label"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="متبقي"
        android:textColor="#64748b"
        android:textSize="11sp" />

</LinearLayout>
EOF

# 7. Widget info XML
cat > "$PROJECT/app/src/main/res/xml/prayer_widget_info.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="180dp"
    android:minHeight="110dp"
    android:updatePeriodMillis="60000"
    android:initialLayout="@layout/prayer_widget"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen" />
EOF

# 8. Copy icon
cp "$APP_DIR/icons/icon-192.png" "$PROJECT/app/src/main/res/mipmap/ic_launcher.png"

# 9. Create build.gradle files
cat > "$PROJECT/settings.gradle" << 'EOF'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "PrayerTimes"
include ':app'
EOF

cat > "$PROJECT/build.gradle" << 'EOF'
plugins {
    id 'com.android.application' version '8.1.0' apply false
}
EOF

cat > "$PROJECT/app/build.gradle" << 'EOF'
plugins {
    id 'com.android.application'
}

android {
    namespace 'com.prayer.times.sa'
    compileSdk 34

    defaultConfig {
        applicationId "com.prayer.times.sa"
        minSdk 24
        targetSdk 34
        versionCode 1
        versionName "1.0"
    }

    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
}

dependencies {
    implementation 'androidx.appcompat:appcompat:1.6.1'
}
EOF

# 10. gradle.properties
cat > "$PROJECT/gradle.properties" << 'EOF'
android.useAndroidX=true
org.gradle.jvmargs=-Xmx2048m
EOF

# 11. Create gradlew
cat > "$PROJECT/gradlew" << 'GRADLEW'
#!/bin/sh
# Minimal gradle wrapper
cd "$(dirname "$0")"
exec gradle "$@"
GRADLEW
chmod +x "$PROJECT/gradlew"

echo ""
echo "✅ Android project created at: $PROJECT"
echo ""
echo "To build the APK, run:"
echo "  cd $PROJECT"
echo "  ./gradlew assembleDebug"
echo ""
echo "Or for release:"
echo "  ./gradlew assembleRelease"
echo ""
echo "Output APK will be at:"
echo "  $PROJECT/app/build/outputs/apk/debug/app-debug.apk"
echo ""

# Also create a quick shortcut
cat > "$APP_DIR/BUILD-INSTRUCTIONS.md" << 'MDEOF'
# 🕌 Prayer Times APK - Build Instructions

## Option 1: Run as PWA (No build needed)
Open `index.html` in a browser, or host it on any web server.
On Android: Chrome → Menu → "Add to Home Screen" — works like a native app!

## Option 2: Build APK

### Prerequisites
- Java 17+ (JDK)
- Android SDK (install via Android Studio or command-line tools)
- Gradle 8+

### Steps
```bash
cd build/app
./gradlew assembleDebug
```

APK output: `app/build/outputs/apk/debug/app-debug.apk`

### Install on device
```bash
adb install app/build/outputs/apk/debug/app-debug.apk
```

## Features
- ✅ All 13 regions of Saudi Arabia
- ✅ 100+ cities with accurate coordinates
- ✅ Hijri & Gregorian dates
- ✅ 12-hour time format
- ✅ Live countdown to next prayer
- ✅ PWA installable without APK
- ✅ Android Widget for home screen
- ✅ Offline support (Service Worker)
- ✅ Beautiful dark theme with Arabic RTL
MDEOF

echo "📋 Build instructions created: BUILD-INSTRUCTIONS.md"
