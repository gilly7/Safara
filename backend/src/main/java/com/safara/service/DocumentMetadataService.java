package com.safara.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.safara.dto.DocumentDto;
import com.safara.exception.ApiException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
public class DocumentMetadataService {

    private static final Logger log = LoggerFactory.getLogger(DocumentMetadataService.class);

    private final Path metadataPath;
    private final ObjectMapper objectMapper;

    public DocumentMetadataService(@Value("${safara.documents-metadata}") String metadataFile) {
        this.metadataPath = Path.of(metadataFile);
        this.objectMapper = new ObjectMapper()
                .registerModule(new JavaTimeModule())
                .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
    }

    public synchronized List<DocumentDto> listDocuments() {
        return new ArrayList<>(readAll());
    }

    public synchronized DocumentDto addDocument(String fileName, String contentType, long sizeBytes, int chunkCount) {
        List<DocumentDto> documents = readAll();
        DocumentDto document = new DocumentDto(
                UUID.randomUUID().toString(),
                fileName,
                contentType,
                sizeBytes,
                chunkCount,
                Instant.now()
        );
        documents.add(document);
        writeAll(documents);
        log.info("Registered document metadata: {}", fileName);
        return document;
    }

    private List<DocumentDto> readAll() {
        try {
            if (!Files.exists(metadataPath)) {
                Files.createDirectories(metadataPath.getParent());
                return new ArrayList<>();
            }
            byte[] bytes = Files.readAllBytes(metadataPath);
            if (bytes.length == 0) {
                return new ArrayList<>();
            }
            return objectMapper.readValue(bytes, new TypeReference<>() {});
        } catch (IOException e) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Failed to read document metadata");
        }
    }

    private void writeAll(List<DocumentDto> documents) {
        try {
            Files.createDirectories(metadataPath.getParent());
            objectMapper.writerWithDefaultPrettyPrinter().writeValue(metadataPath.toFile(), documents);
        } catch (IOException e) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Failed to save document metadata");
        }
    }
}
