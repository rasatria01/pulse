# flutter_local_notifications stores scheduled notifications as GSON JSON and
# reads them back after a reboot or an app update. Renamed or stripped model
# fields would break that, so keep the plugin as written.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepattributes Signature
