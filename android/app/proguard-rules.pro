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

# Bluetooth Classic (flutter_bluetooth_serial)
-keep class io.flutter.plugins.** { *; }

# Method channel handlers are reached reflectively from the Dart side.
-keep class com.sunmiprint.app.**$Companion { *; }

# pdf_render
-keep class com.pdf.render.** { *; }
