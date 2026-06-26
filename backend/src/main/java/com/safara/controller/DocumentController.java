package com.safara.controller;

import com.safara.dto.DocumentDto;
import com.safara.service.DocumentMetadataService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api")
public class DocumentController {

    private final DocumentMetadataService documentMetadataService;

    public DocumentController(DocumentMetadataService documentMetadataService) {
        this.documentMetadataService = documentMetadataService;
    }

    @GetMapping("/documents")
    public List<DocumentDto> listDocuments() {
        return documentMetadataService.listDocuments();
    }
}
