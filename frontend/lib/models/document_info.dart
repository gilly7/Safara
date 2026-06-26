class DocumentInfo {
  const DocumentInfo({
    required this.id,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.chunkCount,
    required this.uploadedAt,
  });

  final String id;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final int chunkCount;
  final DateTime uploadedAt;

  factory DocumentInfo.fromJson(Map<String, dynamic> json) {
    return DocumentInfo(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      contentType: json['contentType'] as String? ?? 'unknown',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      chunkCount: (json['chunkCount'] as num?)?.toInt() ?? 0,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
    );
  }

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
