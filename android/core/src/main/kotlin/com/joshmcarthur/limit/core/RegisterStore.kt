package com.joshmcarthur.limit.core

import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.StandardCopyOption
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.util.UUID
import kotlin.math.floor
import org.json.JSONObject

data class RegisterMetadata(
    var checkedAt: Instant,
    var zoneCount: Int,
    /** Features the source returned, including any skipped for having no usable limit. */
    var sourceFeatureCount: Int,
    /**
     * The source layer's last-edit time when this copy was downloaded. Null if it wasn't known, or for a
     * copy saved before this was recorded.
     */
    var sourceEditedAt: Instant? = null,
)

data class StoredRegister(
    val register: SpeedLimitRegister,
    val metadata: RegisterMetadata,
)

/**
 * A new copy written to disk beside the live one, not yet in use. It becomes the live copy only when
 * [RegisterStore.commit] is called.
 */
class StagedRegister(
    val name: String,
    val metadata: RegisterMetadata,
    val checksum: ULong,
)

/**
 * Keeps the downloaded register in a directory on disk.
 *
 * Blue-green: each copy lives in its own folder (`gen-<id>`) and a small `current` file names the one in
 * use. A new copy is written to a fresh folder, checked, and only then does `current` move to it.
 */
class RegisterStore(val directory: Path) {
    private val pointer: Path get() = directory.resolve("current")
    private val attemptsFile: Path get() = directory.resolve(attemptsName)

    fun loadAttempts(): SyncAttempts {
        val data = try {
            Files.readAllBytes(attemptsFile)
        } catch (_: Exception) {
            return SyncAttempts()
        }
        return try {
            decodeAttempts(data)
        } catch (_: Exception) {
            SyncAttempts()
        }
    }

    fun saveAttempts(attempts: SyncAttempts) {
        Files.createDirectories(directory)
        writeAtomic(attemptsFile, encodeAttempts(attempts))
    }

    /** The folder name `current` points at, if it exists on disk. */
    val currentGeneration: String?
        get() {
            val text = try {
                Files.readString(pointer)
            } catch (_: Exception) {
                return null
            }
            val name = text.trimWhitespacesAndNewlines()
            if (!name.startsWith("gen-") || name.contains("/")) return null
            if (!Files.isRegularFile(metadataPath(name))) return null
            return name
        }

    /** Writes a new copy next to the live one without touching it. */
    fun stage(zones: List<SpeedZone>, metadata: RegisterMetadata): StagedRegister {
        Files.createDirectories(directory)
        removeStrayGenerations()
        val name = "gen-${UUID.randomUUID()}"
        val folder = directory.resolve(name)
        Files.createDirectory(folder)
        val stored = metadata.copy(
            checkedAt = Instant.ofEpochMilli(floor(metadata.checkedAt.toEpochMilli() / 1000.0).toLong() * 1000),
        )
        val encoded = ZoneCodec.encode(zones)
        try {
            writeAtomic(zonesPath(name), encoded)
            writeAtomic(metadataPath(name), encodeMetadata(stored))
        } catch (error: Exception) {
            deleteRecursively(folder)
            throw error
        }
        return StagedRegister(name = name, metadata = stored, checksum = Checksum.fnv1a64(encoded))
    }

    /** Reads a staged copy back from disk and confirms it is what [stage] meant to write. */
    fun verifyWritten(staged: StagedRegister): Boolean {
        val data = try {
            Files.readAllBytes(zonesPath(staged.name))
        } catch (_: Exception) {
            return false
        }
        if (Checksum.fnv1a64(data) != staged.checksum) return false
        val metadata = try {
            decodeMetadata(Files.readAllBytes(metadataPath(staged.name)))
        } catch (_: Exception) {
            return false
        }
        return metadata == staged.metadata
    }

    /** Makes a staged copy the live one, then deletes the old copy. */
    fun commit(staged: StagedRegister) {
        writeAtomic(pointer, staged.name.toByteArray(Charsets.UTF_8))
        removeStrayGenerations()
    }

    /** Throws a staged copy away; the live copy is untouched. */
    fun discard(staged: StagedRegister) {
        deleteRecursively(directory.resolve(staged.name))
    }

    /** Records a successful check that changed nothing. */
    fun updateCheckedAt(date: Instant) {
        val generation = currentGeneration ?: return
        val metadata = loadMetadata() ?: return
        metadata.checkedAt = date
        writeAtomic(metadataPath(generation), encodeMetadata(metadata))
    }

