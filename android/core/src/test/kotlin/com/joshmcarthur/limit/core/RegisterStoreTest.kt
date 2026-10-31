package com.joshmcarthur.limit.core

import java.nio.file.Files
import java.time.Instant
import java.util.UUID
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.test.fail

class RegisterStoreTest {
    private val directory = Files.createTempDirectory("limit-tests-")
    private val checked: Instant = Instant.ofEpochSecond(1_800_000_000)

    private fun zones(): List<SpeedZone> {
        val ring = Ring(
            listOf(
                Coordinate(latitude = -41.1, longitude = 173.9),
                Coordinate(latitude = -41.1, longitude = 174.1),
                Coordinate(latitude = -40.9, longitude = 174.1),
                Coordinate(latitude = -40.9, longitude = 173.9),
            ),
        )!!
        return listOf(SpeedZone(name = "MAIN ROAD", limit = 60, polygons = listOf(Polygon(outer = ring)))!!)
    }

    private fun other(): List<SpeedZone> {
        val ring = Ring(
            listOf(
                Coordinate(latitude = -45.1, longitude = 169.9),
                Coordinate(latitude = -45.1, longitude = 170.1),
                Coordinate(latitude = -44.9, longitude = 170.1),
                Coordinate(latitude = -44.9, longitude = 169.9),
            ),
        )!!
        return listOf(SpeedZone(name = "OTHER ROAD", limit = 80, polygons = listOf(Polygon(outer = ring)))!!)
    }

    private fun meta(count: Int = 1) = RegisterMetadata(checkedAt = checked, zoneCount = count, sourceFeatureCount = count)

    private fun generations(): List<String> =
        Files.list(directory).use { stream ->
            stream.map { it.fileName.toString() }.filter { it.startsWith("gen-") }.toList()
        }

    @Test
    fun emptyStoreLoadsNil() {
        assertNull(RegisterStore(directory).load())
        assertNull(RegisterStore(directory).loadMetadata())
        Files.deleteIfExists(directory)
    }

    @Test
    fun saveThenLoad() {
        val store = RegisterStore(directory)
        val metadata = RegisterMetadata(checkedAt = checked, zoneCount = 1, sourceFeatureCount = 3)
        store.save(zones(), metadata)
        val loaded = store.load() ?: fail("expected a register")
        assertEquals(metadata, loaded.metadata)
        assertEquals(60, loaded.register.lookup(Coordinate(latitude = -41.0, longitude = 174.0))?.limit)
        store.clear()
        Files.deleteIfExists(directory)
    }

    @Test
    fun updateCheckedAtKeepsData() {
        val store = RegisterStore(directory)
        store.save(zones(), RegisterMetadata(checkedAt = checked, zoneCount = 1, sourceFeatureCount = 1))
        store.updateCheckedAt(checked.plusSeconds(86_400))
        val loaded = store.load() ?: fail("expected a register")
        assertEquals(checked.plusSeconds(86_400), loaded.metadata.checkedAt)
        assertEquals(1, loaded.register.zoneCount)
        store.clear()
        Files.deleteIfExists(directory)
    }

    @Test
    fun corruptDataThrowsAndClearRecovers() {
        val store = RegisterStore(directory)
        store.save(zones(), RegisterMetadata(checkedAt = checked, zoneCount = 1, sourceFeatureCount = 1))
        val generation = store.currentGeneration ?: fail("expected a generation")
        Files.write(directory.resolve(generation).resolve("register.lmtz"), "junk".toByteArray())
        var threw = false
        try {
            store.load()
        } catch (_: Exception) {
            threw = true
        }
        assertTrue(threw)
        store.clear()
        assertNull(store.load())
        Files.deleteIfExists(directory)
    }

