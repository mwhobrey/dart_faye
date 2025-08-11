import 'dart:async';
import '../error.dart';
import '../transport/transport.dart';
import '../transport/http_transport.dart';
import '../transport/websocket_transport.dart';

/// Dispatcher for handling Bayeux protocol messages
class Dispatcher {
  /// Client ID
  String? _clientId;
  
  /// Current state
  int _state = 1; // unconnected
  
  /// Message ID counter
  int _messageId = 0;
  
  /// Response callbacks
  final Map<String, Completer<Map<String, dynamic>>> _responseCallbacks = {};
  
  /// Current transport
  Transport? _transport;
  
  /// Available transports
  final List<Transport> _transports = [];
  
  /// Connection advice
  Map<String, dynamic> _advice = {
    'reconnect': 'retry',
    'interval': 1000,
    'timeout': 60000,
  };
  
  /// Connection endpoint
  final String _endpoint;
  
  /// Message stream controller
  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  /// State change stream controller
  final StreamController<int> _stateController = 
      StreamController<int>.broadcast();
  
  /// Error stream controller
  final StreamController<FayeError> _errorController = 
      StreamController<FayeError>.broadcast();
  

  
  Dispatcher(this._endpoint, Map<String, dynamic> options) {
    _initializeTransports();
  }
  
  /// Get current state
  int get state => _state;
  
  /// Get client ID
  String? get clientId => _clientId;
  
  /// Get current transport
  Transport? get transport => _transport;
  
  /// Get message stream
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  
  /// Get state change stream
  Stream<int> get stateStream => _stateController.stream;
  
  /// Get error stream
  Stream<FayeError> get errorStream => _errorController.stream;
  
  /// Initialize available transports
  void _initializeTransports() {
    // Add HTTP transport
    final httpTransport = HttpTransport();
    _transports.add(httpTransport);
    
    // Add WebSocket transport if supported
    final wsTransport = WebSocketTransport();
    if (wsTransport.supported) {
      _transports.add(wsTransport);
    }
    
    // Set default transport
    _transport = _transports.first;
  }
  
  /// Set transport
  void setTransport(String transportName) {
    final transport = _transports.firstWhere(
      (t) => t.name == transportName,
      orElse: () => throw ArgumentError('Transport not found: $transportName'),
    );
    
    if (_transport != transport) {
      _transport = transport;
    }
  }
  
  /// Update state
  void _updateState(int newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }
  
  /// Generate message ID
  String _generateMessageId() {
    _messageId = (_messageId + 1) % 9007199254740991; // 2^53 - 1
    return _messageId.toString();
  }
  

  
  /// Connect to server
  Future<void> connect({Map<String, String>? headers}) async {
          if (_state != 1) return; // unconnected
      
      _updateState(2); // connecting
    
    try {
      // Perform handshake
              await _handshake(headers: headers);
        
        // Connect transport
        await _connectTransport(headers: headers);
      
              _updateState(3); // connected
      } catch (e) {
        _updateState(4); // disconnected
      _emitError(FayeError.network('Connection failed: $e'));
      rethrow;
    }
  }
  
  /// Disconnect from server
  Future<void> disconnect() async {
          if (_state == 1) return; // unconnected
      
      _updateState(4); // disconnected
    
    // Send disconnect message
    if (_clientId != null) {
      try {
        await _sendMessage({
          'channel': '/meta/disconnect',
          'clientId': _clientId,
        });
      } catch (e) {
        // Ignore disconnect errors
      }
    }
    
    // Disconnect transport
    await _transport?.disconnect();
    
    _clientId = null;
          _updateState(1); // unconnected
  }
  
  /// Perform handshake
  Future<void> _handshake({Map<String, String>? headers}) async {
    final message = {
      'channel': '/meta/handshake',
              'version': '1.0',
      'supportedConnectionTypes': _transports.map((t) => t.name).toList(),
      'id': _generateMessageId(),
    };
    
    final response = await _sendMessage(message, headers: headers);
    
    if (response['successful'] == true) {
      _clientId = response['clientId'] as String?;
      
      // Update advice
      if (response['advice'] != null) {
        _advice.addAll(response['advice'] as Map<String, dynamic>);
      }
      
      // Set recommended transport
      if (response['supportedConnectionTypes'] != null) {
        final supportedTypes = response['supportedConnectionTypes'] as List<dynamic>;
        final recommendedType = supportedTypes.first as String;
        setTransport(recommendedType);
      }
    } else {
      throw FayeError.fromBayeux(response['error'] ?? {});
    }
  }
  
