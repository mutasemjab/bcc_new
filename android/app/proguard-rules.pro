# flutter_local_notifications stores notification details with Gson.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
# Agora RTC
-keep class io.agora.** { *; }
-dontwarn io.agora.**
