package com.royleguiza.voicebubblestt

import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** T16 · Los stickers entran en 512 × 512 sin deformarse. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33], manifest = Config.NONE)
class StickerStoreTest {
    @Test
    fun squareFillsTheBox() {
        val r = StickerStore.fitInside(1000, 1000)
        assertEquals(0, r.left)
        assertEquals(512, r.width())
        assertEquals(512, r.height())
    }

    @Test
    fun wideIsCenteredVertically() {
        val r = StickerStore.fitInside(1024, 512)
        assertEquals(512, r.width())
        assertEquals(256, r.height())
        assertEquals(128, r.top)
    }

    @Test
    fun tallIsCenteredHorizontally() {
        val r = StickerStore.fitInside(300, 600)
        assertEquals(256, r.width())
        assertEquals(512, r.height())
        assertEquals(128, r.left)
    }

    @Test
    fun hugePhotosAreDecodedSmaller() {
        assertEquals(1, StickerStore.sampleSize(800, 800))
        assertEquals(2, StickerStore.sampleSize(4000, 3000))
        assertEquals(4, StickerStore.sampleSize(8000, 6000))
    }
}
