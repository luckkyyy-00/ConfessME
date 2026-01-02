# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }

# In App Purchase
-keep class com.android.billingclient.api.** { *; }

# Retrofit / OkHttp (if used implicitly)
-dontwarn okhttp3.**
-dontwarn retrofit2.**

# Prevent R8 from stripping standard Flutter classes
-keep class com.google.flutter.** { *; }
-keepattributes SourceFile,LineNumberTable


# Google Play Core (Fixes R8 missing class errors)
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.finsky.** { *; }
-dontwarn com.google.android.play.core.**
