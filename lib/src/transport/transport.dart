import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import '../error.dart';

/// Callback function for transport events
typedef TransportCallback = void Function(dynamic data);

/// Callback function for transport errors
typedef TransportErrorCallback = void Function(FayeError error);

/// Abstract base class for all transport implementations
abstract class Transport {
  /// Transport name
  String get name;
  
  /// Whether this transport is supported
  bool get supported;
  
  /// Whether this transport is currently connected
  bool get connected;
  
  /// Connection timeout in seconds
  int get timeout;
  
  /// Set connection timeout
  set timeout(int value);
  
  /// Stream of messages received from the transport
  Stream<Map<String, dynamic>> get messageStream;
  
  /// Stream of connection state changes
  Stream<bool> get connectionStateStream;
  
  /// Stream of errors
  Stream<FayeError> get errorStream;
  
  /// Connect to the server
  Future<void> connect(String url, {Map<String, String>? headers});
  
  /// Disconnect from the server
  Future<void> disconnect();
  
  /// Send a message to the server
  Future<void> send(Map<String, dynamic> message);
  
  /// Send multiple messages to the server
  Future<void> sendBatch(List<Map<String, dynamic>> messages);
  
  /// Close the transport
  Future<void> close();
  
  /// Get transport statistics
  Map<String, dynamic> get statistics;
}

/// Base implementation of Transport with common functionality
abstract class BaseTransport implements Transport {
  /// Logger
  static final Logger _logger = Logger('FayeBaseTransport');
  
  /// Connection timeout in seconds
  int _timeout = 30;
  
  /// Constructor
  BaseTransport() {
    _logger.info('BaseTransport: Creating base transport');
    _logger.info('BaseTransport: Default timeout: $_timeout seconds');
  }
  
  /// Whether the transport is connected
  bool _connected = false;
  
  /// Message controller
  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  /// Connection state controller
  final StreamController<bool> _connectionStateController = 
      StreamController<bool>.broadcast();
  
  /// Error controller
  final StreamController<FayeError> _errorController = 
      StreamController<FayeError>.broadcast();
  
  /// Statistics
  final Map<String, dynamic> _statistics = {
    'messagesSent': 0,
    'messagesReceived': 0,
    'errors': 0,
    'bytesSent': 0,
    'bytesReceived': 0,
    'connectTime': 0,
    'lastActivity': null,
  };
  
  @override
  bool get connected => _connected;
  
  @override
  int get timeout => _timeout;
  
  @override
  set timeout(int value) {
    _timeout = value;
  }
  
  @override
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  
  @override
  Stream<bool> get connectionStateStream => _connectionStateController.stream;
  
  @override
  Stream<FayeError> get errorStream => _errorController.stream;
  
  /// Update connection state
  @protected
  void updateConnectionState(bool connected) {
    _logger.info('BaseTransport: Updating connection state from $_connected to $connected');
    if (_connected != connected) {
      _connected = connected;
      _connectionStateController.add(connected);
      updateLastActivity();
      _logger.info('BaseTransport: Connection state updated to $connected');
    } else {
      _logger.info('BaseTransport: Connection state unchanged ($connected)');
    }
  }
  
  /// Emit a message
  @protected
  void emitMessage(Map<String, dynamic> message) {
    _logger.info('BaseTransport: Emitting message: $message');
    _messageController.add(message);
    _statistics['messagesReceived']++;
    _statistics['bytesReceived'] += jsonEncode(message).length;
    updateLastActivity();
  }
  
  /// Emit an error
  @protected
  void emitError(FayeError error) {
    _logger.severe('BaseTransport: Emitting error: $error');
    _errorController.add(error);
    _statistics['errors']++;
    updateLastActivity();
  }
  
  /// Update last activity timestamp
  @protected
  void updateLastActivity() {
    _statistics['lastActivity'] = DateTime.now().toIso8601String();
  }
  
  /// Record message sent
  @protected
  void recordMessageSent(Map<String, dynamic> message) {
    _statistics['messagesSent']++;
    _statistics['bytesSent'] += jsonEncode(message).length;
    updateLastActivity();
  }
  
  /// Record connection time
  @protected
  void recordConnectTime(int milliseconds) {
    _statistics['connectTime'] = milliseconds;
  }
  
  @override
  Map<String, dynamic> get statistics {
    return Map.from(_statistics);
  }
  
  @override
  Future<void> close() async {
    await disconnect();
    await _messageController.close();
    await _connectionStateController.close();
    await _errorController.close();
  }
  
  @override
  String toString() {
    return '${name}Transport(connected: $_connected)';
  }
}
