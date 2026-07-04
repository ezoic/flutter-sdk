package com.ezoic.ezoic_flutter_sdk

import android.app.Activity
import android.app.Application
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.ezoic.ads.sdk.adunits.EzoicInstreamAd
import com.ezoic.ads.sdk.adunits.EzoicInstreamAdListener
import com.ezoic.ads.sdk.adunits.EzoicInterstitialAd
import com.ezoic.ads.sdk.adunits.EzoicInterstitialAdListenerAdapter
import com.ezoic.ads.sdk.adunits.EzoicReward
import com.ezoic.ads.sdk.adunits.EzoicRewardedAd
import com.ezoic.ads.sdk.adunits.EzoicRewardedAdListenerAdapter
import com.ezoic.ads.sdk.core.EzoicAds
import com.ezoic.ads.sdk.core.EzoicConfiguration
import com.ezoic.ads.sdk.core.EzoicError
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class EzoicFlutterSdkPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var appContext: Context
  private lateinit var messenger: BinaryMessenger
  private val mainHandler = Handler(Looper.getMainLooper())

  /** The host Activity, available while the plugin is attached to one. */
  private var activity: Activity? = null

  /** Loaded rewarded ads awaiting `show`, keyed by ad unit id. */
  private val rewardedAds = HashMap<String, EzoicRewardedAd>()

  /** Per-ad event channels used to surface lifecycle callbacks to Dart. */
  private val rewardedChannels = HashMap<String, MethodChannel>()

  /** In-flight `show` calls, keyed by ad unit id. */
  private val pendingShows = HashMap<String, RewardShow>()

  private class RewardShow(val result: MethodChannel.Result) {
    var settled = false
    var reward: EzoicReward? = null
  }

  /** Loaded interstitial ads awaiting `show`, keyed by ad unit id. */
  private val interstitialAds = HashMap<String, EzoicInterstitialAd>()

  /** Per-ad event channels used to surface interstitial callbacks to Dart. */
  private val interstitialChannels = HashMap<String, MethodChannel>()

  /** In-flight interstitial `show` calls, keyed by ad unit id. */
  private val pendingInterstitialShows = HashMap<String, InterstitialShow>()

  private class InterstitialShow(val result: MethodChannel.Result) {
    var settled = false
  }

  /** Ad unit ids with an in-flight rewarded `load`. */
  private val loadingRewarded = HashSet<String>()

  /** Ad unit ids with an in-flight interstitial `load`. */
  private val loadingInterstitial = HashSet<String>()

  /** Live instream controllers, keyed by ad unit id. Multi-use — reused across loads. */
  private val instreamAds = HashMap<Int, EzoicInstreamAd>()

  /**
   * In-flight instream `load` calls, keyed by ad unit id. The native load
   * silently no-ops while loading, which would hang the Dart future, so an
   * overlapping load is rejected here instead. Also lets `destroyInstreamAd`
   * settle a pending load's result: the native SDKs ignore callbacks for a
   * destroyed ad, so without this the Dart `load()` future would hang forever.
   */
  private val loadingInstream = HashMap<Int, InstreamLoad>()

  private class InstreamLoad(val result: MethodChannel.Result) {
    var settled = false
  }

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    appContext = binding.applicationContext
    messenger = binding.binaryMessenger
    channel = MethodChannel(messenger, "com.ezoic/ezoic_flutter_sdk")
    channel.setMethodCallHandler(this)
    binding.platformViewRegistry.registerViewFactory(
      "com.ezoic/ezoic_banner_view",
      EzoicBannerViewFactory(messenger)
    )
    binding.platformViewRegistry.registerViewFactory(
      "com.ezoic/ezoic_native_ad_view",
      EzoicNativeAdViewFactory(messenger)
    )
    binding.platformViewRegistry.registerViewFactory(
      "com.ezoic/ezoic_outstream_ad_view",
      EzoicOutstreamAdViewFactory(messenger)
    )
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    rewardedChannels.values.forEach { it.setMethodCallHandler(null) }
    rewardedChannels.clear()
    rewardedAds.clear()
    pendingShows.clear()
    loadingRewarded.clear()
    interstitialChannels.values.forEach { it.setMethodCallHandler(null) }
    interstitialChannels.clear()
    interstitialAds.clear()
    pendingInterstitialShows.clear()
    loadingInterstitial.clear()
    loadingInstream.values.forEach { holder ->
      if (!holder.settled) {
        holder.settled = true
        holder.result.error("EzoicAds", "Engine detached while an instream ad was loading", null)
      }
    }
    instreamAds.values.forEach { it.destroy() }
    instreamAds.clear()
    loadingInstream.clear()
  }

  // ActivityAware — capture the Activity so rewarded ads can be presented.

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
      "loadRewardedAd" -> handleLoadRewardedAd(call, result)
      "showRewardedAd" -> handleShowRewardedAd(call, result)
      "loadInterstitialAd" -> handleLoadInterstitialAd(call, result)
      "showInterstitialAd" -> handleShowInterstitialAd(call, result)
      "loadInstreamAd" -> handleLoadInstreamAd(call, result)
      "getInstreamNextAdTagUrl" -> handleGetInstreamNextAdTagUrl(call, result)
      "reportInstreamImpression" -> handleReportInstreamImpression(call, result)
      "destroyInstreamAd" -> handleDestroyInstreamAd(call, result)
      else -> result.notImplemented()
    }
  }

  private fun handleLoadRewardedAd(call: MethodCall, result: MethodChannel.Result) {
    val adUnitIdentifier = call.argument<String>("adUnitIdentifier")
    val id = adUnitIdentifier?.toIntOrNull()
    if (adUnitIdentifier == null || id == null) {
      result.error("EzoicAds", "Invalid adUnitIdentifier: $adUnitIdentifier", null); return
    }
    if (rewardedAds.containsKey(adUnitIdentifier) || loadingRewarded.contains(adUnitIdentifier)) {
      result.error(
        "EzoicAds", "An ad is already loaded/loading for ad unit $adUnitIdentifier", null); return
    }
    loadingRewarded.add(adUnitIdentifier)
    EzoicRewardedAd.load(appContext, id) { r ->
      loadingRewarded.remove(adUnitIdentifier)
      r.onSuccess { ad ->
        ad.listener = makeListener(adUnitIdentifier)
        rewardedAds[adUnitIdentifier] = ad
        rewardedChannels.getOrPut(adUnitIdentifier) {
          MethodChannel(messenger, "com.ezoic/ezoic_rewarded_ad_$adUnitIdentifier")
        }
        result.success(null)
      }.onFailure { e ->
        result.error("EzoicAds", e.message ?: "Rewarded ad failed to load", e.toString())
      }
    }
  }

  private fun handleShowRewardedAd(call: MethodCall, result: MethodChannel.Result) {
    val adUnitIdentifier = call.argument<String>("adUnitIdentifier")
    val ad = if (adUnitIdentifier != null) rewardedAds[adUnitIdentifier] else null
    if (adUnitIdentifier == null || ad == null) {
      result.error("EzoicAds", "Rewarded ad not loaded for $adUnitIdentifier", null); return
    }
    if (pendingShows.containsKey(adUnitIdentifier)) {
      result.error(
        "EzoicAds", "A show is already in progress for ad unit $adUnitIdentifier", null); return
    }
    val currentActivity = activity
    if (currentActivity == null) {
      result.error("EzoicAds", "No current Activity to present the rewarded ad", null); return
    }

    val show = RewardShow(result)
    pendingShows[adUnitIdentifier] = show
    currentActivity.runOnUiThread {
      ad.show(currentActivity) { reward -> show.reward = reward }
    }
  }

  private fun makeListener(adUnitIdentifier: String) =
    object : EzoicRewardedAdListenerAdapter() {
      override fun onRewardedAdShown(rewardedAd: EzoicRewardedAd) {
        emit(adUnitIdentifier, "onShown")
      }

      override fun onRewardedAdFailedToShow(rewardedAd: EzoicRewardedAd, error: EzoicError) {
        emit(adUnitIdentifier, "onFailedToShow", mapOf("message" to error.message, "code" to error.code))
        cleanup(adUnitIdentifier)
        val pending = pendingShows.remove(adUnitIdentifier)
        if (pending != null && !pending.settled) {
          pending.settled = true
          pending.result.error("EzoicAds", error.message, null)
        }
      }

      override fun onRewardedAdImpression(rewardedAd: EzoicRewardedAd) {
        emit(adUnitIdentifier, "onImpression")
      }

      override fun onRewardedAdClicked(rewardedAd: EzoicRewardedAd) {
        emit(adUnitIdentifier, "onClicked")
      }

      override fun onUserEarnedReward(rewardedAd: EzoicRewardedAd, reward: EzoicReward) {
        emit(adUnitIdentifier, "onUserEarnedReward", mapOf("type" to reward.type, "amount" to reward.amount))
        pendingShows[adUnitIdentifier]?.reward = reward
      }

      override fun onRewardedAdDismissed(rewardedAd: EzoicRewardedAd) {
        emit(adUnitIdentifier, "onDismissed")
        val pending = pendingShows.remove(adUnitIdentifier)
        cleanup(adUnitIdentifier)
        if (pending != null && !pending.settled) {
          pending.settled = true
          val reward = pending.reward
          pending.result.success(
            mapOf(
              "earned" to (reward != null),
              "type" to (reward?.type ?: ""),
              "amount" to (reward?.amount ?: 0)
            )
          )
        }
      }
    }

  private fun cleanup(adUnitIdentifier: String) {
    rewardedAds.remove(adUnitIdentifier)
  }

  private fun emit(adUnitIdentifier: String, method: String, args: Any? = null) {
    val channel = rewardedChannels[adUnitIdentifier] ?: return
    mainHandler.post { channel.invokeMethod(method, args) }
  }

  private fun handleLoadInterstitialAd(call: MethodCall, result: MethodChannel.Result) {
    val adUnitIdentifier = call.argument<String>("adUnitIdentifier")
    val id = adUnitIdentifier?.toIntOrNull()
    if (adUnitIdentifier == null || id == null) {
      result.error("EzoicAds", "Invalid adUnitIdentifier: $adUnitIdentifier", null); return
    }
    if (interstitialAds.containsKey(adUnitIdentifier) || loadingInterstitial.contains(adUnitIdentifier)) {
      result.error(
        "EzoicAds", "An ad is already loaded/loading for ad unit $adUnitIdentifier", null); return
    }
    loadingInterstitial.add(adUnitIdentifier)
    EzoicInterstitialAd.load(appContext, id) { r ->
      loadingInterstitial.remove(adUnitIdentifier)
      r.onSuccess { ad ->
        ad.listener = makeInterstitialListener(adUnitIdentifier)
        interstitialAds[adUnitIdentifier] = ad
        interstitialChannels.getOrPut(adUnitIdentifier) {
          MethodChannel(messenger, "com.ezoic/ezoic_interstitial_ad_$adUnitIdentifier")
        }
        result.success(null)
      }.onFailure { e ->
        result.error("EzoicAds", e.message ?: "Interstitial ad failed to load", e.toString())
      }
    }
  }

  private fun handleShowInterstitialAd(call: MethodCall, result: MethodChannel.Result) {
    val adUnitIdentifier = call.argument<String>("adUnitIdentifier")
    val ad = if (adUnitIdentifier != null) interstitialAds[adUnitIdentifier] else null
    if (adUnitIdentifier == null || ad == null) {
      result.error("EzoicAds", "Interstitial ad not loaded for $adUnitIdentifier", null); return
    }
    if (pendingInterstitialShows.containsKey(adUnitIdentifier)) {
      result.error(
        "EzoicAds", "A show is already in progress for ad unit $adUnitIdentifier", null); return
    }
    val currentActivity = activity
    if (currentActivity == null) {
      result.error("EzoicAds", "No current Activity to present the interstitial ad", null); return
    }

    pendingInterstitialShows[adUnitIdentifier] = InterstitialShow(result)
    // Native show(activity) has no completion lambda, so the show promise is
    // settled from the listener (dismiss = resolve, failed-to-show = reject).
    currentActivity.runOnUiThread {
      ad.show(currentActivity)
    }
  }

  private fun makeInterstitialListener(adUnitIdentifier: String) =
    object : EzoicInterstitialAdListenerAdapter() {
      override fun onInterstitialAdShown(interstitialAd: EzoicInterstitialAd) {
        emitInterstitial(adUnitIdentifier, "onShown")
      }

      override fun onInterstitialAdFailedToShow(interstitialAd: EzoicInterstitialAd, error: EzoicError) {
        emitInterstitial(adUnitIdentifier, "onFailedToShow", mapOf("message" to error.message, "code" to error.code))
        cleanupInterstitial(adUnitIdentifier)
        val pending = pendingInterstitialShows.remove(adUnitIdentifier)
        if (pending != null && !pending.settled) {
          pending.settled = true
          pending.result.error("EzoicAds", error.message, error.code)
        }
      }

      override fun onInterstitialAdImpression(interstitialAd: EzoicInterstitialAd) {
        emitInterstitial(adUnitIdentifier, "onImpression")
      }

      override fun onInterstitialAdClicked(interstitialAd: EzoicInterstitialAd) {
        emitInterstitial(adUnitIdentifier, "onClicked")
      }

      override fun onInterstitialAdDismissed(interstitialAd: EzoicInterstitialAd) {
        emitInterstitial(adUnitIdentifier, "onDismissed")
        val pending = pendingInterstitialShows.remove(adUnitIdentifier)
        cleanupInterstitial(adUnitIdentifier)
        if (pending != null && !pending.settled) {
          pending.settled = true
          pending.result.success(null)
        }
      }
    }

  private fun cleanupInterstitial(adUnitIdentifier: String) {
    interstitialAds.remove(adUnitIdentifier)
  }

  private fun emitInterstitial(adUnitIdentifier: String, method: String, args: Any? = null) {
    val channel = interstitialChannels[adUnitIdentifier] ?: return
    mainHandler.post { channel.invokeMethod(method, args) }
  }

  private fun handleLoadInstreamAd(call: MethodCall, result: MethodChannel.Result) {
    val adUnitIdentifier = call.argument<String>("adUnitIdentifier")
    val id = adUnitIdentifier?.toIntOrNull()
    if (adUnitIdentifier == null || id == null) {
      result.error("EzoicAds", "Invalid adUnitIdentifier: $adUnitIdentifier", null); return
    }
    // Reject overlapping loads for this ad unit: the native load silently
    // no-ops while loading (both a second load on the same instance and a load
    // on a fresh Dart instance sharing the id), which would hang the future.
    if (loadingInstream.containsKey(id)) {
      result.error(
        "EzoicAds", "An instream ad is already loading for ad unit $adUnitIdentifier", null); return
    }
    val contentUrl = call.argument<String>("contentUrl")

    // Create-or-reuse: instream is multi-use, so a repeat load on the same id
    // reuses the existing native controller (preserving its tag state).
    val ad = instreamAds.getOrPut(id) { EzoicInstreamAd(id) }

    val holder = InstreamLoad(result)
    loadingInstream[id] = holder
    ad.load(appContext, contentUrl, object : EzoicInstreamAdListener {
      override fun onAdTagReady(adTagUrl: String) {
        mainHandler.post {
          if (!holder.settled) {
            holder.settled = true
            loadingInstream.remove(id)
            holder.result.success(adTagUrl)
          }
        }
      }

      override fun onAdFailedToLoad(error: EzoicError) {
        mainHandler.post {
          if (!holder.settled) {
            holder.settled = true
            loadingInstream.remove(id)
            holder.result.error("EzoicAds", error.message, error.code)
          }
        }
      }
    })
  }

  private fun handleGetInstreamNextAdTagUrl(call: MethodCall, result: MethodChannel.Result) {
    val id = call.argument<String>("adUnitIdentifier")?.toIntOrNull()
    if (id == null) {
      result.error("EzoicAds", "Invalid adUnitIdentifier", null); return
    }
    result.success(instreamAds[id]?.getNextAdTagUrl())
  }

  private fun handleReportInstreamImpression(call: MethodCall, result: MethodChannel.Result) {
    val id = call.argument<String>("adUnitIdentifier")?.toIntOrNull()
    if (id == null) {
      result.error("EzoicAds", "Invalid adUnitIdentifier", null); return
    }
    // revenueUsd may arrive as an Int over the codec when whole; take it as a
    // Number and coerce to the native Double? the SDK expects.
    val revenueUsd = call.argument<Number>("revenueUsd")?.toDouble()
    instreamAds[id]?.reportImpression(revenueUsd)
    result.success(null)
  }

  private fun handleDestroyInstreamAd(call: MethodCall, result: MethodChannel.Result) {
    val id = call.argument<String>("adUnitIdentifier")?.toIntOrNull()
    if (id == null) {
      result.error("EzoicAds", "Invalid adUnitIdentifier", null); return
    }
    // The native SDKs ignore load callbacks once an ad is destroyed, so a
    // pending load's Flutter result must be settled here or it hangs forever.
    val pending = loadingInstream.remove(id)
    if (pending != null && !pending.settled) {
      pending.settled = true
      pending.result.error("EzoicAds", "Instream ad was destroyed while loading", null)
    }
    instreamAds.remove(id)?.destroy()
    result.success(null)
  }
}