    @Test
    fun aStagedCopyIsNotLiveUntilCommitted() {
        val store = RegisterStore(directory)
        store.save(zones(), meta())
        val staged = store.stage(other(), meta())
        val before = store.load() ?: fail("expected the live copy")
        assertEquals(60, before.register.lookup(Coordinate(latitude = -41.0, longitude = 174.0))?.limit)
        assertNull(before.register.lookup(Coordinate(latitude = -45.0, longitude = 170.0)))
        store.commit(staged)
        val after = store.load() ?: fail("expected the new copy")
        assertEquals(80, after.register.lookup(Coordinate(latitude = -45.0, longitude = 170.0))?.limit)
        assertNull(after.register.lookup(Coordinate(latitude = -41.0, longitude = 174.0)))
        store.clear()
        Files.deleteIfExists(directory)
    }

    @Test
    fun commitDeletesTheOldCopy() {
        val store = RegisterStore(directory)
        store.save(zones(), meta())
        store.save(other(), meta())
        assertEquals(1, generations().size)
        store.clear()
        Files.deleteIfExists(directory)
    }

    @Test
    fun discardLeavesTheLiveCopyUntouched() {
        val store = RegisterStore(directory)
        store.save(zones(), meta())
        val live = store.currentGeneration
        store.discard(store.stage(other(), meta()))
        assertEquals(live, store.currentGeneration)
        assertEquals(1, generations().size)
        val loaded = store.load() ?: fail("expected the live copy")
        assertEquals(60, loaded.register.lookup(Coordinate(latitude = -41.0, longitude = 174.0))?.limit)
        store.clear()
        Files.deleteIfExists(directory)
    }

    @Test
    fun anInterruptedCopyIsIgnoredAndCleanedUp() {
        val store = RegisterStore(directory)
        store.save(zones(), meta())
        val stray = directory.resolve("gen-${UUID.randomUUID()}")
        Files.createDirectory(stray)
        Files.write(stray.resolve("register.lmtz"), "half".toByteArray())
        assertEquals(1, store.load()?.register?.zoneCount)
        store.stage(other(), meta())
        assertFalse(Files.exists(stray))
        store.clear()
        Files.deleteIfExists(directory)
    }

    @Test
    fun aDanglingPointerLoadsNothing() {
        val store = RegisterStore(directory)
        Files.createDirectories(directory)
        Files.write(directory.resolve("current"), "gen-missing".toByteArray())
        assertNull(store.load())
        store.clear()
        Files.deleteIfExists(directory)
    }

    @Test
    fun aPointerCannotEscapeTheDirectory() {
        val store = RegisterStore(directory)
        Files.createDirectories(directory)
        Files.write(directory.resolve("current"), "gen-../../x".toByteArray())
        assertNull(store.currentGeneration)
        store.clear()
        Files.deleteIfExists(directory)
    }

    @Test
    fun clearRemovesEverything() {
        val store = RegisterStore(directory)
        store.save(zones(), meta())
        store.clear()
        assertNull(store.load())
        val names = Files.list(directory).use { it.map { path -> path.fileName.toString() }.toList() }
        assertEquals(emptyList(), names)
        Files.deleteIfExists(directory)
    }

    @Test
    fun aStagedCopyReadsBackIntactOrFails() {
        val store = RegisterStore(directory)
        val staged = store.stage(zones(), meta())
        assertTrue(store.verifyWritten(staged))
        val file = directory.resolve(staged.name).resolve("register.lmtz")
        val bytes = Files.readAllBytes(file)
        bytes[bytes.size - 1] = (bytes[bytes.size - 1].toInt() xor 0xFF).toByte()
        Files.write(file, bytes)
        assertFalse(store.verifyWritten(staged))
        store.clear()
        Files.deleteIfExists(directory)
    }

    @Test
    fun aMissingStagedFileFailsVerification() {
        val store = RegisterStore(directory)
        val staged = store.stage(zones(), meta())
        store.discard(staged)
        assertFalse(store.verifyWritten(staged))
        store.clear()
        Files.deleteIfExists(directory)
    }
}

fun RegisterStore.save(zones: List<SpeedZone>, metadata: RegisterMetadata) {
    commit(stage(zones, metadata))
}
