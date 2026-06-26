package com.safara.dto;

public record IngestResponse(
        String fileName,
        int chunkCount,
        String message
) {}
