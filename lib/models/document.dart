// Document model for storing markdown text and metadata

class Document {
  final String id;
  final String content;
  final DateTime lastModified;
  final String title;

  Document({
    required this.id,
    required this.content,
    required this.lastModified,
    String? title,
  }) : title = title ?? _extractTitle(content);

  // Extract title from first line or use timestamp
  static String _extractTitle(String content) {
    if (content.isEmpty) return 'Untitled';

    final lines = content.split('\n');
    final firstLine = lines.first.trim();

    // Remove markdown heading symbols
    if (firstLine.startsWith('#')) {
      return firstLine.replaceAll(RegExp(r'^#+\s*'), '').trim();
    }

    return firstLine.isEmpty ? 'Untitled' : firstLine.substring(0, firstLine.length > 50 ? 50 : firstLine.length);
  }

  Document copyWith({
    String? id,
    String? content,
    DateTime? lastModified,
    String? title,
  }) {
    return Document(
      id: id ?? this.id,
      content: content ?? this.content,
      lastModified: lastModified ?? this.lastModified,
      title: title ?? this.title,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'lastModified': lastModified.toIso8601String(),
      'title': title,
    };
  }

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'] as String,
      content: json['content'] as String,
      lastModified: DateTime.parse(json['lastModified'] as String),
      title: json['title'] as String?,
    );
  }
}
