package com.ezoic.ezoic_flutter_cmp_sdk

import com.ezoic.ads.sdk.privacy.cmp.CmpError
import com.ezoic.ads.sdk.privacy.cmp.ConsentDecisionType
import com.ezoic.ads.sdk.privacy.cmp.ConsentOutcome
import kotlin.test.Test
import kotlin.test.assertEquals

class ConsentOutcomeWireTest {
  @Test
  fun failedNotInitializedCarriesItsCode() {
    val map = ConsentOutcome.Failed(CmpError.NotInitialized).toWireMap()
    assertEquals("failed", map["type"])
    assertEquals(1001, map["code"])
    assertEquals(CmpError.NotInitialized.message, map["message"])
  }

  @Test
  fun everyCmpErrorKeepsItsCode() {
    assertEquals(2001, ConsentOutcome.Failed(CmpError.Network(null)).toWireMap()["code"])
    assertEquals(4001, ConsentOutcome.Failed(CmpError.Render("r")).toWireMap()["code"])
    assertEquals(5002, ConsentOutcome.Failed(CmpError.InvalidConsent("i")).toWireMap()["code"])
  }

  @Test
  fun anErrorWithoutACodeFallsBackToMinusOne() {
    val map = ConsentOutcome.Failed(IllegalStateException("boom")).toWireMap()
    assertEquals(mapOf("type" to "failed", "code" to -1, "message" to "boom"), map)
  }

  @Test
  fun anErrorWithoutAMessageUsesItsStringForm() {
    val map = ConsentOutcome.Failed(IllegalStateException()).toWireMap()
    assertEquals("java.lang.IllegalStateException", map["message"])
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
