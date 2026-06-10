package com.ezoic.ezoic_flutter_sdk

import android.app.Application
import android.content.Context
import com.ezoic.ads.sdk.core.EzoicAds
import com.ezoic.ads.sdk.core.EzoicConfiguration
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class EzoicFlutterSdkPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var appContext: Context
  private lateinit var messenger: BinaryMessenger

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    appContext = binding.applicationContext
    messenger = binding.binaryMessenger
    channel = MethodChannel(messenger, "com.ezoic/ezoic_flutter_sdk")
    channel.setMethodCallHandler(this)
    binding.platformViewRegistry.registerViewFactory(
      "com.ezoic/ezoic_banner_view",
      EzoicBannerViewFactory(messenger)
    )
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "initialize" -> {
        val domain = call.argument<String>("domain")
        if (domain.isNullOrEmpty()) {
          result.error("EzoicAds", "initialize requires a non-empty `domain`.", null); return
        }
        val app = appContext as? Application
        if (app == null) { result.error("EzoicAds", "No Application context available.", null); return }
        val config = EzoicConfiguration(
          domain = domain,
          autoReadConsent = call.argument<Boolean>("autoReadConsent") ?: true,
          subjectToCOPPA = call.argument<Boolean>("subjectToCOPPA") ?: false,
          requestATTBeforeAds = call.argument<Boolean>("requestATTBeforeAds") ?: true,
          debugEnabled = call.argument<Boolean>("debugEnabled") ?: false,
          testMode = call.argument<Boolean>("testMode") ?: false
        )
        EzoicAds.instance.initialize(app, config) { r ->
          r.onSuccess { result.success(null) }
            .onFailure { e -> result.error("EzoicAds", e.message, e.toString()) }
        }
      }
      "setGDPRConsent" -> {
        EzoicAds.instance.setGDPRConsent(
          call.argument<Boolean>("applies") ?: false, call.argument<String>("consentString"))
        result.success(null)
      }
      "setGPPConsent" -> {
        EzoicAds.instance.setGPPConsent(
          call.argument<String>("gppString"), call.argument<String>("sectionIds"))
        result.success(null)
      }
      "setSubjectToCOPPA" -> {
        EzoicAds.instance.setSubjectToCOPPA(call.argument<Boolean>("value") ?: false)
        result.success(null)
      }
      "trackPageview" -> EzoicAds.instance.trackPageview { success -> result.success(success) }
      else -> result.notImplemented()
    }
  }
}
