class SourceInfo {
  const SourceInfo({
    required this.fileName,
    required this.excerpt,
    this.score,
  });

  final String fileName;
  final String excerpt;
  final double? score;

  factory SourceInfo.fromJson(Map<String, dynamic> json) {
    return SourceInfo(
      fileName: json['fileName'] as String? ?? 'Unknown',
      excerpt: json['excerpt'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble(),
    );
  }
}
