package com.safara.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.safara.dto.SourceDto;
import dev.langchain4j.data.document.Metadata;
import dev.langchain4j.data.segment.TextSegment;
import dev.langchain4j.rag.content.Content;
import dev.langchain4j.service.TokenStream;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Sinks;

import java.util.List;

@Service
public class ChatService {

    private static final Logger log = LoggerFactory.getLogger(ChatService.class);

    private final SafaraAiService safaraAiService;
    private final ObjectMapper objectMapper;

    public ChatService(SafaraAiService safaraAiService, ObjectMapper objectMapper) {
        this.safaraAiService = safaraAiService;
        this.objectMapper = objectMapper;
    }

    public Flux<ServerSentEvent<String>> streamChat(String sessionId, String message) {
        Sinks.Many<ServerSentEvent<String>> sink = Sinks.many().unicast().onBackpressureBuffer();

        TokenStream tokenStream = safaraAiService.chat(sessionId, message);

        tokenStream
                .onRetrieved(contents -> {
                    List<SourceDto> sources = contents.stream().map(this::toSourceDto).toList();
                    try {
                        String json = objectMapper.writeValueAsString(sources);
                        sink.tryEmitNext(ServerSentEvent.builder(json).event("sources").build());
                    } catch (JsonProcessingException e) {
                        log.warn("Failed to serialize sources", e);
                    }
                })
                .onPartialResponse(token -> sink.tryEmitNext(ServerSentEvent.builder(token).event("token").build()))
                .onCompleteResponse(response -> {
                    sink.tryEmitNext(ServerSentEvent.builder("complete").event("done").build());
                    sink.tryEmitComplete();
                })
                .onError(error -> {
                    log.error("Chat stream error for session {}", sessionId, error);
                    sink.tryEmitNext(ServerSentEvent.builder(error.getMessage()).event("error").build());
                    sink.tryEmitComplete();
                })
                .start();

        return sink.asFlux();
    }

    private SourceDto toSourceDto(Content content) {
        TextSegment segment = content.textSegment();
        Metadata metadata = segment.metadata();
        String fileName = metadata != null ? metadata.getString("fileName") : null;
        if (fileName == null || fileName.isBlank()) {
            fileName = "Unknown source";
        }
        String text = segment.text();
        String excerpt = text.length() > 200 ? text.substring(0, 200) + "..." : text;
        Double score = content.metadata() != null ? content.metadata().score() : null;
        return new SourceDto(fileName, excerpt, score);
    }
}
