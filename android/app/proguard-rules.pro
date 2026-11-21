# Copy to: android/app/proguard-rules.pro
#
# WorkManager and Room come in through the Google Mobile Ads SDK. In a release build R8 can strip
# the generated Room class, and the app then crashes at startup, before any Dart code runs:
#   java.lang.RuntimeException: Failed to create an instance of androidx.work.impl.WorkDatabase
# Debug builds are not minified, so the problem only shows up in release / Play builds.
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.** { *; }
-keep class androidx.startup.** { *; }
-dontwarn androidx.work.**
