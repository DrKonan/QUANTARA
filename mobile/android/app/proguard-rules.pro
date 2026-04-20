-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Supabase / GoTrue
-keep class io.supabase.** { *; }
-keep class com.haibin.calendarview.** { *; }

# Keep annotations
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Local Auth (biometric)
-keep class androidx.biometric.** { *; }

# Image picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# Prevent R8 from removing model classes used via reflection/serialization
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
