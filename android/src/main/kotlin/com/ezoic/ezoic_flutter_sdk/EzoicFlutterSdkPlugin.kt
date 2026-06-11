package com.ezoic.ezoic_flutter_sdk

import android.app.Activity
import android.app.Application
import android.content.Context
import android.os.Handler
import android.os.Looper
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
    rewardedChannels.values.forEach { it.setMethodCallHandler(null) }
    rewardedChannels.clear()
    rewardedAds.clear()
    pendingShows.clear()
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
      else -> result.notImplemented()
    }
  }

  private fun handleLoadRewardedAd(call: MethodCall, result: MethodChannel.Result) {
    val adUnitIdentifier = call.argument<String>("adUnitIdentifier")
    val id = adUnitIdentifier?.toIntOrNull()
    if (adUnitIdentifier == null || id == null) {
      result.error("EzoicAds", "Invalid adUnitIdentifier: $adUnitIdentifier", null); return
    }
    EzoicRewardedAd.load(appContext, id) { r ->
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
}
