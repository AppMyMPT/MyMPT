# ==============================================================================
# ProGuard / R8 Configuration for MyMPT
# ==============================================================================

# Сохранение строк исходников и номеров строк для читаемых краш-логов
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Аннотации и дженерики
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# ------------------------------------------------------------------------------
# 1. Flutter Framework & Engine
# ------------------------------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Регистраторы плагинов и MethodChannel
-keep class * implements io.flutter.plugin.common.PluginRegistry$PluginRegistrantCallback { *; }
-keep class * implements io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }
-keep class * implements io.flutter.plugin.common.BasicMessageChannel$MessageHandler { *; }

# ------------------------------------------------------------------------------
# 2. Нативный код приложения (Виджеты, ресиверы, сервисы)
# ------------------------------------------------------------------------------
-keep class ru.merrcurys.my_mpt.** { *; }
-keepclassmembers class ru.merrcurys.my_mpt.** { *; }

# ------------------------------------------------------------------------------
# 3. Google Play In-App Updates & Core
# ------------------------------------------------------------------------------
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# ------------------------------------------------------------------------------
# 4. RuStore Update SDK
# ------------------------------------------------------------------------------
-keep class ru.rustore.sdk.** { *; }
-dontwarn ru.rustore.sdk.**

# ------------------------------------------------------------------------------
# 5. Firebase & Google Mobile Services (FCM, Firestore, Core)
# ------------------------------------------------------------------------------
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ------------------------------------------------------------------------------
# 6. Flutter Local Notifications
# ------------------------------------------------------------------------------
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# ------------------------------------------------------------------------------
# 7. Kotlin & Desugaring warnings
# ------------------------------------------------------------------------------
-dontwarn java.lang.invoke.**
-dontwarn org.codehaus.mojo.animal_sniffer.**
-dontwarn org.checkerframework.**
-dontwarn javax.annotation.**

