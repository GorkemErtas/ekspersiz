package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.exception.FileStorageException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Set;
import java.util.UUID;

@Service
public class FileStorageService {

    private static final long MAX_FILE_SIZE =
            10L * 1024 * 1024;

    private static final Set<String>
            ALLOWED_CONTENT_TYPES =
            Set.of(
                    "image/jpeg",
                    "image/png",
                    "image/webp"
            );

    private final Path uploadDirectory;

    public FileStorageService(
            @Value("${application.storage.upload-dir}")
            String uploadDirectory
    ) {
        this.uploadDirectory =
                Path.of(uploadDirectory)
                        .toAbsolutePath()
                        .normalize();

        createUploadDirectory();
    }

    public String storeImage(
            MultipartFile file
    ) {
        validateFile(file);

        String extension =
                getExtensionFromContentType(
                        file.getContentType()
                );

        String storedFilename =
                UUID.randomUUID()
                        + extension;

        Path destination =
                uploadDirectory
                        .resolve(storedFilename)
                        .normalize();

        if (!destination.startsWith(
                uploadDirectory
        )) {
            throw new FileStorageException(
                    "Geçersiz dosya yolu."
            );
        }

        try {
            Files.copy(
                    file.getInputStream(),
                    destination,
                    StandardCopyOption
                            .REPLACE_EXISTING
            );
        } catch (IOException exception) {
            throw new FileStorageException(
                    "Dosya kaydedilemedi.",
                    exception
            );
        }

        return storedFilename;
    }

    public Path resolveStoredFile(
            String imagePath
    ) {
        if (imagePath == null
                || imagePath.isBlank()) {

            throw new FileStorageException(
                    "İncelemeye ait fotoğraf bulunamadı."
            );
        }

        String filename =
                Path.of(imagePath)
                        .getFileName()
                        .toString();

        Path resolvedPath =
                uploadDirectory
                        .resolve(filename)
                        .normalize();

        if (!resolvedPath.startsWith(
                uploadDirectory
        )) {
            throw new FileStorageException(
                    "Geçersiz fotoğraf yolu."
            );
        }

        if (!Files.isRegularFile(
                resolvedPath
        )) {
            throw new FileStorageException(
                    "Fotoğraf dosyası bulunamadı."
            );
        }

        return resolvedPath;
    }

    public void deleteStoredFile(
            String imagePath
    ) {
        if (imagePath == null
                || imagePath.isBlank()) {
            return;
        }

        String filename =
                Path.of(imagePath)
                        .getFileName()
                        .toString();

        Path resolvedPath =
                uploadDirectory
                        .resolve(filename)
                        .normalize();

        if (!resolvedPath.startsWith(
                uploadDirectory
        )) {
            throw new FileStorageException(
                    "Geçersiz fotoğraf yolu."
            );
        }

        try {
            Files.deleteIfExists(
                    resolvedPath
            );
        } catch (IOException exception) {
            throw new FileStorageException(
                    "Fotoğraf silinemedi.",
                    exception
            );
        }
    }

    private void createUploadDirectory() {
        try {
            Files.createDirectories(
                    uploadDirectory
            );
        } catch (IOException exception) {
            throw new FileStorageException(
                    "Upload klasörü oluşturulamadı.",
                    exception
            );
        }
    }

    private void validateFile(
            MultipartFile file
    ) {
        if (file == null
                || file.isEmpty()) {

            throw new FileStorageException(
                    "Yüklenecek fotoğraf boş olamaz."
            );
        }

        if (file.getSize()
                > MAX_FILE_SIZE) {

            throw new FileStorageException(
                    "Fotoğraf boyutu en fazla "
                            + "10 MB olabilir."
            );
        }

        String contentType =
                file.getContentType();

        if (contentType == null
                || !ALLOWED_CONTENT_TYPES
                .contains(contentType)) {

            throw new FileStorageException(
                    "Yalnızca JPG, PNG veya WEBP "
                            + "yüklenebilir."
            );
        }

        validateFileSignature(
                file,
                contentType
        );
    }

    private void validateFileSignature(
            MultipartFile file,
            String contentType
    ) {
        try {
            byte[] header =
                    file.getInputStream()
                            .readNBytes(12);

            boolean valid =
                    switch (contentType) {

                        case "image/jpeg" ->
                                header.length >= 2
                                        && (header[0] & 0xFF) == 0xFF
                                        && (header[1] & 0xFF) == 0xD8;

                        case "image/png" ->
                                header.length >= 8
                                        && (header[0] & 0xFF) == 0x89
                                        && (header[1] & 0xFF) == 0x50
                                        && (header[2] & 0xFF) == 0x4E
                                        && (header[3] & 0xFF) == 0x47
                                        && (header[4] & 0xFF) == 0x0D
                                        && (header[5] & 0xFF) == 0x0A
                                        && (header[6] & 0xFF) == 0x1A
                                        && (header[7] & 0xFF) == 0x0A;

                        case "image/webp" ->
                                header.length >= 12
                                        && header[0] == 'R'
                                        && header[1] == 'I'
                                        && header[2] == 'F'
                                        && header[3] == 'F'
                                        && header[8] == 'W'
                                        && header[9] == 'E'
                                        && header[10] == 'B'
                                        && header[11] == 'P';

                        default -> false;
                    };

            if (!valid) {
                throw new FileStorageException(
                        "Dosya içeriği geçerli bir fotoğraf değil."
                );
            }

        } catch (IOException exception) {
            throw new FileStorageException(
                    "Fotoğraf doğrulanamadı.",
                    exception
            );
        }
    }

    private String getExtensionFromContentType(
            String contentType
    ) {
        return switch (contentType) {
            case "image/jpeg" -> ".jpg";
            case "image/png" -> ".png";
            case "image/webp" -> ".webp";

            default ->
                    throw new FileStorageException(
                            "Desteklenmeyen "
                                    + "fotoğraf formatı."
                    );
        };
    }
}