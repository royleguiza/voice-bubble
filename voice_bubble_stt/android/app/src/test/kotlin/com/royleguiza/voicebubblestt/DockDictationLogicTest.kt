package com.royleguiza.voicebubblestt

import com.royleguiza.voicebubblestt.DockDictationLogic.AfterStart as A
import com.royleguiza.voicebubblestt.DockDictationLogic.Phase as P
import com.royleguiza.voicebubblestt.DockDictationLogic.Toggle as T
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Máquina de estados del dictado de la barra flotante (TOGGLE / CANCEL). JVM pura. */
class DockDictationLogicTest {

    @Test
    fun `en reposo un toque empieza, grabando termina, transcribiendo se ignora`() {
        val l = DockDictationLogic()
        assertEquals(P.IDLE, l.phase)
        assertFalse(l.isBusy)
        assertEquals(T.START, l.onToggle())
        assertEquals(P.STARTING, l.phase)
        assertEquals(A.KEEP_RECORDING, l.onRecordingStarted())
        assertEquals(P.RECORDING, l.phase)
        assertEquals(T.STOP, l.onToggle())
        assertEquals(P.TRANSCRIBING, l.phase)
        assertEquals(T.IGNORE, l.onToggle())
        assertEquals(P.TRANSCRIBING, l.phase)
        l.onFinished()
        assertEquals(P.IDLE, l.phase)
        assertEquals(T.START, l.onToggle())
    }

    @Test
    fun `un segundo toque mientras arranca el microfono termina apenas arranque`() {
        val l = DockDictationLogic()
        l.onToggle()
        assertEquals(T.QUEUE_STOP, l.onToggle())
        assertEquals(P.STARTING, l.phase)
        assertEquals(A.STOP_NOW, l.onRecordingStarted())
        assertEquals(P.TRANSCRIBING, l.phase)
    }

    @Test
    fun `cancelar grabando corta ya`() {
        val l = DockDictationLogic()
        l.onToggle()
        l.onRecordingStarted()
        assertTrue(l.onCancel())
        assertEquals(P.IDLE, l.phase)
    }

    @Test
    fun `cancelar mientras arranca corta apenas arranque`() {
        val l = DockDictationLogic()
        l.onToggle()
        assertFalse(l.onCancel())
        assertEquals(P.STARTING, l.phase)
        assertEquals(A.CANCEL_NOW, l.onRecordingStarted())
        assertEquals(P.IDLE, l.phase)
    }

    @Test
    fun `cancelar transcribiendo o en reposo no hace nada`() {
        val l = DockDictationLogic()
        assertFalse(l.onCancel())
        l.onToggle()
        l.onRecordingStarted()
        l.onToggle()
        assertEquals(P.TRANSCRIBING, l.phase)
        assertFalse(l.onCancel())
        assertEquals(P.TRANSCRIBING, l.phase)
    }

    @Test
    fun `si no arranca vuelve a reposo y no arrastra pedidos viejos`() {
        val l = DockDictationLogic()
        l.onToggle()
        l.onToggle() // terminar en cola
        l.onStartFailed()
        assertEquals(P.IDLE, l.phase)
        assertEquals(T.START, l.onToggle())
        assertEquals(A.KEEP_RECORDING, l.onRecordingStarted())
    }

    @Test
    fun `arrancar dos veces seguidas no deja un cancelar colgado`() {
        val l = DockDictationLogic()
        l.onToggle()
        l.onCancel()
        l.onRecordingStarted()
        assertEquals(T.START, l.onToggle())
        assertEquals(A.KEEP_RECORDING, l.onRecordingStarted())
    }

    @Test
    fun `audio minimo util de 8000 bytes como la app`() {
        assertFalse(DockDictationLogic.hasUsableAudio(7999))
        assertTrue(DockDictationLogic.hasUsableAudio(8000))
    }

    @Test
    fun `los errores de transcripcion tienen una frase fija y corta`() {
        assertEquals(DockDictationLogic.MSG_NO_NETWORK, DockDictationLogic.errorMessage(null))
        assertEquals(DockDictationLogic.MSG_BAD_KEY, DockDictationLogic.errorMessage(401))
        assertEquals(DockDictationLogic.MSG_BAD_KEY, DockDictationLogic.errorMessage(403))
        assertEquals(DockDictationLogic.MSG_RATE_LIMIT, DockDictationLogic.errorMessage(429))
        assertEquals(DockDictationLogic.MSG_FAILED, DockDictationLogic.errorMessage(500))
        assertEquals(DockDictationLogic.MSG_FAILED, DockDictationLogic.errorMessage(400))
    }

    @Test
    fun `las frases entran en el mensaje corto del protocolo`() {
        val all = listOf(
            DockDictationLogic.MSG_PASTED, DockDictationLogic.MSG_COPIED, DockDictationLogic.MSG_NO_KEY,
            DockDictationLogic.MSG_NO_MIC_PERMISSION, DockDictationLogic.MSG_MIC_BUSY, DockDictationLogic.MSG_MIC_FAILED,
            DockDictationLogic.MSG_NO_NETWORK, DockDictationLogic.MSG_BAD_KEY, DockDictationLogic.MSG_RATE_LIMIT,
            DockDictationLogic.MSG_FAILED, DockDictationLogic.MSG_NOTHING, DockDictationLogic.MSG_TOO_BIG,
        )
        for (m in all) {
            val text = stringResource(m)
            assertTrue("«$text» entra en ${PointerProtocol.MAX_MIC_MESSAGE}", text.length <= PointerProtocol.MAX_MIC_MESSAGE)
        }
        assertEquals("Pegado", stringResource(DockDictationLogic.doneMessage(true)))
        assertEquals("Copiado", stringResource(DockDictationLogic.doneMessage(false)))
    }

    /** Texto (es) de un id de `R.string`, leído de `res/values-es/strings.xml` (los tests JVM no tienen Resources). */
    private fun stringResource(id: Int): String {
        val name = R.string::class.java.fields.first { it.type == Int::class.javaPrimitiveType && it.getInt(null) == id }.name
        val xml = java.io.File("src/main/res/values-es/strings.xml").readText(Charsets.UTF_8)
        val raw = Regex("<string name=\"" + name + "\">(.*?)</string>", RegexOption.DOT_MATCHES_ALL).find(xml)!!.groupValues[1]
        return raw.replace("\\'", "'").replace("\\\"", "\"").replace("&amp;", "&")
    }
}
