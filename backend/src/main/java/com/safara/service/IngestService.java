package com.safara.service;

import com.safara.dto.IngestResponse;
import com.safara.exception.ApiException;
import dev.langchain4j.data.document.Document;
import dev.langchain4j.data.document.DocumentSplitter;
import dev.langchain4j.data.document.Metadata;
import dev.langchain4j.data.document.loader.FileSystemDocumentLoader;
import dev.langchain4j.data.document.parser.TextDocumentParser;
import dev.langchain4j.data.document.parser.apache.pdfbox.ApachePdfBoxDocumentParser;
import dev.langchain4j.data.document.splitter.DocumentSplitters;
import dev.langchain4j.data.segment.TextSegment;
import dev.langchain4j.model.embedding.EmbeddingModel;
import dev.langchain4j.store.embedding.EmbeddingStore;
import dev.langchain4j.store.embedding.EmbeddingStoreIngestor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

@Service
public class IngestService {

    private static final Logger log = LoggerFactory.getLogger(IngestService.class);
    private static final Set<String> ALLOWED_EXTENSIONS = Set.of("pdf", "txt");

    private final Path uploadsDir;
    private final EmbeddingStore<TextSegment> embeddingStore;
    private final EmbeddingModel embeddingModel;
    private final DocumentMetadataService metadataService;
    private final DocumentSplitter documentSplitter;

    public IngestService(@Value("${safara.uploads-dir}") String uploadsDir,
                         @Value("${safara.rag.chunk-size}") int chunkSize,
                         @Value("${safara.rag.chunk-overlap}") int chunkOverlap,
                         EmbeddingStore<TextSegment> embeddingStore,
                         EmbeddingModel embeddingModel,
                         DocumentMetadataService metadataService) {
        this.uploadsDir = Path.of(uploadsDir);
        this.embeddingStore = embeddingStore;
        this.embeddingModel = embeddingModel;
        this.metadataService = metadataService;
        this.documentSplitter = DocumentSplitters.recursive(chunkSize, chunkOverlap);
    }

    public List<IngestResponse> ingestFiles(MultipartFile[] files) {
        if (files == null || files.length == 0) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "No files provided");
        }

        List<IngestResponse> responses = new ArrayList<>();
        for (MultipartFile file : files) {
            responses.add(ingestFile(file));
        }
        return responses;
    }

    public IngestResponse ingestFile(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Empty file upload");
        }

        String originalName = Path.of(file.getOriginalFilename() != null ? file.getOriginalFilename() : "unknown")
                .getFileName()
                .toString();
        String extension = getExtension(originalName);

        if (!ALLOWED_EXTENSIONS.contains(extension)) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Unsupported file type: " + extension + ". Allowed: PDF, TXT");
        }

        try {
            Files.createDirectories(uploadsDir);
            Path savedPath = uploadsDir.resolve(sanitizeFileName(originalName));
            file.transferTo(savedPath);

            Document document = loadDocument(savedPath, extension);
            Metadata meta = document.metadata() != null ? document.metadata() : Metadata.from(Map.of());
            meta = meta.put("fileName", originalName).put("uploadedAt", Instant.now().toString());
            document = Document.from(document.text(), meta);

            EmbeddingStoreIngestor ingestor = EmbeddingStoreIngestor.builder()
                    .embeddingStore(embeddingStore)
                    .embeddingModel(embeddingModel)
                    .documentSplitter(documentSplitter)
                    .build();

            ingestor.ingest(document);

            int chunkCount = documentSplitter.split(document).size();
            metadataService.addDocument(originalName, file.getContentType(), file.getSize(), chunkCount);

            log.info("Ingested {} ({} chunks)", originalName, chunkCount);
            return new IngestResponse(originalName, chunkCount, "Document ingested successfully");
        } catch (IOException e) {
            log.error("Failed to ingest {}", originalName, e);
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Failed to ingest document: " + originalName);
        }
    }

    public void ingestSampleDocuments() {
        Path samplesDir = Path.of("./data/samples");
        if (!Files.isDirectory(samplesDir)) {
            return;
        }
        try {
            Files.list(samplesDir)
                    .filter(p -> ALLOWED_EXTENSIONS.contains(getExtension(p.getFileName().toString())))
                    .forEach(path -> {
                        try {
                            String fileName = path.getFileName().toString();
                            Document document = loadDocument(path, getExtension(fileName));
                            Metadata meta = document.metadata() != null ? document.metadata() : Metadata.from(Map.of());
                            meta = meta.put("fileName", fileName).put("uploadedAt", Instant.now().toString());
                            document = Document.from(document.text(), meta);

                            EmbeddingStoreIngestor ingestor = EmbeddingStoreIngestor.builder()
                                    .embeddingStore(embeddingStore)
                                    .embeddingModel(embeddingModel)
                                    .documentSplitter(documentSplitter)
                                    .build();
                            ingestor.ingest(document);

                            int chunkCount = documentSplitter.split(document).size();
                            metadataService.addDocument(fileName, "text/plain", Files.size(path), chunkCount);
                            log.info("Seeded sample document: {}", fileName);
                        } catch (Exception e) {
                            log.warn("Failed to seed sample {}", path, e);
                        }
                    });
        } catch (IOException e) {
            log.warn("Could not seed sample documents", e);
        }
    }

    private Document loadDocument(Path path, String extension) throws IOException {
        if ("pdf".equals(extension)) {
            return FileSystemDocumentLoader.loadDocument(path, new ApachePdfBoxDocumentParser());
        }
        return FileSystemDocumentLoader.loadDocument(path, new TextDocumentParser());
    }

    private String getExtension(String fileName) {
        int dot = fileName.lastIndexOf('.');
        if (dot < 0) {
            return "";
        }
        return fileName.substring(dot + 1).toLowerCase(Locale.ROOT);
    }

    private String sanitizeFileName(String fileName) {
        return fileName.replaceAll("[^a-zA-Z0-9._-]", "_");
    }
}
