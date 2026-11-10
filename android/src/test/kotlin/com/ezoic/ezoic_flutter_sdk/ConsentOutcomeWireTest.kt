package com.ezoic.ezoic_flutter_sdk

import com.ezoic.ads.sdk.core.EzoicError
import com.ezoic.ads.sdk.privacy.cmp.CmpError
import com.ezoic.ads.sdk.privacy.cmp.ConsentDecisionType
import com.ezoic.ads.sdk.privacy.cmp.ConsentOutcome
import kotlin.test.Test
import kotlin.test.assertEquals

class ConsentOutcomeWireTest {
  @Test
  fun failedEzoicErrorCarriesItsCode() {
    val map = ConsentOutcome.Failed(EzoicError.NotInitialized).toWireMap()
    assertEquals("failed", map["type"])
    assertEquals(1001, map["code"])
    assertEquals(EzoicError.NotInitialized.message, map["message"])
  }

  @Test
  fun failedCmpErrorCarriesItsCode() {
    assertEquals(5002, ConsentOutcome.Failed(CmpError.InvalidConsent("x")).toWireMap()["code"])
    assertEquals(2001, ConsentOutcome.Failed(CmpError.Network(null)).toWireMap()["code"])
  }

  @Test
  fun anErrorWithoutACodeFallsBackToMinusOne() {
    assertEquals(
      mapOf("type" to "failed", "code" to -1, "message" to "boom"),
      ConsentOutcome.Failed(RuntimeException("boom")).toWireMap()
    )
  }

  @Test
  fun mapsEveryOtherOutcome() {
    assertEquals(mapOf("type" to "notRequired"), ConsentOutcome.NotRequired.toWireMap())
    assertEquals(mapOf("type" to "alreadyDecided"), ConsentOutcome.AlreadyDecided.toWireMap())
    assertEquals(mapOf("type" to "dismissed"), ConsentOutcome.Dismissed.toWireMap())
    assertEquals(mapOf("type" to "alreadyPresenting"), ConsentOutcome.AlreadyPresenting.toWireMap())
    assertEquals(
      listOf("acceptAll", "rejectAll", "custom"),
      ConsentDecisionType.entries.map { ConsentOutcome.Decided(it).toWireMap()["decision"] }
    )
  }
}
