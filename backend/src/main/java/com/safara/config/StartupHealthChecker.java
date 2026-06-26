package com.safara.config;

import com.safara.service.DocumentMetadataService;
import com.safara.service.IngestService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Component
public class StartupHealthChecker {

    private static final Logger log = LoggerFactory.getLogger(StartupHealthChecker.class);

    private final String chromaBaseUrl;
    private final String ollamaBaseUrl;
    private final IngestService ingestService;
    private final DocumentMetadataService documentMetadataService;

    public StartupHealthChecker(@Value("${safara.chroma.base-url}") String chromaBaseUrl,
                                @Value("${langchain4j.ollama.base-url}") String ollamaBaseUrl,
                                IngestService ingestService,
                                DocumentMetadataService documentMetadataService) {
        this.chromaBaseUrl = chromaBaseUrl;
        this.ollamaBaseUrl = ollamaBaseUrl;
        this.ingestService = ingestService;
        this.documentMetadataService = documentMetadataService;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void onReady() {
        checkChroma();
        checkOllama();
        if (documentMetadataService.listDocuments().isEmpty()) {
            log.info("No documents found — seeding sample Kenya tourism files");
            ingestService.ingestSampleDocuments();
        }
    }

    private void checkChroma() {
        try {
            RestClient.create(chromaBaseUrl).get().uri("/api/v1/heartbeat").retrieve().toBodilessEntity();
            log.info("Chroma is reachable at {}", chromaBaseUrl);
        } catch (Exception e) {
            log.warn("Chroma not reachable at {}. Start with: docker compose up -d", chromaBaseUrl);
        }
    }

    private void checkOllama() {
        try {
            RestClient.create(ollamaBaseUrl).get().uri("/api/tags").retrieve().toBodilessEntity();
            log.info("Ollama is reachable at {}", ollamaBaseUrl);
        } catch (Exception e) {
            log.warn("Ollama not reachable at {}. Install Ollama and run: ollama pull llama3.2", ollamaBaseUrl);
        }
    }
}
