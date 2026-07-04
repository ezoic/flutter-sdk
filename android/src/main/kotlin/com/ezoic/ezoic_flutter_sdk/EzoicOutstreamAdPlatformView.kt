package com.ezoic.ezoic_flutter_sdk

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.FrameLayout
import com.ezoic.ads.sdk.adunits.EzoicOutstreamAdView
import com.ezoic.ads.sdk.adunits.EzoicOutstreamAdViewListener
import com.ezoic.ads.sdk.core.EzoicError
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class EzoicOutstreamAdViewFactory(private val messenger: BinaryMessenger) :
  PlatformViewFactory(StandardMessageCodec.INSTANCE) {
  override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
    @Suppress("UNCHECKED_CAST")
    val params = (args as? Map<String, Any?>) ?: emptyMap()
    return EzoicOutstreamAdPlatformView(context, viewId, params, messenger)
  }
}

class EzoicOutstreamAdPlatformView(
  private val context: Context,
  viewId: Int,
  params: Map<String, Any?>,
  messenger: BinaryMessenger,
) : PlatformView {

  private val container = FrameLayout(context)
  private val channel = MethodChannel(messenger, "com.ezoic/ezoic_outstream_ad_view_$viewId")
  private val adUnitId = (params["adUnitIdentifier"] as? String)?.toIntOrNull() ?: 0
  private val mainHandler = Handler(Looper.getMainLooper())
  private var outstreamView: EzoicOutstreamAdView? = null
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
        else -> result.notImplemented()
      }
    }
  }

  private fun startLoad() {
    // A second "load" is a no-op success; the guard survives across calls.
    if (loadStarted) return
    loadStarted = true

    // Unlike the native-ad unit there is no separate ad object — the VIEW is
    // the ad. Add it to the container before loading so it renders in place
    // when the SDK fills it.
    val view = EzoicOutstreamAdView(context, adUnitId)
    outstreamView = view
    container.addView(view)

    // The listener must be assigned BEFORE loadAd(): native loadAd() fails
    // synchronously when the SDK is uninitialized, so onError must already be
    // wired or the failure is dropped.
    view.listener = object : EzoicOutstreamAdViewListener {
      override fun onOutstreamLoaded(adView: EzoicOutstreamAdView) {
        post("onLoad", null)
      }

      override fun onOutstreamLoadFailed(adView: EzoicOutstreamAdView, error: EzoicError) {
        post("onError", mapOf("message" to error.message, "code" to error.code))
      }

      override fun onOutstreamImpression(adView: EzoicOutstreamAdView) {
        post("onImpression", null)
      }

      override fun onOutstreamClicked(adView: EzoicOutstreamAdView) {
        post("onClick", null)
      }

      override fun onOutstreamOpened(adView: EzoicOutstreamAdView) {
        post("onOpen", null)
      }

      override fun onOutstreamClosed(adView: EzoicOutstreamAdView) {
        post("onClose", null)
      }
    }
    view.loadAd()
  }

  /**
   * Posts an event to Dart on the main thread, guarded by [disposed] so a late
   * SDK callback after dispose never touches the cleared channel.
   */
  private fun post(method: String, args: Any?) {
    mainHandler.post {
      if (disposed) return@post
      channel.invokeMethod(method, args)
    }
  }

  override fun getView(): View = container

  override fun dispose() {
    disposed = true
    // Clear the inbound handler: the messenger keys handlers by channel name
    // for the engine's lifetime and the closure retains this view (and its
    // Context) — view ids are never reused, so an uncleared handler leaks.
    channel.setMethodCallHandler(null)
    outstreamView?.destroy()
    outstreamView = null
    container.removeAllViews()
  }
}
