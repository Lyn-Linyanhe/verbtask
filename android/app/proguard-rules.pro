# WorkManager 需要保留这些类（Room WorkDatabase 在 R8 下必须原样保留）
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**
-keepclassmembers class * extends androidx.work.Worker { <init>(...); }

# Room（WorkDatabase 的存储层）
-keep class androidx.room.** { *; }
-dontwarn androidx.room.**
-keep @androidx.room.Entity class * { *; }
-keepclassmembers class * { @androidx.room.* <methods>; }
