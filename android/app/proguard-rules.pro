# Flutter ProGuard rules
-keep class io.flutter.** { *; }
-keep class com.sunmi.** { *; }
-keep class sunmi.** { *; }
-keep class com.sunmiprint.app.** { *; }
-dontwarn io.flutter.**
-dontwarn com.sunmi.**

# Keep attributes for reflection
-keepattributes Signature
-keepattributes *Annotation*

# Flutter Blue Plus
-keep class com.bosch.** { *; }
-keep class no.nordicsemi.android.** { *; }
-keep class com.lib.flutter_blue_plus.** { *; }
-keep class io.flutter.plugins.** { *; }

# pdf_render
-keep class com.pdf.render.** { *; }
