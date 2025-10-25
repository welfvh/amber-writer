// Text state for synchronization between controller and display
// Contains all TextEditingValue data plus scroll position

import 'dart:convert';

class TextState {
  final int sequence;
  final String deviceId;
  final int timestampMs;
  final String text;
  final int selectionBase;
  final int selectionExtent;
  final double scrollOffset;
  final double? mouseX; // Mouse cursor X position (nullable)
  final double? mouseY; // Mouse cursor Y position (nullable)

  TextState({
    required this.sequence,
    required this.deviceId,
    required this.timestampMs,
    required this.text,
    required this.selectionBase,
    required this.selectionExtent,
    required this.scrollOffset,
    this.mouseX,
    this.mouseY,
  });

  Map<String, dynamic> toJson() => {
        'sequence': sequence,
        'deviceId': deviceId,
        'timestampMs': timestampMs,
        'text': text,
        'selectionBase': selectionBase,
        'selectionExtent': selectionExtent,
        'scrollOffset': scrollOffset,
        if (mouseX != null) 'mouseX': mouseX,
        if (mouseY != null) 'mouseY': mouseY,
      };

  factory TextState.fromJson(Map<String, dynamic> json) => TextState(
        sequence: json['sequence'] as int,
        deviceId: json['deviceId'] as String,
        timestampMs: json['timestampMs'] as int,
        text: json['text'] as String,
        selectionBase: json['selectionBase'] as int,
        selectionExtent: json['selectionExtent'] as int,
        scrollOffset: (json['scrollOffset'] as num).toDouble(),
        mouseX: json['mouseX'] != null ? (json['mouseX'] as num).toDouble() : null,
        mouseY: json['mouseY'] != null ? (json['mouseY'] as num).toDouble() : null,
      );

  String toJsonString() => jsonEncode(toJson());

  factory TextState.fromJsonString(String jsonString) =>
      TextState.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
}
