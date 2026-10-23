package com.ezoic.ezoic_flutter_sdk

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import com.ezoic.ads.sdk.adunits.EzoicNativeAd
import com.ezoic.ads.sdk.adunits.EzoicNativeAdListener
import com.ezoic.ads.sdk.adunits.EzoicNativeAdLoadListener
import com.ezoic.ads.sdk.adunits.EzoicNativeAdStyle
import com.ezoic.ads.sdk.adunits.EzoicNativeAdTemplateView
import com.ezoic.ads.sdk.core.EzoicError
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class EzoicNativeAdViewFactory(private val messenger: BinaryMessenger) :
  PlatformViewFactory(StandardMessageCodec.INSTANCE) {
  override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
    @Suppress("UNCHECKED_CAST")
    val params = (args as? Map<String, Any?>) ?: emptyMap()
    return EzoicNativeAdPlatformView(context, viewId, params, messenger)
  }
}

class EzoicNativeAdPlatformView(
  private val context: Context,
  viewId: Int,
  params: Map<String, Any?>,
  messenger: BinaryMessenger,
) : PlatformView {

  private val container = FrameLayout(context)
  private val channel = MethodChannel(messenger, "com.ezoic/ezoic_native_ad_view_$viewId")
  private val adUnitId = (params["adUnitIdentifier"] as? String)?.toIntOrNull() ?: 0
  private var ezoicNativeAd: EzoicNativeAd? = null
  private var adStyle = styleFrom(params["adStyle"])
  private var templateView: EzoicNativeAdTemplateView? = null
  private var loadStarted = false
  private var disposed = false

  init {
    // The load is triggered by an explicit "load" call from Dart rather than
    // here, so the Dart-side handler is attached before the native SDK can
    // fail synchronously (e.g. EzoicError.NotInitialized) and drop onError.
    channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "load" -> {
          startLoad()
          result.success(null)
        }
        "setStyle" -> {
          adStyle = styleFrom(call.arguments)
          templateView?.style = adStyle
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }
  }

  private fun startLoad() {
    // A second "load" is a no-op success; the guard survives across calls.
    if (loadStarted) return
    loadStarted = true
    EzoicNativeAd.load(context, adUnitId, object : EzoicNativeAdLoadListener {
      override fun onNativeAdLoaded(nativeAd: EzoicNativeAd) {
        // dispose() may run mid-load; the SDK callback and dispose both arrive
        // on the main thread, so this check is race-free. Destroy the ad the
        // SDK just handed us to avoid leaking it (there is no deinit).
        if (disposed) {
          nativeAd.destroy()
          return
        }
        ezoicNativeAd = nativeAd
        if (nativeAd.nativeAd == null) {
          channel.invokeMethod(
            "onError", mapOf("message" to "Native ad loaded without content", "code" to 0))
          return
        }
        // Attach the lifecycle listener before the rendered NativeAdView
        // registers — the impression fires as soon as the view is displayed.
        nativeAd.listener = object : EzoicNativeAdListener {
          override fun onNativeAdImpression(nativeAd: EzoicNativeAd) {
            channel.invokeMethod("onImpression", null)
          }
          override fun onNativeAdClicked(nativeAd: EzoicNativeAd) {
            channel.invokeMethod("onClick", null)
          }
          override fun onNativeAdOpened(nativeAd: EzoicNativeAd) {
            channel.invokeMethod("onOpen", null)
          }
          override fun onNativeAdClosed(nativeAd: EzoicNativeAd) {
            channel.invokeMethod("onClose", null)
          }
        }
        // The SDK template renders the ad and registers it for viewability.
        val template = EzoicNativeAdTemplateView(context)
        template.style = adStyle
        template.nativeAd = nativeAd
        container.removeAllViews()
        container.addView(template)
        templateView = template
        channel.invokeMethod("onLoad", null)
      }

      override fun onNativeAdFailedToLoad(error: EzoicError) {
        if (disposed) return
        channel.invokeMethod("onError", mapOf("message" to error.message, "code" to error.code))
      }
    })
  }

  @Suppress("UNCHECKED_CAST")
  private fun styleFrom(value: Any?): EzoicNativeAdStyle =
    EzoicNativeAdStyle.fromMap(value as? Map<String, Any?>)

  override fun getView(): View = container

  override fun dispose() {
    disposed = true
    // Clear the inbound handler: the messenger keys handlers by channel name
    // for the engine's lifetime and the closure retains this view (and its
    // Context) — view ids are never reused, so an uncleared handler leaks.
    channel.setMethodCallHandler(null)
    ezoicNativeAd?.destroy()
    ezoicNativeAd = null
    templateView = null
    container.removeAllViews()
  }
}
