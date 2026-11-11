package com.ezoic.ezoic_flutter_cmp_sdk

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.ezoic.ads.sdk.privacy.cmp.EzoicCmp
import com.ezoic.ads.sdk.privacy.cmp.EzoicCmpConfiguration
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class EzoicFlutterCmpSdkPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
  private companion object {
    const val TAG = "EzoicFlutterCmpSdk"
  }

  private lateinit var channel: MethodChannel
  private lateinit var appContext: Context
  private val mainHandler = Handler(Looper.getMainLooper())

  /** The host Activity, available while the plugin is attached to one. */
  private var activity: Activity? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    appContext = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "com.ezoic/ezoic_flutter_cmp_sdk")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onDetachedFromActivity() {
    activity = null
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "initialize" -> {
        val domain = call.argument<String>("domain")
        if (domain.isNullOrEmpty()) {
          result.error("EzoicCmp", "initialize requires a non-empty `domain`.", null); return
        }
        val debug = call.argument<Boolean>("debugEnabled") ?: false
        EzoicCmp.initialize(
          appContext,
          domain,
          EzoicCmpConfiguration(
            cmpEnabled = call.argument<Boolean>("cmpEnabled") ?: true,
            autoReadConsent = call.argument<Boolean>("autoReadConsent") ?: true,
            debugEnabled = debug
          )
        )
        result.success(null)
        if (call.argument<Boolean>("autoPresentConsent") ?: true) {
          mainHandler.post { autoPresentConsent(debug) }
        }
      }
      "presentConsentIfRequired" -> presentConsent(reopen = false) { result.success(it) }
      "presentConsentSettings" -> presentConsent(reopen = true) { result.success(it) }
      "isConsentRequired" -> result.success(EzoicCmp.isConsentRequired)
      "isPrivacyOptionsRequired" -> result.success(EzoicCmp.isPrivacyOptionsRequired)
      "resetConsent" -> {
        EzoicCmp.resetConsent()
        result.success(null)
      }
      else -> result.notImplemented()
    }
  }

  /**
   * Runs once after `initialize` when `autoPresentConsent` is on. The outcome
   * is only logged; apps that need it call `presentConsentIfRequired`.
   */
  private fun autoPresentConsent(debug: Boolean) {
    if (activity == null) {
      if (debug) Log.d(TAG, "Auto-present consent skipped: no foreground Activity")
      return
    }
    presentConsent(reopen = false) { outcome ->
      if (debug) Log.d(TAG, "Auto-present consent outcome: $outcome")
    }
  }

  /**
   * Presents the consent dialog (or the settings when [reopen]) from the host
   * Activity. Always completes with an outcome map, never `result.error`.
   */
  private fun presentConsent(reopen: Boolean, completion: (Map<String, Any>) -> Unit) {
    val host = activity
    if (host == null) {
      completion(mapOf("type" to "failed", "code" to -1, "message" to "No foreground Activity"))
      return
    }
    if (reopen) {
      EzoicCmp.presentConsentSettings(host) { completion(it.toWireMap()) }
    } else {
      EzoicCmp.presentConsentIfRequired(host) { completion(it.toWireMap()) }
    }
  }
}
