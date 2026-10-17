package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.exception.FileStorageException;
import com.gorkem.vehicle_inspector.service.FileStorageService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.mock.web.MockMultipartFile;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class FileStorageServiceTest {
    @TempDir Path directory;

    @ParameterizedTest
    @ValueSource(strings = {"image/jpeg", "image/png", "image/webp"})
    void storesIdenticalBytesAndClosesBothStreams(String mime) throws Exception {
        byte[] bytes = switch (mime) {
            case "image/png" -> new byte[]{(byte) 0x89, 'P', 'N', 'G', 13, 10, 26, 10, 1, 2, 3, 4};
            case "image/webp" -> new byte[]{'R', 'I', 'F', 'F', 0, 0, 0, 0, 'W', 'E', 'B', 'P'};
            default -> new byte[]{(byte) 0xFF, (byte) 0xD8, 1, 2, 3, 4};
        };
        TrackingUpload upload = new TrackingUpload(mime, bytes, false, false);
        FileStorageService storage = new FileStorageService(directory.toString());

        String filename = storage.storeImage(upload);

        assertArrayEquals(bytes, Files.readAllBytes(storage.resolveStoredFile(filename)));
        assertEquals(2, upload.streams.size());
        assertTrue(upload.streams.stream().allMatch(stream -> stream.closed));
    }

    @Test
    void invalidSignatureClosesItsStreamAndCreatesNoFile() throws Exception {
        TrackingUpload upload = new TrackingUpload("image/jpeg", new byte[]{1, 2, 3}, false, false);
        assertThrows(FileStorageException.class, () -> new FileStorageService(directory.toString()).storeImage(upload));
        assertEquals(1, upload.streams.size());
        assertTrue(upload.streams.getFirst().closed);
        try (var paths = Files.list(directory)) {
            assertEquals(0, paths.count());
        }
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void failedCopyOrCloseRemovesOnlyItsNewFile(boolean failOnClose) throws Exception {
        Path oldImage = Files.write(directory.resolve("previous-report.jpg"), new byte[]{7, 8, 9});
        TrackingUpload upload = new TrackingUpload("image/jpeg", new byte[]{(byte) 0xFF, (byte) 0xD8, 1, 2},
                !failOnClose, failOnClose);

        assertThrows(FileStorageException.class, () -> new FileStorageService(directory.toString()).storeImage(upload));

        assertArrayEquals(new byte[]{7, 8, 9}, Files.readAllBytes(oldImage));
        assertEquals(2, upload.streams.size());
        assertTrue(upload.streams.stream().allMatch(stream -> stream.closed));
        try (var paths = Files.list(directory)) {
            assertEquals(List.of(oldImage), paths.toList());
        }
    }

    @Test
    void oversizedFileIsRejectedBeforeOpeningAStream() {
        TrackingUpload upload = new TrackingUpload("image/jpeg", new byte[]{(byte) 0xFF, (byte) 0xD8}, false, false) {
            @Override public long getSize() { return 10L * 1024 * 1024 + 1; }
        };
        assertThrows(FileStorageException.class, () -> new FileStorageService(directory.toString()).storeImage(upload));
        assertTrue(upload.streams.isEmpty());
    }

    private static class TrackingUpload extends MockMultipartFile {
        private final List<TrackingStream> streams = new ArrayList<>();
        private final boolean failCopy;
        private final boolean failClose;

        TrackingUpload(String mime, byte[] bytes, boolean failCopy, boolean failClose) {
            super("image", "photo", mime, bytes);
            this.failCopy = failCopy;
            this.failClose = failClose;
        }

        @Override public InputStream getInputStream() throws IOException {
            boolean copying = !streams.isEmpty();
            TrackingStream stream = new TrackingStream(getBytes(), copying && failCopy, copying && failClose);
            streams.add(stream);
            return stream;
        }
    }

    private static class TrackingStream extends ByteArrayInputStream {
        private final boolean failCopy;
        private final boolean failClose;
        private boolean closed;

        TrackingStream(byte[] bytes, boolean failCopy, boolean failClose) {
            super(bytes);
            this.failCopy = failCopy;
            this.failClose = failClose;
        }

        @Override public long transferTo(java.io.OutputStream output) throws IOException {
            if (failCopy) {
                output.write(read());
                throw new IOException("simulated interrupted copy");
            }
            return super.transferTo(output);
        }

        @Override public void close() throws IOException {
            closed = true;
            super.close();
            if (failClose) throw new IOException("simulated close failure");
        }
    }
}
