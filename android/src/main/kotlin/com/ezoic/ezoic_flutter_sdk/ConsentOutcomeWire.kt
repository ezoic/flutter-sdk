package com.ezoic.ezoic_flutter_sdk

import com.ezoic.ads.sdk.core.EzoicError
import com.ezoic.ads.sdk.privacy.cmp.ConsentDecisionType
import com.ezoic.ads.sdk.privacy.cmp.ConsentOutcome

/**
 * The outcome in the wire format the Dart `EzoicConsentOutcome.fromMap`
 * parses. `EzoicAds` reports `Failed` with an [EzoicError], which carries the
 * code; anything else gets -1. Not `CmpError`: that class is in ezoic-cmp-sdk,
 * which an app may exclude (see the README), and this plugin must not touch it.
 */
internal fun ConsentOutcome.toWireMap(): Map<String, Any> = when (this) {
  ConsentOutcome.NotRequired -> mapOf("type" to "notRequired")
  ConsentOutcome.AlreadyDecided -> mapOf("type" to "alreadyDecided")
  is ConsentOutcome.Decided -> mapOf(
    "type" to "decided",
    "decision" to when (decision) {
      ConsentDecisionType.ACCEPT_ALL -> "acceptAll"
      ConsentDecisionType.REJECT_ALL -> "rejectAll"
      ConsentDecisionType.CUSTOM -> "custom"
    }
  )
  ConsentOutcome.Dismissed -> mapOf("type" to "dismissed")
  ConsentOutcome.AlreadyPresenting -> mapOf("type" to "alreadyPresenting")
  is ConsentOutcome.Failed -> mapOf(
    "type" to "failed",
    "code" to ((error as? EzoicError)?.code ?: -1),
    "message" to (error.message ?: error.toString())
  )
}
