# ProGuard rules for Google ML Kit Pose Detection and Camera
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_pose.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**
