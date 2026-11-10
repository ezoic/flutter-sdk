package com.ezoic.ezoic_flutter_sdk

import com.ezoic.ads.sdk.core.EzoicError
import com.ezoic.ads.sdk.privacy.cmp.CmpError
import com.ezoic.ads.sdk.privacy.cmp.ConsentDecisionType
import com.ezoic.ads.sdk.privacy.cmp.ConsentOutcome

/**
 * The outcome in the wire format the Dart `EzoicConsentOutcome.fromMap`
 * parses. `Failed.error` is an `Exception` from native 1.22.0: an
 * [EzoicError] through `EzoicAds`, a [CmpError] through `EzoicCmp`. Both carry
 * the same codes; anything else gets -1.
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
    "code" to ((error as? EzoicError)?.code ?: (error as? CmpError)?.code ?: -1),
    "message" to (error.message ?: error.toString())
  )
}
