# Google Mobile Ads pulls in WorkManager, whose Room database (WorkDatabase_Impl)
# is created by reflection at app startup via androidx.startup. Without these
# rules R8 strips it and the release build crashes on launch with
# "Failed to create an instance of androidx.work.impl.WorkDatabase".
-keep class androidx.work.** { *; }
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.room.** { *; }
-keep class androidx.startup.** { *; }
-keep class * implements androidx.startup.Initializer { <init>(); }

# Google Mobile Ads SDK
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**
