# Keep generic signatures & annotations for Gson TypeToken in R8 Full Mode
-keepattributes Signature,InnerClasses,EnclosingMethod,*Annotation*
-dontwarn sun.misc.**

# Gson & TypeToken subclasses (fixes Missing type parameter in FlutterLocalNotificationsPlugin$1)
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken { *; }
-keep public class * extends com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * extends com.google.gson.internal.bind.TypeAdapterFactory
-keep class * extends com.google.gson.JsonSerializer
-keep class * extends com.google.gson.JsonDeserializer

# Flutter Local Notifications models, receivers & serialized fields
-keep class com.dexterous.** { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
