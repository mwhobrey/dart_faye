import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../util/constants.dart';
import '../error.dart';
import 'transport.dart';

/// WebSocket transport implementation for Bayeux protocol
class WebSocketTransport extends BaseTransport {
  /// Logger
  static final Logger _logger = Logger('FayeWebSocketTransport');

  /// Transport name
  @override
  String get name => 'websocket';

  /// Whether this transport is supported (always true for WebSocket)
  @override
  bool get supported => true;

  /// WebSocket channel
  WebSocketChannel? _channel;

  /// Current connection URL
  String? _url;

  /// WebSocket protocols
  List<String> _protocols = Constants.defaultWebSocketProtocols;

  /// Connection headers
  Map<String, String>? _headers;

  /// Constructor
  WebSocketTransport() {
    _logger.info('WebSocket: Creating WebSocket transport');
    _logger.info('WebSocket: Default protocols: $_protocols');
  }

  /// Reconnection settings
  bool _autoReconnect = true;
  int _reconnectAttempts = 0;
  int _maxReconnectAttempts = 5;
  int _reconnectDelay = 1000;
  Timer? _reconnectTimer;

  /// Heartbeat settings
  Timer? _heartbeatTimer;
  int _heartbeatInterval = Constants.defaultHeartbeatInterval;

  /// Set WebSocket protocols
  void setProtocols(List<String> protocols) {
    _protocols = protocols;
  }

  /// Set auto-reconnect settings
  void setAutoReconnect(bool enabled, {int maxAttempts = 5, int delay = 1000}) {
    _autoReconnect = enabled;
    _maxReconnectAttempts = maxAttempts;
    _reconnectDelay = delay;
  }

  /// Set heartbeat interval
  void setHeartbeatInterval(int interval) {
    _heartbeatInterval = interval;
  }

  @override
  Future<void> connect(String url, {Map<String, String>? headers}) async {
    _logger.info('WebSocket: Starting connection to $url');
    _logger.info('WebSocket: Current connected state: $connected');

    if (connected) {
      _logger.info('WebSocket: Already connected, skipping connection');
      return;
    }

    final startTime = DateTime.now();

    try {
      _url = url;
      _headers = headers ?? {};
      _logger.info('WebSocket: URL set to $_url');
      _logger.info('WebSocket: Headers: $_headers');

      // Convert HTTP URL to WebSocket URL
      final wsUrl = _convertToWebSocketUrl(url);
      _logger.info('WebSocket: Converted URL: $wsUrl');

      // Create WebSocket connection
      _logger.info('WebSocket: Creating WebSocketChannel...');
      _logger.info('WebSocket: URL: $wsUrl');
      _logger.info('WebSocket: Protocols: $_protocols');
      try {
        _channel = WebSocketChannel.connect(
          Uri.parse(wsUrl),
          // Don't specify protocols - let the server choose
        );
        _logger.info('WebSocket: WebSocketChannel created successfully');
      } catch (e) {
        _logger.severe('WebSocket: Failed to create WebSocketChannel: $e');
        rethrow;
      }

      // Listen for messages
      _logger.info('WebSocket: Setting up message listeners...');
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );
      _logger.info('WebSocket: Message listeners configured');

      // Wait for connection to be established
      _logger.info('WebSocket: Waiting for connection to establish...');
      await _waitForConnection();
      _logger.info('WebSocket: Connection established');

      updateConnectionState(true);
      recordConnectTime(DateTime.now().difference(startTime).inMilliseconds);
      _logger.info('WebSocket: Connection state updated to connected');

      // Start heartbeat
      _logger.info('WebSocket: Starting heartbeat...');
      _startHeartbeat();

      // Reset reconnection attempts
      _reconnectAttempts = 0;
      _logger.info('WebSocket: Connection completed successfully');
    } catch (e) {
      _logger.severe('WebSocket: Connection failed: $e');
      emitError(FayeError.network('Failed to connect: $e'));
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    if (!connected) return;

    _stopHeartbeat();
    _stopReconnect();

    if (_channel != null) {
      await _channel!.sink.close(status.goingAway);
      _channel = null;
    }

    updateConnectionState(false);
  }

