import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../util/constants.dart';
import '../error.dart';
import 'transport.dart';

/// WebSocket transport implementation for Bayeux protocol
class WebSocketTransport extends BaseTransport {
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
          if (connected) return;
    
    final startTime = DateTime.now();
    
    try {
      _url = url;
      _headers = headers ?? {};
      
      // Convert HTTP URL to WebSocket URL
      final wsUrl = _convertToWebSocketUrl(url);
      
      // Create WebSocket connection
      _channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        protocols: _protocols,
      );
      
      // Listen for messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );
      
      // Wait for connection to be established
      await _waitForConnection();
      
              updateConnectionState(true);
        recordConnectTime(DateTime.now().difference(startTime).inMilliseconds);
      
      // Start heartbeat
      _startHeartbeat();
      
      // Reset reconnection attempts
      _reconnectAttempts = 0;
      
    } catch (e) {
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
          if (!connected || _channel == null) {
        throw FayeError.network('Not connected');
      }
      
      try {
        final jsonMessage = jsonEncode(message);
        _channel!.sink.add(jsonMessage);
        recordMessageSent(message);
      } catch (e) {
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
    final uri = Uri.parse(url);
    
    if (uri.scheme == 'https') {
      return 'wss://${uri.authority}${uri.path}${uri.query.isNotEmpty ? '?${uri.query}' : ''}';
    } else {
      return 'ws://${uri.authority}${uri.path}${uri.query.isNotEmpty ? '?${uri.query}' : ''}';
    }
  }
  
  /// Wait for WebSocket connection to be established
  Future<void> _waitForConnection() async {
    // WebSocket connection is established when the channel is created
    // We'll wait a short time to ensure the connection is ready
    await Future.delayed(Duration(milliseconds: 100));
  }
  
  /// Handle incoming WebSocket message
  void _handleMessage(dynamic data) {
    try {
      Map<String, dynamic> message;
      
      if (data is String) {
        message = jsonDecode(data) as Map<String, dynamic>;
      } else if (data is Map<String, dynamic>) {
        message = data;
      } else {
        throw FormatException('Invalid message format: $data');
      }
      
      emitMessage(message);
    } catch (e) {
      emitError(FayeError.protocol('Failed to parse message: $e'));
    }
  }
  
  /// Handle WebSocket error
  void _handleError(dynamic error) {
    emitError(FayeError.network('WebSocket error: $error'));
  }
  
  /// Handle WebSocket disconnect
  void _handleDisconnect() {
    updateConnectionState(false);
    _stopHeartbeat();
    
    // Attempt reconnection if enabled
    if (_autoReconnect && _reconnectAttempts < _maxReconnectAttempts) {
      _scheduleReconnect();
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
    
    _heartbeatTimer = Timer.periodic(Duration(milliseconds: _heartbeatInterval), (timer) {
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
