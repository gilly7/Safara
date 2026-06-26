package com.safara.dto;

import java.time.Instant;

public record DocumentDto(
        String id,
        String fileName,
        String contentType,
        long sizeBytes,
        int chunkCount,
        Instant uploadedAt
) {}