  @override
  Future<void> send(Map<String, dynamic> message) async {
    _logger.info('WebSocket: Sending message: $message');
    _logger.info(
        'WebSocket: Connected state: $connected, Channel: ${_channel != null}');

    if (!connected || _channel == null) {
      _logger.severe('WebSocket: Cannot send message - not connected');
      throw FayeError.network('Not connected');
    }

    try {
      final jsonMessage = jsonEncode(message);
      _logger.info('WebSocket: Sending JSON: $jsonMessage');
      _channel!.sink.add(jsonMessage);
      recordMessageSent(message);
      _logger.info('WebSocket: Message sent successfully');
    } catch (e) {
      _logger.severe('WebSocket: Failed to send message: $e');
      emitError(FayeError.network('Failed to send message: $e'));
      rethrow;
    }
  }

  @override
  Future<void> sendBatch(List<Map<String, dynamic>> messages) async {
    if (!connected || _channel == null) {
      throw FayeError.network('Not connected');
    }

    try {
      final jsonMessages = jsonEncode(messages);
      _channel!.sink.add(jsonMessages);

      for (final message in messages) {
        recordMessageSent(message);
      }
    } catch (e) {
      emitError(FayeError.network('Failed to send batch: $e'));
      rethrow;
    }
  }

  /// Convert HTTP URL to WebSocket URL
  String _convertToWebSocketUrl(String url) {
    _logger.info('WebSocket: Converting URL: $url');
    final uri = Uri.parse(url);
    _logger.info(
        'WebSocket: Parsed URI - scheme: ${uri.scheme}, authority: ${uri.authority}, path: ${uri.path}');

    String wsUrl;
    if (uri.scheme == 'https' || uri.scheme == 'wss') {
      wsUrl =
          'wss://${uri.authority}${uri.path}${uri.query.isNotEmpty ? '?${uri.query}' : ''}';
    } else {
      wsUrl =
          'ws://${uri.authority}${uri.path}${uri.query.isNotEmpty ? '?${uri.query}' : ''}';
    }

    _logger.info('WebSocket: Converted to WebSocket URL: $wsUrl');
    return wsUrl;
  }

  /// Wait for WebSocket connection to be established
  Future<void> _waitForConnection() async {
    _logger.info('WebSocket: Waiting for connection to establish...');
    // WebSocket connection is established when the channel is created
    // We'll wait a short time to ensure the connection is ready
    await Future.delayed(Duration(milliseconds: 100));
    _logger.info('WebSocket: Connection wait completed');
  }

