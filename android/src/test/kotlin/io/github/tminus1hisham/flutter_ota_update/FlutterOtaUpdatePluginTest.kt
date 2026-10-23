package io.github.tminus1hisham.flutter_ota_update

import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse

/*
 * Run from example/android with: ./gradlew :flutter_ota_update:testDebugUnitTest
 */
internal class FlutterOtaUpdatePluginTest {
    // SHA-256 of the ASCII bytes "hello".
    private val helloSha = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"

    private fun source(): File = File.createTempFile("ota-src", ".bin").apply { writeText("hello") }

    @Test
    fun downloadAndHash_copiesFileAndReturnsSha() {
        val dest = File.createTempFile("ota-dest", ".apk")
        var lastReceived = 0L
        val sha = downloadAndHash(source().toURI().toString(), emptyMap(), dest, helloSha) { r, _ ->
            lastReceived = r
        }
        assertEquals(helloSha, sha)
        assertEquals("hello", dest.readText())
        assertEquals(5L, lastReceived)
    }

    @Test
    fun downloadAndHash_rejectsMismatchAndDeletesFile() {
        val dest = File.createTempFile("ota-dest", ".apk")
        assertFailsWith<ChecksumMismatchException> {
            downloadAndHash(source().toURI().toString(), emptyMap(), dest, "00".repeat(32)) { _, _ -> }
        }
        assertFalse(dest.exists())
    }
}