    fun loadMetadata(): RegisterMetadata? {
        val generation = currentGeneration ?: return null
        return decodeMetadata(Files.readAllBytes(metadataPath(generation)))
    }

    /** Null when nothing has been downloaded. Throws if the files are damaged. */
    fun load(): StoredRegister? {
        val generation = currentGeneration ?: return null
        val metadata = loadMetadata() ?: return null
        val zones = ZoneCodec.decode(Files.readAllBytes(zonesPath(generation)))
        return StoredRegister(register = SpeedLimitRegister(zones = zones), metadata = metadata)
    }

    fun clear() {
        if (!Files.isDirectory(directory)) return
        Files.list(directory).use { stream ->
            stream.forEach { path ->
                if (path.fileName.toString() != attemptsName) deleteRecursively(path)
            }
        }
    }

    private fun zonesPath(generation: String): Path = directory.resolve(generation).resolve("register.lmtz")

    private fun metadataPath(generation: String): Path = directory.resolve(generation).resolve("register.json")

    /** Deletes every generation folder (and any stray file) except the live one. */
    private fun removeStrayGenerations() {
        if (!Files.isDirectory(directory)) return
        val keep = currentGeneration
        Files.list(directory).use { stream ->
            stream.forEach { path ->
                val name = path.fileName.toString()
                if (name != "current" && name != keep && name != attemptsName) deleteRecursively(path)
            }
        }
    }

    private fun writeAtomic(path: Path, bytes: ByteArray) {
        Files.createDirectories(path.parent)
        val temporary = path.resolveSibling("${path.fileName}.tmp-${UUID.randomUUID()}")
        Files.write(temporary, bytes)
        try {
            Files.move(temporary, path, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
        } catch (_: Exception) {
            Files.move(temporary, path, StandardCopyOption.REPLACE_EXISTING)
        }
    }

    private fun deleteRecursively(path: Path) {
        if (!Files.exists(path)) return
        if (Files.isDirectory(path)) {
            Files.list(path).use { stream -> stream.forEach { deleteRecursively(it) } }
        }
        Files.deleteIfExists(path)
    }

    companion object {
        private const val attemptsName = "sync-attempts.json"

        private fun encodeMetadata(metadata: RegisterMetadata): ByteArray {
            val json = JSONObject()
            json.put("checkedAt", iso(metadata.checkedAt))
            json.put("zoneCount", metadata.zoneCount)
            json.put("sourceFeatureCount", metadata.sourceFeatureCount)
            metadata.sourceEditedAt?.let { json.put("sourceEditedAt", iso(it)) }
            return json.toString().toByteArray(Charsets.UTF_8)
        }

        private fun decodeMetadata(data: ByteArray): RegisterMetadata {
            val json = JSONObject(String(data, Charsets.UTF_8))
            return RegisterMetadata(
                checkedAt = Instant.parse(json.getString("checkedAt")),
                zoneCount = json.getInt("zoneCount"),
                sourceFeatureCount = json.getInt("sourceFeatureCount"),
                sourceEditedAt = if (json.has("sourceEditedAt") && !json.isNull("sourceEditedAt")) {
                    Instant.parse(json.getString("sourceEditedAt"))
                } else {
                    null
                },
            )
        }

        private fun encodeAttempts(attempts: SyncAttempts): ByteArray {
            val json = JSONObject()
            attempts.lastAttemptAt?.let { json.put("lastAttemptAt", iso(it)) }
            json.put("consecutiveFailures", attempts.consecutiveFailures)
            return json.toString().toByteArray(Charsets.UTF_8)
        }

        private fun decodeAttempts(data: ByteArray): SyncAttempts {
            val json = JSONObject(String(data, Charsets.UTF_8))
            val last = if (json.has("lastAttemptAt") && !json.isNull("lastAttemptAt")) {
                Instant.parse(json.getString("lastAttemptAt"))
            } else {
                null
            }
            val failures = if (json.has("consecutiveFailures")) json.getInt("consecutiveFailures") else 0
            return SyncAttempts(lastAttemptAt = last, consecutiveFailures = failures)
        }

        private fun iso(instant: Instant): String =
            DateTimeFormatter.ISO_INSTANT.format(Instant.ofEpochSecond(instant.epochSecond))
    }
}