  /// Handle incoming WebSocket message
  void _handleMessage(dynamic data) {
    _logger.info('WebSocket: Received message: $data');
    _logger.info('WebSocket: Data type: ${data.runtimeType}');
    _logger.info('WebSocket: Data is String: ${data is String}');
    _logger.info('WebSocket: Data is Map: ${data is Map<String, dynamic>}');
    _logger.info(
        'WebSocket: Data length: ${data is String ? data.length : 'N/A'}');


    try {
      if (data is String) {
        _logger.info('WebSocket: Parsing string message');
        final decoded = jsonDecode(data);

        if (decoded is List) {
          _logger.info(
              'WebSocket: Received batch message with ${decoded.length} items');
          // Handle batch messages (array of messages)
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              _logger.info('WebSocket: Emitting batch message item: $item');
              _logger.info('WebSocket: Item type: ${item.runtimeType}');
              emitMessage(item);
            } else {
              _logger
                  .warning('WebSocket: Skipping non-map item in batch: $item');
            }
          }
        } else if (decoded is Map<String, dynamic>) {
          _logger.info('WebSocket: Emitting single message: $decoded');
          _logger.info('WebSocket: Message type: ${decoded.runtimeType}');
          emitMessage(decoded);
        } else {
          _logger.warning(
              'WebSocket: Received non-map/non-list decoded message: $decoded (type: ${decoded.runtimeType})');
          // Convert other types to a map format for compatibility
          final messageMap = <String, dynamic>{
            'data': decoded,
            'type': decoded.runtimeType.toString(),
          };
          _logger.info('WebSocket: Converting to map format: $messageMap');
          emitMessage(messageMap);
        }
      } else if (data is Map<String, dynamic>) {
        _logger.info('WebSocket: Using map message directly');
        emitMessage(data);
      } else {
        _logger.warning(
            'WebSocket: Received non-string/non-map data: $data (type: ${data.runtimeType})');
        // Convert other types to a map format for compatibility
        final messageMap = <String, dynamic>{
          'data': data,
          'type': data.runtimeType.toString(),
        };
        _logger.info('WebSocket: Converting to map format: $messageMap');
        emitMessage(messageMap);
      }
    } catch (e) {
      _logger.severe('WebSocket: Failed to parse message: $e');
      _logger.severe('WebSocket: Original data was: $data');
      _logger.severe('WebSocket: Data type was: ${data.runtimeType}');
      emitError(FayeError.protocol('Failed to parse message: $e'));
    }
  }

  /// Handle WebSocket error
  void _handleError(dynamic error) {
    _logger.severe('WebSocket: Error occurred: $error');
    _logger.severe('WebSocket: Error type: ${error.runtimeType}');
    _logger.severe('WebSocket: Error details: ${error.toString()}');
    if (error is Exception) {
      _logger.severe('WebSocket: Exception details: ${error.toString()}');
    }
    emitError(FayeError.network('WebSocket error: $error'));
  }

  /// Handle WebSocket disconnect
  void _handleDisconnect() {
    _logger.info('WebSocket: Disconnect event received');
    updateConnectionState(false);
    _stopHeartbeat();

    // Attempt reconnection if enabled
    if (_autoReconnect && _reconnectAttempts < _maxReconnectAttempts) {
      _logger.info(
          'WebSocket: Scheduling reconnection attempt ${_reconnectAttempts + 1}');
      _scheduleReconnect();
    } else {
      _logger.info(
          'WebSocket: No reconnection scheduled (autoReconnect: $_autoReconnect, attempts: $_reconnectAttempts)');
    }
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(milliseconds: _reconnectDelay), () {
      _attemptReconnect();
    });
  }

  /// Attempt to reconnect
  Future<void> _attemptReconnect() async {
    if (_url == null) return;

    try {
      await connect(_url!, headers: _headers);
    } catch (e) {
      emitError(FayeError.network('Reconnection failed: $e'));

      // Schedule next reconnection attempt with exponential backoff
      if (_reconnectAttempts < _maxReconnectAttempts) {
        _reconnectDelay = (_reconnectDelay * 1.5).round();
        _scheduleReconnect();
      }
    }
  }

  /// Stop reconnection attempts
  void _stopReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Start heartbeat
  void _startHeartbeat() {
    if (_heartbeatInterval <= 0) return;

    _heartbeatTimer =
        Timer.periodic(Duration(milliseconds: _heartbeatInterval), (timer) {
      _sendHeartbeat();
    });
  }

  /// Stop heartbeat
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Send heartbeat message
  void _sendHeartbeat() {
    if (!connected || _channel == null) return;

    try {
      final heartbeat = {
        'channel': '/meta/connect',
        'clientId': 'temp', // Will be replaced by actual client ID
        'connectionType': 'websocket',
      };

      _channel!.sink.add(jsonEncode(heartbeat));
    } catch (e) {
      emitError(FayeError.network('Failed to send heartbeat: $e'));
    }
  }

  @override
  Future<void> close() async {
    _stopHeartbeat();
    _stopReconnect();

    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }

    await super.close();
  }

  @override
  Map<String, dynamic> get statistics {
    final stats = super.statistics;
    stats['protocols'] = _protocols;
    stats['autoReconnect'] = _autoReconnect;
    stats['reconnectAttempts'] = _reconnectAttempts;
    stats['maxReconnectAttempts'] = _maxReconnectAttempts;
    stats['heartbeatInterval'] = _heartbeatInterval;
    return stats;
  }
}
