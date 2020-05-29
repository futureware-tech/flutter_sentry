package org.dasfoo.flutter_sentry

import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar


/** FlutterSentryPlugin */
class FlutterSentryPlugin : FlutterPlugin, MethodCallHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private var firebaseTestLab: Boolean? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        if (firebaseTestLab == null) {
            // https://firebase.google.com/docs/test-lab/android/android-studio.
            val testLabSetting = Settings.System.getString(
                    flutterPluginBinding.applicationContext.contentResolver,
                    "firebase.test.lab")
            firebaseTestLab = "true" == testLabSetting
        }

        val channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_sentry")
        channel.setMethodCallHandler(this)
    }

    // This static function is optional and equivalent to onAttachedToEngine. It supports the old
    // pre-Flutter-1.12 Android projects. You are encouraged to continue supporting
    // plugin registration via this function while apps migrate to use the new Android APIs
    // post-flutter-1.12 via https://flutter.dev/go/android-project-migration.
    //
    // It is encouraged to share logic between onAttachedToEngine and registerWith to keep
    // them functionally equivalent. Only one of onAttachedToEngine or registerWith will be called
    // depending on the user's project. onAttachedToEngine or registerWith must both be defined
    // in the same class.
    companion object {
        @JvmStatic
        @Suppress("unused")
        fun registerWith(registrar: Registrar) {
            val channel = MethodChannel(registrar.messenger(), "flutter_sentry")
            channel.setMethodCallHandler(FlutterSentryPlugin())
        }
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        if (call.method == "nativeCrash") {
            // Return an error in case something goes wrong and we get past the crash.
            result.error("FAILED_PRECONDITION", "Failed to cause a native crash.", null)
            // Throw an error that a sane implementation will not suppress.
            throw OutOfMemoryError("This is a nativeCrash method call.")
        } else if (call.method == "getFirebaseTestLab") {
            result.success(firebaseTestLab)
            return
        }

        result.notImplemented()
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
