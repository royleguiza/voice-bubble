package com.royleguiza.voicebubblestt

import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.android.controller.ServiceController
import org.robolectric.annotation.Config

/**
 * C-05: exclusion mutua del microfono entre teclado y widget. Ambos
 * compiten por el claim atomico de [BackgroundWork] y solo el ganador llega
 * al AudioRecord.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class MicrophoneClaimTest {

    private val widgetTokens = mutableListOf<Long>()
    private var widgetController: ServiceController<WidgetDictationService>? = null
    private lateinit var widget: WidgetDictationService

    @Before
    fun createWidgetService() {
        val controller = Robolectric.buildService(WidgetDictationService::class.java).create()
        widgetController = controller
        widget = controller.get()
    }

    @After
    fun releaseEveryClaim() {
        val controller = widgetController ?: return
        controller.get().releaseMicrophone()
        widgetTokens.forEach { token ->
            BackgroundWork.releaseMicrophone(token)
        }
        widgetTokens.clear()
        controller.destroy()
    }

    private fun claimForWidget(): Long {
        val claim = widget.claimMicrophoneForDictation()
        if (claim != 0L) widgetTokens.add(claim)
        return claim
    }

    @Test
    fun concurrentClaimsHaveExactlyOneWinner() {
        val threads = 8
        val ready = CountDownLatch(threads)
        val go = CountDownLatch(1)
        val winners = AtomicInteger(0)
        val winnerToken = AtomicLong(0L)
        val pool = Executors.newFixedThreadPool(threads)
        try {
            repeat(threads) {
                pool.execute {
                    ready.countDown()
                    go.await(5, TimeUnit.SECONDS)
                    val claim = BackgroundWork.tryClaimMicrophone()
                    if (claim != 0L) {
                        winners.incrementAndGet()
                        winnerToken.set(claim)
                    }
                }
            }
            assertTrue(ready.await(5, TimeUnit.SECONDS))
            go.countDown()
            pool.shutdown()
            assertTrue(pool.awaitTermination(10, TimeUnit.SECONDS))
        } finally {
            pool.shutdownNow()
        }

        assertEquals(1, winners.get())
        assertTrue(winnerToken.get() != 0L)
        assertTrue(BackgroundWork.isMicrophoneClaimed())
        assertTrue(BackgroundWork.isMicrophoneClaimedBy(winnerToken.get()))
        BackgroundWork.releaseMicrophone(winnerToken.get())
    }

    @Test
    fun staleTokenDoesNotFreeTheCurrentClaim() {
        val primero = BackgroundWork.tryClaimMicrophone()
        assertTrue(primero != 0L)
        BackgroundWork.releaseMicrophone(primero)

        val segundo = BackgroundWork.tryClaimMicrophone()
        assertTrue(segundo != 0L)
        assertTrue(primero != segundo)

        BackgroundWork.releaseMicrophone(primero)
        assertTrue(BackgroundWork.isMicrophoneClaimed())
        assertTrue(BackgroundWork.isMicrophoneClaimedBy(segundo))
        assertFalse(BackgroundWork.isMicrophoneClaimedBy(primero))

        BackgroundWork.releaseMicrophone(segundo)
        assertFalse(BackgroundWork.isMicrophoneClaimed())
    }

    @Test
    fun releaseIsIdempotentAndIgnoresEmptyTokens() {
        val claim = BackgroundWork.tryClaimMicrophone()
        assertTrue(claim != 0L)

        assertTrue(BackgroundWork.releaseMicrophone(claim))
        assertFalse(BackgroundWork.releaseMicrophone(claim))
        assertFalse(BackgroundWork.releaseMicrophone(0L))
        assertFalse(BackgroundWork.isMicrophoneClaimed())

        val siguiente = BackgroundWork.tryClaimMicrophone()
        assertTrue(siguiente != 0L)
        assertTrue(BackgroundWork.releaseMicrophone(siguiente))
        assertFalse(BackgroundWork.isMicrophoneClaimed())
    }

    @Test
    fun duplicateReleaseDuringTakeoverNeverStealsTheNewOwner() {
        val primero = BackgroundWork.tryClaimMicrophone()
        assertTrue(primero != 0L)
        val go = CountDownLatch(1)
        val pool = Executors.newFixedThreadPool(2)
        val nuevo = AtomicLong(0L)
        try {
            pool.execute {
                go.await(5, TimeUnit.SECONDS)
                BackgroundWork.releaseMicrophone(primero)
                BackgroundWork.releaseMicrophone(primero)
            }
            pool.execute {
                go.await(5, TimeUnit.SECONDS)
                nuevo.set(BackgroundWork.tryClaimMicrophone())
            }
            go.countDown()
            pool.shutdown()
            assertTrue(pool.awaitTermination(10, TimeUnit.SECONDS))
        } finally {
            pool.shutdownNow()
        }

        val ganador = nuevo.get()
        if (ganador == 0L) {
            assertFalse(BackgroundWork.isMicrophoneClaimed())
        } else {
            assertTrue(BackgroundWork.isMicrophoneClaimed())
            assertTrue(BackgroundWork.isMicrophoneClaimedBy(ganador))
            assertFalse(BackgroundWork.releaseMicrophone(primero))
            assertTrue(BackgroundWork.isMicrophoneClaimedBy(ganador))
            assertTrue(BackgroundWork.releaseMicrophone(ganador))
        }
        assertFalse(BackgroundWork.isMicrophoneClaimed())
    }

    @Test
    fun concurrentClaimAndDuplicateReleaseNeverOverlapTwoOwners() {
        val holders = AtomicInteger(0)
        val maxHolders = AtomicInteger(0)
        val fallos = ConcurrentLinkedQueue<String>()
        val pool = Executors.newFixedThreadPool(4)
        try {
            repeat(4) {
                pool.execute {
                    for (vuelta in 0 until 3000) {
                        val claim = try {
                            BackgroundWork.tryClaimMicrophone()
                        } catch (e: Throwable) {
                            fallos.add("tryClaim lanzo en la vuelta $vuelta: $e")
                            0L
                        }
                        if (claim == 0L) continue
                        val vivos = holders.incrementAndGet()
                        maxHolders.accumulateAndGet(vivos) { a, b -> maxOf(a, b) }
                        if (vivos != 1) {
                            fallos.add("dos duenos simultaneos en la vuelta $vuelta: $vivos")
                        }
                        holders.decrementAndGet()
                        BackgroundWork.releaseMicrophone(claim)
                        BackgroundWork.releaseMicrophone(claim)
                        BackgroundWork.releaseMicrophone(claim)
                    }
                }
            }
            pool.shutdown()
            assertTrue(pool.awaitTermination(60, TimeUnit.SECONDS))
        } finally {
            pool.shutdownNow()
        }

        assertTrue(fallos.isEmpty(), "carrera con releases duplicados: ${fallos.toList()}")
        assertEquals(1L, maxHolders.get().toLong())
        assertFalse(BackgroundWork.isMicrophoneClaimed())
    }

    @Test
    fun widgetReTapWhileBusyIsIgnoredInsteadOfClaimingAgain() {
        val teclado = BackgroundWork.tryClaimMicrophone()
        assertTrue(teclado != 0L)

        assertEquals(WidgetToggleOutcome.START, widget.handleToggle())
        assertEquals(WidgetToggleOutcome.IGNORED, widget.handleToggle())
        assertEquals(0L, widget.microphoneClaim)
        assertTrue(BackgroundWork.isMicrophoneClaimedBy(teclado))

        BackgroundWork.releaseMicrophone(teclado)
    }

    @Test
    fun widgetDictationStaysOutWhenKeyboardHoldsTheClaim() {
        val teclado = BackgroundWork.tryClaimMicrophone()
        assertTrue(teclado != 0L)

        assertEquals(0L, claimForWidget())
        assertEquals(0L, widget.microphoneClaim)
        assertTrue(BackgroundWork.isMicrophoneClaimedBy(teclado))

        widget.releaseMicrophone()
        assertTrue(BackgroundWork.isMicrophoneClaimedBy(teclado))
        BackgroundWork.releaseMicrophone(teclado)
    }

    @Test
    fun widgetDictationTakesTheClaimAndReleasesItInEveryTerminalPath() {
        val claim = claimForWidget()
        assertTrue(claim != 0L)
        assertEquals(claim, widget.microphoneClaim)
        assertTrue(BackgroundWork.isMicrophoneClaimedBy(claim))
        assertEquals(0L, BackgroundWork.tryClaimMicrophone())

        widget.releaseMicrophone()
        assertFalse(BackgroundWork.isMicrophoneClaimed())
        assertEquals(0L, widget.microphoneClaim)

        widget.releaseMicrophone()
        assertFalse(BackgroundWork.isMicrophoneClaimed())

        val segundo = claimForWidget()
        assertTrue(segundo != 0L)
        widget.releaseMicrophone()
        assertFalse(BackgroundWork.isMicrophoneClaimed())
    }

    @Test
    fun keyboardAndWidgetRaceHasASingleWinner() {
        val winners = AtomicInteger(0)
        val winnerToken = AtomicLong(0L)
        val go = CountDownLatch(1)
        val pool = Executors.newFixedThreadPool(2)
        try {
            pool.execute {
                go.await(5, TimeUnit.SECONDS)
                val claim = BackgroundWork.tryClaimMicrophone()
                if (claim != 0L) {
                    winners.incrementAndGet()
                    winnerToken.set(claim)
                }
            }
            pool.execute {
                go.await(5, TimeUnit.SECONDS)
                val claim = widget.claimMicrophoneForDictation()
                if (claim != 0L) {
                    winners.incrementAndGet()
                    winnerToken.set(claim)
                }
            }
            go.countDown()
            pool.shutdown()
            assertTrue(pool.awaitTermination(10, TimeUnit.SECONDS))
        } finally {
            pool.shutdownNow()
        }

        assertEquals(1, winners.get())
        assertTrue(winnerToken.get() != 0L)
        assertTrue(BackgroundWork.isMicrophoneClaimedBy(winnerToken.get()))
        if (winnerToken.get() == widget.microphoneClaim) {
            widget.releaseMicrophone()
        } else {
            BackgroundWork.releaseMicrophone(winnerToken.get())
        }
        assertFalse(BackgroundWork.isMicrophoneClaimed())
    }
}
