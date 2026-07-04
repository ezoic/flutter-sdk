package com.ezoic.ezoic_flutter_sdk

import android.content.Context
import android.graphics.Typeface
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.ezoic.ads.sdk.adunits.EzoicNativeAd
import com.ezoic.ads.sdk.adunits.EzoicNativeAdListener
import com.ezoic.ads.sdk.adunits.EzoicNativeAdLoadListener
import com.ezoic.ads.sdk.core.EzoicError
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
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
        val gmaAd = nativeAd.nativeAd ?: run {
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
        val adView = buildTemplate(gmaAd)
        container.removeAllViews()
        container.addView(adView)
        channel.invokeMethod("onLoad", null)
      }

      override fun onNativeAdFailedToLoad(error: EzoicError) {
        if (disposed) return
        channel.invokeMethod("onError", mapOf("message" to error.message, "code" to error.code))
      }
    })
  }

  /**
   * Builds a template [NativeAdView] entirely in code (the plugin ships no
   * `res/` layouts). Layout: a vertical column of a header row (icon +
   * headline/advertiser), a [MediaView], the body text and a call-to-action
   * button. Only the asset views actually present on [gmaAd] are created and
   * registered; [NativeAdView.setNativeAd] is called last, as GMA requires.
   */
  private fun buildTemplate(gmaAd: NativeAd): NativeAdView {
    val adView = NativeAdView(context)

    val root = LinearLayout(context).apply {
      orientation = LinearLayout.VERTICAL
      layoutParams = FrameLayout.LayoutParams(
        FrameLayout.LayoutParams.MATCH_PARENT,
        FrameLayout.LayoutParams.WRAP_CONTENT,
      )
      val pad = dp(8)
      setPadding(pad, pad, pad, pad)
    }

    val headerRow = LinearLayout(context).apply {
      orientation = LinearLayout.HORIZONTAL
      layoutParams = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT,
      )
    }

    var iconView: ImageView? = null
    gmaAd.icon?.drawable?.let { drawable ->
      val iv = ImageView(context).apply {
        layoutParams = LinearLayout.LayoutParams(dp(40), dp(40))
        setImageDrawable(drawable)
      }
      headerRow.addView(iv)
      iconView = iv
    }

    val textColumn = LinearLayout(context).apply {
      orientation = LinearLayout.VERTICAL
      layoutParams = LinearLayout.LayoutParams(
        0,
        LinearLayout.LayoutParams.WRAP_CONTENT,
        1f,
      ).apply { leftMargin = dp(8) }
    }

    var headlineView: TextView? = null
    gmaAd.headline?.let { text ->
      val tv = TextView(context).apply {
        this.text = text
        setTypeface(typeface, Typeface.BOLD)
        textSize = 16f
      }
      textColumn.addView(tv)
      headlineView = tv
    }

    var advertiserView: TextView? = null
    gmaAd.advertiser?.let { text ->
      val tv = TextView(context).apply {
        this.text = text
        textSize = 12f
      }
      textColumn.addView(tv)
      advertiserView = tv
    }

    headerRow.addView(textColumn)
    root.addView(headerRow)

    var mediaView: MediaView? = null
    gmaAd.mediaContent?.let { content ->
      val mv = MediaView(context).apply {
        layoutParams = LinearLayout.LayoutParams(
          LinearLayout.LayoutParams.MATCH_PARENT,
          dp(175),
        ).apply { topMargin = dp(8) }
        mediaContent = content
      }
      root.addView(mv)
      mediaView = mv
    }

    var bodyView: TextView? = null
    gmaAd.body?.let { text ->
      val tv = TextView(context).apply {
        this.text = text
        textSize = 14f
        setPadding(0, dp(8), 0, 0)
      }
      root.addView(tv)
      bodyView = tv
    }

    var callToActionView: Button? = null
    gmaAd.callToAction?.let { text ->
      val btn = Button(context).apply {
        this.text = text
        layoutParams = LinearLayout.LayoutParams(
          LinearLayout.LayoutParams.MATCH_PARENT,
          LinearLayout.LayoutParams.WRAP_CONTENT,
        ).apply { topMargin = dp(8) }
      }
      root.addView(btn)
      callToActionView = btn
    }

    adView.addView(root)
    // Register only the asset views that were populated; a null assignment
    // leaves that asset unregistered.
    adView.headlineView = headlineView
    adView.bodyView = bodyView
    adView.iconView = iconView
    adView.advertiserView = advertiserView
    adView.callToActionView = callToActionView
    adView.mediaView = mediaView
    adView.setNativeAd(gmaAd)
    return adView
  }

  private fun dp(value: Int): Int =
    (value * context.resources.displayMetrics.density).toInt()

  override fun getView(): View = container

  override fun dispose() {
    disposed = true
    // Clear the inbound handler: the messenger keys handlers by channel name
    // for the engine's lifetime and the closure retains this view (and its
    // Context) — view ids are never reused, so an uncleared handler leaks.
    channel.setMethodCallHandler(null)
    ezoicNativeAd?.destroy()
    ezoicNativeAd = null
    container.removeAllViews()
  }
}
