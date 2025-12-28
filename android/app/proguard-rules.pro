# -----------------------------------------------
# Flutter & Kotlin essentials
# -----------------------------------------------

# Keep all classes annotated with @Keep
-keep @androidx.annotation.Keep class * { *; }

# Keep Kotlin metadata annotations
-keep class kotlin.Metadata { *; }

# Keep all Parcelable implementations
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Flutter embedding and engine classes
-keep class io.flutter.embedding.android.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep AndroidX + Google classes (used via reflection in plugins)
-keep class androidx.** { *; }
-keep class com.google.** { *; }

# Keep all enums (prevents obfuscation issues)
-keepclassmembers enum * { *; }

# -----------------------------------------------
# Play Core handling (you are NOT using it)
# -----------------------------------------------

# Prevent R8 errors about missing Play Core classes
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-keep interface com.google.android.play.core.** { *; }

# -----------------------------------------------
# Optional: remove logging and unused code for release
# (uncomment after testing thoroughly)
# -----------------------------------------------

# -dontwarn kotlin.**
# -dontwarn io.flutter.**
# -dontwarn androidx.**
# -keep class * {
#     public <init>(...);
# }
# -----------------------------------------------
# flutter_local_notifications specific
# -----------------------------------------------

# Keep all classes in the plugin package
-keep class com.dexterous.** { *; }

# Keep WorkManager (used internally by notifications)
-keep class androidx.work.** { *; }

# Keep Notification-related classes
-keep class android.app.Notification { *; }
-keep class android.app.NotificationManager { *; }
-keep class android.app.NotificationChannel { *; }
-keep class android.app.NotificationChannelGroup { *; }