  /// Connect transport
  Future<void> _connectTransport({Map<String, String>? headers}) async {
    if (_transport == null) {
      throw FayeError.network('No transport available');
    }
    
    await _transport!.connect(_endpoint, headers: headers);
    
    // Listen for transport messages
    _transport!.messageStream.listen(_handleTransportMessage);
    _transport!.errorStream.listen(_emitError);
  }
  
  /// Send message
  Future<Map<String, dynamic>> _sendMessage(
    Map<String, dynamic> message, {
    Map<String, String>? headers,
  }) async {
    if (_transport == null) {
      throw FayeError.network('No transport available');
    }
    
    final messageId = message['id'] as String?;
    Completer<Map<String, dynamic>>? completer;
    
    if (messageId != null) {
      completer = Completer<Map<String, dynamic>>();
      _responseCallbacks[messageId] = completer;
    }
    
    try {
      await _transport!.send(message);
      
      if (completer != null) {
        return await completer.future.timeout(
          Duration(seconds: _transport!.timeout),
          onTimeout: () {
            _responseCallbacks.remove(messageId);
            throw FayeError.timeout('Message timeout: $messageId');
          },
        );
      }
      
      return <String, dynamic>{};
    } catch (e) {
      _responseCallbacks.remove(messageId);
      rethrow;
    }
  }
  
  /// Handle transport message
  void _handleTransportMessage(Map<String, dynamic> message) {
    final messageId = message['id'] as String?;
    
    // Check if this is a response to a pending request
    if (messageId != null && _responseCallbacks.containsKey(messageId)) {
      final completer = _responseCallbacks.remove(messageId)!;
      completer.complete(message);
      return;
    }
    
    // Emit message to listeners
    _messageController.add(message);
  }
  
  /// Emit error
  void _emitError(FayeError error) {
    _errorController.add(error);
  }
  
  /// Send connect message
  Future<void> sendConnect() async {
    if (_state != 3 || _clientId == null) { // connected
      throw FayeError.network('Not connected');
    }
    
    await _sendMessage({
      'channel': '/meta/connect',
      'clientId': _clientId,
      'connectionType': _transport?.name ?? 'long-polling',
    });
  }
  
  /// Send subscribe message
  Future<Map<String, dynamic>> subscribe(String channel) async {
    if (_state != 3 || _clientId == null) { // connected
      throw FayeError.network('Not connected');
    }
    
    return await _sendMessage({
      'channel': '/meta/subscribe',
      'clientId': _clientId,
      'subscription': channel,
      'id': _generateMessageId(),
    });
  }
  
  /// Send unsubscribe message
  Future<Map<String, dynamic>> unsubscribe(String channel) async {
    if (_state != 3 || _clientId == null) { // connected
      throw FayeError.network('Not connected');
    }
    
    return await _sendMessage({
      'channel': '/meta/unsubscribe',
      'clientId': _clientId,
      'subscription': channel,
      'id': _generateMessageId(),
    });
  }
  
  /// Send publish message
  Future<Map<String, dynamic>> publish(String channel, dynamic data) async {
    if (_state != 3 || _clientId == null) { // connected
      throw FayeError.network('Not connected');
    }
    
    return await _sendMessage({
      'channel': channel,
      'data': data,
      'clientId': _clientId,
      'id': _generateMessageId(),
    });
  }
  
  /// Close dispatcher
  Future<void> close() async {
    await disconnect();
    await _messageController.close();
    await _stateController.close();
    await _errorController.close();
    
    for (final transport in _transports) {
      await transport.close();
    }
  }
  
  /// Get dispatcher statistics
  Map<String, dynamic> get statistics {
    return {
      'state': _state,
      'clientId': _clientId,
      'transport': _transport?.name,
      'advice': _advice,
      'pendingCallbacks': _responseCallbacks.length,
      'transportStats': _transport?.statistics,
    };
  }
}
