// Storage service for persisting documents locally using shared preferences

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/document.dart';

class StorageService {
  static const String _currentDocKey = 'current_document';
  static const String _documentsListKey = 'documents_list';

  // Save current document
  Future<void> saveCurrentDocument(Document document) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentDocKey, jsonEncode(document.toJson()));
  }

  // Load current document
  Future<Document?> loadCurrentDocument() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_currentDocKey);

    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return Document.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  // Save document to list
  Future<void> saveDocument(Document document) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> documentsList = prefs.getStringList(_documentsListKey) ?? [];

    // Remove existing document with same id if any
    documentsList.removeWhere((jsonString) {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return json['id'] == document.id;
    });

    // Add updated document
    documentsList.add(jsonEncode(document.toJson()));

    await prefs.setStringList(_documentsListKey, documentsList);
  }

  // Load all documents
  Future<List<Document>> loadAllDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> documentsList = prefs.getStringList(_documentsListKey) ?? [];

    return documentsList.map((jsonString) {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return Document.fromJson(json);
    }).toList()
      ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
  }

  // Clear all data (for testing)
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
