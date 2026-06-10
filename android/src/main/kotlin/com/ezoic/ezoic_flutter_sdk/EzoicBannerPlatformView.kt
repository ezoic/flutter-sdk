package com.ezoic.ezoic_flutter_sdk

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import com.ezoic.ads.sdk.adunits.EzoicBannerView
import com.ezoic.ads.sdk.adunits.EzoicBannerViewListener
import com.ezoic.ads.sdk.core.EzoicError
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class EzoicBannerViewFactory(private val messenger: BinaryMessenger) :
  PlatformViewFactory(StandardMessageCodec.INSTANCE) {
  override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
    @Suppress("UNCHECKED_CAST")
    val params = (args as? Map<String, Any?>) ?: emptyMap()
    return EzoicBannerPlatformView(context, viewId, params, messenger)
  }
}

class EzoicBannerPlatformView(
  context: Context,
  viewId: Int,
  params: Map<String, Any?>,
  messenger: BinaryMessenger,
) : PlatformView {

  private val container = FrameLayout(context)
  private val channel = MethodChannel(messenger, "com.ezoic/ezoic_banner_view_$viewId")

  init {
    val adUnitId = (params["adUnitIdentifier"] as? String)?.toIntOrNull() ?: 0
    val sizes = (params["size"] as? String ?: "").split(",").map { it.trim() }.filter { it.isNotEmpty() }
    val banner = EzoicBannerView(context, adUnitId)
    banner.listener = object : EzoicBannerViewListener {
      override fun onBannerLoaded(b: EzoicBannerView) { channel.invokeMethod("onLoad", null) }
      override fun onBannerLoadFailed(b: EzoicBannerView, error: EzoicError) {
        channel.invokeMethod("onError", mapOf("message" to error.message, "code" to error.code))
      }
      override fun onBannerImpression(b: EzoicBannerView) { channel.invokeMethod("onImpression", null) }
      override fun onBannerClicked(b: EzoicBannerView) { channel.invokeMethod("onClick", null) }
      override fun onBannerOpened(b: EzoicBannerView) { channel.invokeMethod("onOpen", null) }
      override fun onBannerClosed(b: EzoicBannerView) { channel.invokeMethod("onClose", null) }
    }
    container.addView(banner)
    if (sizes.isEmpty()) banner.loadAd() else banner.loadAd(sizes)
  }

  override fun getView(): View = container
  override fun dispose() {}
}
