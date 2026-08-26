# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# MSSQL Connection (Likely uses jTDS or MS JDBC)
-keep class net.sourceforge.jtds.** { *; }
-keep class java.sql.** { *; }
-keep class javax.sql.** { *; }
-keep class com.microsoft.sqlserver.jdbc.** { *; }

# Prevent R8 from stripping native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Flutter embedding
-keep class com.google.flutter.embedding.** { *; }

# General ProGuard
-dontwarn android.support.**
-dontwarn androidx.**
-dontwarn io.flutter.**

# Suppress warnings for missing Java runtime classes (SQL Driver optional deps)
-dontwarn javax.naming.**
-dontwarn javax.sql.**
-dontwarn javax.transaction.**
-dontwarn javax.security.**
-dontwarn org.ietf.jgss.**
-dontwarn jcifs.**

# Annotation processing artifacts
-dontwarn javax.lang.model.**
-dontwarn com.squareup.javapoet.**
-dontwarn com.google.auto.value.**
