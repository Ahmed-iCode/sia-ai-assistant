-keep class com.dexterous.** { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keepattributes Signature,InnerClasses,EnclosingMethod
