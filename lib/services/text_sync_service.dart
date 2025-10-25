// Text synchronization service for controller/display setup over USB
// Controller (Mac): runs WebSocket server on localhost:8080
// Display (DC1): connects via adb forward (adb forward tcp:8080 tcp:8080)

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:uuid/uuid.dart';
import '../models/app_mode.dart';
import '../models/text_state.dart';

class TextSyncService extends ChangeNotifier {
  final String deviceId = const Uuid().v4();
  final AppMode mode;

  // WebSocket
  HttpServer? _server;
  WebSocketChannel? _channel;
  WebSocket? _currentClientSocket;

  // Controllers
  TextEditingController? _textController;

  // State management
  int _sequence = 0;
  bool _isApplyingRemote = false;
  Timer? _throttleTimer;
  Duration _throttleInterval = const Duration(milliseconds: 30);
  String _lastSentText = '';
  Offset? _mousePosition; // Current mouse position (controller only)
  Offset? get mousePosition => _mousePosition; // Expose to display
  double _scrollOffset = 0.0; // Current scroll position
  double? get scrollOffset => _scrollOffset; // Expose to display
  double _lastSentScrollOffset = 0.0;

  // Connection state
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  TextSyncService({required this.mode});

  // Initialize with text controller
  void initialize(TextEditingController textController) {
    _textController = textController;

    if (mode == AppMode.controller) {
      _textController!.addListener(_onLocalChange);
    }
  }

  // Start WebSocket server (Controller mode)
  Future<void> startServer() async {
    if (mode != AppMode.controller) return;

    try {
      _server = await HttpServer.bind('127.0.0.1', 8080);
      print('WebSocket server running on ws://127.0.0.1:8080');
      print('On Mac, run: adb reverse tcp:8080 tcp:8080');

      _server!.listen((HttpRequest request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          _currentClientSocket = await WebSocketTransformer.upgrade(request);
          _handleConnection(_currentClientSocket!);
        }
      });
    } catch (e) {
      print('Failed to start server: $e');
    }
  }

  // Connect as client (Display mode)
  Future<void> connectAsClient() async {
    if (mode != AppMode.display) return;

    try {
      print('Connecting to ws://127.0.0.1:8080 (via adb reverse)...');
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://127.0.0.1:8080'),
      );

      _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          print('WebSocket error: $error');
          _isConnected = false;
          notifyListeners();
          _reconnect();
        },
        onDone: () {
          print('WebSocket closed');
          _isConnected = false;
          notifyListeners();
          _reconnect();
        },
      );

      _isConnected = true;
      notifyListeners();
      print('Connected to controller');
    } catch (e) {
      print('Failed to connect: $e');
      _reconnect();
    }
  }

  void _handleConnection(WebSocket socket) {
    print('Display connected');
    _isConnected = true;
    notifyListeners();

    _channel = IOWebSocketChannel(socket);
    _channel!.stream.listen(
      _handleMessage,
      onError: (error) {
        print('Client error: $error');
        _isConnected = false;
        notifyListeners();
      },
      onDone: () {
        print('Display disconnected');
        _isConnected = false;
        notifyListeners();
      },
    );

    // Send initial state
    _sendUpdate();
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mode == AppMode.display && !_isConnected) {
        connectAsClient();
      }
    });
  }

  // Update mouse position (Controller only)
  void updateMousePosition(Offset position) {
    if (mode != AppMode.controller) return;
    _mousePosition = position;
    _scheduleUpdate();
  }

  // Update scroll position (Controller only)
  void updateScrollPosition(double offset) {
    if (mode != AppMode.controller) return;
    _scrollOffset = offset;
    _scheduleUpdate();
  }

  // Handle local text changes (Controller only)
  void _onLocalChange() {
    if (_isApplyingRemote || mode != AppMode.controller) return;
    _scheduleUpdate();
  }

  void _scheduleUpdate() {
    final textChanged = _textController!.text != _lastSentText;

    if (textChanged) {
      // Text changed: send immediately
      _throttleTimer?.cancel();
      _sendUpdate();
    } else {
      // Only cursor moved: throttle
      _throttleTimer?.cancel();
      _throttleTimer = Timer(_throttleInterval, _sendUpdate);
    }
  }

  void _sendUpdate() {
    if (_textController == null) {
      print('[SYNC] Cannot send: controller is null');
      return;
    }
    if (!_isConnected) {
      print('[SYNC] Cannot send: not connected');
      return;
    }

    final state = TextState(
      sequence: _sequence++,
      deviceId: deviceId,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      text: _textController!.text,
      selectionBase: _textController!.selection.baseOffset,
      selectionExtent: _textController!.selection.extentOffset,
      scrollOffset: _scrollOffset,
      mouseX: _mousePosition?.dx,
      mouseY: _mousePosition?.dy,
    );

    _lastSentText = _textController!.text;
    _lastSentScrollOffset = _scrollOffset;

    print('[SYNC] Sending update #${state.sequence}: "${state.text.substring(0, state.text.length > 50 ? 50 : state.text.length)}" | cursor: ${state.selectionBase}-${state.selectionExtent} | scroll: ${state.scrollOffset.toStringAsFixed(1)}');

    try {
      _channel?.sink.add(state.toJsonString());
    } catch (e) {
      print('Failed to send update: $e');
    }
  }

  // Handle incoming messages
  void _handleMessage(dynamic data) {
    if (_textController == null) return;

    try {
      final state = TextState.fromJsonString(data as String);

      // Ignore own echoes
      if (state.deviceId == deviceId) return;

      _applyUpdate(state);
    } catch (e) {
      print('Failed to handle message: $e');
    }
  }

  void _applyUpdate(TextState state) {
    print('[SYNC] Applying update #${state.sequence}: "${state.text.substring(0, state.text.length > 50 ? 50 : state.text.length)}" | cursor: ${state.selectionBase}-${state.selectionExtent} | scroll: ${state.scrollOffset.toStringAsFixed(1)}');

    _isApplyingRemote = true;

    try {
      // Apply text and selection atomically
      _textController!.value = TextEditingValue(
        text: state.text,
        selection: TextSelection(
          baseOffset: state.selectionBase.clamp(0, state.text.length),
          extentOffset: state.selectionExtent.clamp(0, state.text.length),
        ),
        composing: TextRange.empty, // Clear composing on Display
      );

      // Update mouse position for display rendering
      if (state.mouseX != null && state.mouseY != null) {
        _mousePosition = Offset(state.mouseX!, state.mouseY!);
      }

      // Update scroll position for display rendering
      _scrollOffset = state.scrollOffset;
    } finally {
      _isApplyingRemote = false;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    _textController?.removeListener(_onLocalChange);
    _channel?.sink.close();
    _server?.close();
    super.dispose();
  }
}
