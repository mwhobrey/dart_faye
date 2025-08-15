import 'dart:async';
import 'package:logging/logging.dart';
import '../error.dart';
import '../transport/transport.dart';
import '../transport/http_transport.dart';
import '../transport/websocket_transport.dart';
import 'dart:convert'; // Added for jsonDecode

/// Dispatcher for handling Bayeux protocol messages
class Dispatcher {
  /// Logger
  static final Logger _logger = Logger('FayeDispatcher');

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
    _logger.info('Dispatcher: Creating dispatcher for endpoint: $_endpoint');
    _logger.info('Dispatcher: Options: $options');
    _initializeTransports();
    _logger.info('Dispatcher: Dispatcher created successfully');
  }

  /// Extract the first message from a Bayeux response
  /// Bayeux responses can be either a single object or an array of objects
  Map<String, dynamic> extractBayeuxMessage(dynamic response) {
    _logger.info('Dispatcher: extractBayeuxMessage called with response: $response');
    _logger.info('Dispatcher: Response type: ${response.runtimeType}');
    
    if (response is String) {
      // Parse string response as JSON
      try {
        _logger.info('Dispatcher: Parsing string response as JSON');
        final decoded = jsonDecode(response);
        _logger.info('Dispatcher: Decoded response: $decoded');
        _logger.info('Dispatcher: Decoded type: ${decoded.runtimeType}');
        
        if (decoded is List) {
          if (decoded.isEmpty) {
            throw FayeError.network('Empty response array from server');
          }
          final firstItem = decoded.first;
          _logger.info('Dispatcher: First item from list: $firstItem');
          _logger.info('Dispatcher: First item type: ${firstItem.runtimeType}');
          
          if (firstItem is Map<String, dynamic>) {
            return firstItem;
          } else {
            throw FayeError.network(
                'Invalid first item type in response array: ${firstItem.runtimeType}');
          }
        } else if (decoded is Map<String, dynamic>) {
          return decoded;
        } else {
          throw FayeError.network(
              'Invalid decoded response type: ${decoded.runtimeType}');
        }
      } catch (e) {
        _logger.severe('Dispatcher: Failed to parse response as JSON: $e');
        throw FayeError.network('Failed to parse response as JSON: $e');
      }
    } else if (response is List) {
      if (response.isEmpty) {
        throw FayeError.network('Empty response array from server');
      }
      final firstItem = response.first;
      _logger.info('Dispatcher: First item from list: $firstItem');
      _logger.info('Dispatcher: First item type: ${firstItem.runtimeType}');
      
      if (firstItem is Map<String, dynamic>) {
        return firstItem;
      } else {
        throw FayeError.network(
            'Invalid first item type in response array: ${firstItem.runtimeType}');
      }
    } else if (response is Map<String, dynamic>) {
      return response;
    } else {
      _logger.severe('Dispatcher: Invalid response type: ${response.runtimeType}');
      throw FayeError.network(
          'Invalid response type from server: ${response.runtimeType}');
    }
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
    _logger.info('Dispatcher: Initializing transports...');

    // Add HTTP transport
    final httpTransport = HttpTransport();
    _transports.add(httpTransport);
    _logger.info('Dispatcher: Added HTTP transport: ${httpTransport.name}');

    // Add WebSocket transport if supported
    final wsTransport = WebSocketTransport();
    if (wsTransport.supported) {
      _transports.add(wsTransport);
      _logger
          .info('Dispatcher: Added WebSocket transport: ${wsTransport.name}');
    } else {
      _logger.warning('Dispatcher: WebSocket transport not supported');
    }

    // Set default transport
    _transport = _transports.first;
    _logger.info('Dispatcher: Set default transport: ${_transport?.name}');
    _logger.info(
        'Dispatcher: Available transports: ${_transports.map((t) => t.name).toList()}');
  }

  /// Set transport
  void setTransport(String transportName) {
    _logger.info('Dispatcher: Setting transport to: $transportName');
    _logger.info(
        'Dispatcher: Available transports: ${_transports.map((t) => t.name).toList()}');

    final transport = _transports.firstWhere(
      (t) => t.name == transportName,
      orElse: () => throw ArgumentError('Transport not found: $transportName'),
    );

    if (_transport != transport) {
      _logger.info(
          'Dispatcher: Changing transport from ${_transport?.name} to ${transport.name}');
      _transport = transport;
    } else {
      _logger.info('Dispatcher: Transport unchanged (${transport.name})');
    }
  }

  /// Update state
  void _updateState(int newState) {
    _logger.info('Dispatcher: Updating state from $_state to $newState');
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
      _logger.info('Dispatcher: State updated and broadcasted');
    } else {
      _logger.info('Dispatcher: State unchanged ($newState)');
    }
  }

  /// Generate message ID
  String _generateMessageId() {
    _messageId = (_messageId + 1) % 9007199254740991; // 2^53 - 1
    final messageId = _messageId.toString();
    _logger.info('Dispatcher: Generated message ID: $messageId');
    return messageId;
  }

  /// Connect to server
  Future<void> connect({Map<String, String>? headers}) async {
    _logger.info('Dispatcher: Starting connection to $_endpoint');
    _logger.info('Dispatcher: Current state: $_state');

    if (_state != 1) {
      _logger.warning(
          'Dispatcher: Cannot connect, not in unconnected state. Current state: $_state');
      return; // unconnected
    }

    _logger.info('Dispatcher: Updating state to connecting (2)');
    _updateState(2); // connecting

    try {
      _logger.info('Dispatcher: Starting transport connection...');
      // Connect transport first
      await _connectTransport(headers: headers);
      _logger.info('Dispatcher: Transport connection completed');

      _logger.info('Dispatcher: Starting handshake...');
      // Perform handshake after transport is connected
      await _handshake(headers: headers);
      _logger.info('Dispatcher: Handshake completed successfully');

      _logger.info('Dispatcher: Updating state to connected (3)');
      _updateState(3); // connected
      _logger.info('Dispatcher: Connection completed successfully');
    } catch (e) {
      _logger.severe('Dispatcher: Connection failed with error: $e');
      _logger.severe('Dispatcher: Updating state to disconnected (4)');
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
    _logger.info('Dispatcher: Starting handshake...');

    final message = {
      'channel': '/meta/handshake',
      'version': '1.0',
      'supportedConnectionTypes': _transports.map((t) => t.name).toList(),
      'id': _generateMessageId(),
    };

    _logger.info('Dispatcher: Handshake message: $message');
    _logger.info(
        'Dispatcher: Available transports: ${_transports.map((t) => t.name).toList()}');

    final response = await _sendMessage(message, headers: headers);
    _logger.info('Dispatcher: Handshake response: $response');

    // Extract the first message from Bayeux response
    final responseMessage = extractBayeuxMessage(response);

    // Apply extension to handshake response if available
    Map<String, dynamic> processedResponse = responseMessage;
    if (_extension != null) {
      try {
        _logger.info(
            'Dispatcher: Applying extension to handshake response: $response');
        _logger.info('Dispatcher: Extension type: ${_extension.runtimeType}');
        _logger.info(
            'Dispatcher: Extension methods: ${_extension.runtimeType.toString()}');
        _logger.info('Dispatcher: Extension object: $_extension');
        processedResponse = _extension.incoming(response);
        _logger.info('Dispatcher: Extension returned: $processedResponse');
        _logger.info('Dispatcher: Applied extension to handshake response');
      } catch (e) {
        _logger.warning('Dispatcher: Extension processing failed: $e');
        _logger.warning(
            'Dispatcher: Extension error stack trace: ${e.toString()}');
      }
    } else {
      _logger.info('Dispatcher: No extension available for handshake response');
    }

    if (processedResponse['successful'] == true) {
      _clientId = processedResponse['clientId'] as String?;
      _logger.info('Dispatcher: Handshake successful, clientId: $_clientId');

      // Update advice
      if (processedResponse['advice'] != null) {
        _advice.addAll(processedResponse['advice'] as Map<String, dynamic>);
        _logger.info('Dispatcher: Updated advice: $_advice');
      }

      // Set recommended transport (but only if we support it)
      if (processedResponse['supportedConnectionTypes'] != null) {
        final supportedTypes =
            processedResponse['supportedConnectionTypes'] as List<dynamic>;
        final recommendedType = supportedTypes.first as String;
        _logger
            .info('Dispatcher: Server recommended transport: $recommendedType');

        // Only switch to recommended transport if we support it
        final availableTransportNames = _transports.map((t) => t.name).toList();
        if (availableTransportNames.contains(recommendedType)) {
          _logger.info(
              'Dispatcher: Setting recommended transport: $recommendedType');
          setTransport(recommendedType);
        } else {
          _logger.info(
              'Dispatcher: Recommended transport $recommendedType not available, keeping current transport: ${_transport?.name}');
        }
      }
    } else {
      _logger.severe(
          'Dispatcher: Handshake failed: ${processedResponse['error']}');
      throw FayeError.fromBayeux(processedResponse['error'] ?? {});
    }
  }

  /// Connect transport
  Future<void> _connectTransport({Map<String, String>? headers}) async {
    _logger.info('Dispatcher: Connecting transport...');
    _logger.info('Dispatcher: Current transport: ${_transport?.name}');
    _logger.info('Dispatcher: Endpoint: $_endpoint');

    if (_transport == null) {
      _logger.severe('Dispatcher: No transport available');
      throw FayeError.network('No transport available');
    }

    _logger.info(
        'Dispatcher: Attempting to connect transport ${_transport!.name} to $_endpoint');
    await _transport!.connect(_endpoint, headers: headers);
    _logger.info('Dispatcher: Transport connected successfully');

    // Listen for transport messages
    _logger.info('Dispatcher: Setting up transport message listeners');
    _transport!.messageStream.listen(_handleTransportMessage);
    _transport!.errorStream.listen(_emitError);
    _logger.info('Dispatcher: Transport listeners configured');
  }

  /// Send message
  Future<Map<String, dynamic>> _sendMessage(
    Map<String, dynamic> message, {
    Map<String, String>? headers,
  }) async {
    _logger.info('Dispatcher: Sending message: $message');


    if (_transport == null) {
      _logger.severe('Dispatcher: No transport available for sending message');
      throw FayeError.network('No transport available');
    }

    final messageId = message['id'] as String?;
    Completer<Map<String, dynamic>>? completer;

    if (messageId != null) {
      completer = Completer<Map<String, dynamic>>();
      _responseCallbacks[messageId] = completer;
      _logger.info('Dispatcher: Waiting for response to message $messageId');
      _logger.info('Dispatcher: Created completer for message $messageId');
    }

    try {
      _logger.info(
          'Dispatcher: Sending message via transport ${_transport!.name}');
      await _transport!.send(message);
      _logger.info('Dispatcher: Message sent successfully');

      if (completer != null) {
        _logger.info(
            'Dispatcher: Waiting for response with timeout: ${_transport!.timeout}s');
        final response = await completer.future.timeout(
          Duration(seconds: _transport!.timeout),
          onTimeout: () {
            _logger.severe('Dispatcher: Message timeout for $messageId');
            _responseCallbacks.remove(messageId);
            throw FayeError.timeout('Message timeout: $messageId');
          },
        );
        _logger.info('Dispatcher: Received response: $response');
        _logger.info('Dispatcher: Response type: ${response.runtimeType}');
        return response;
      }

      _logger.info('Dispatcher: No response expected, returning empty map');
      return <String, dynamic>{};
    } catch (e) {
      _logger.severe('Dispatcher: Failed to send message: $e');
      if (messageId != null) {
        _responseCallbacks.remove(messageId);
      }
      rethrow;
    }
  }

  /// Handle transport message
  void _handleTransportMessage(dynamic message) {
    _logger.info('Dispatcher: Received transport message: $message');
    _logger.info('Dispatcher: Message type: ${message.runtimeType}');
    
    // Handle string messages by parsing them
    if (message is String) {
      _logger.info('Dispatcher: Received string message, parsing as JSON');
      try {
        final decoded = jsonDecode(message);
        _logger.info('Dispatcher: Decoded message: $decoded');
        _logger.info('Dispatcher: Decoded type: ${decoded.runtimeType}');
        
        if (decoded is Map<String, dynamic>) {
          _handleTransportMessage(decoded);
          return;
        } else if (decoded is List) {
          // Handle array of messages
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              _handleTransportMessage(item);
            } else {
              _logger.warning('Dispatcher: Skipping non-map item in array: $item');
            }
          }
          return;
        } else {
          _logger.warning('Dispatcher: Unexpected decoded type: ${decoded.runtimeType}');
          return;
        }
      } catch (e) {
        _logger.severe('Dispatcher: Failed to parse string message: $e');
        _emitError(FayeError.protocol('Failed to parse message: $e'));
        return;
      }
    }
    
    // Ensure message is a Map
    if (message is! Map<String, dynamic>) {
      _logger.severe('Dispatcher: Invalid message type: ${message.runtimeType}');
      _emitError(FayeError.protocol('Invalid message type: ${message.runtimeType}'));
      return;
    }
    
    _logger.info('Dispatcher: Message keys: ${message.keys.toList()}');

    final messageId = message['id'] as String?;
    _logger.info('Dispatcher: Message ID: $messageId');

    // Check if this is a response to a pending request
    if (messageId != null && _responseCallbacks.containsKey(messageId)) {
      _logger.info('Dispatcher: Found pending callback for message $messageId');
      final completer = _responseCallbacks.remove(messageId)!;
      _logger.info(
          'Dispatcher: About to complete callback with message: $message');
      _logger.info('Dispatcher: Completer is completed: ${completer.isCompleted}');
      
      // Check if this is an error response
      if (message['successful'] == false) {
        _logger.warning('Dispatcher: Error response received: ${message['error']}');
      }
      
      completer.complete(message);
      _logger.info('Dispatcher: Completed callback for message $messageId');
      return;
    } else if (messageId != null) {
      _logger.info('Dispatcher: No pending callback found for message $messageId');
      _logger.info('Dispatcher: Available callbacks: ${_responseCallbacks.keys.toList()}');
    }

    // Emit message to listeners
    _logger.info('Dispatcher: Emitting message to listeners');
    _messageController.add(message);
  }

  /// Emit error
  void _emitError(FayeError error) {
    _logger.severe('Dispatcher: Emitting error: $error');
    _errorController.add(error);
  }

  /// Send connect message
  Future<void> sendConnect() async {
    _logger.info('Dispatcher: Sending connect message');
    _logger.info('Dispatcher: Current state: $_state, clientId: $_clientId');

    if (_state != 3 || _clientId == null) {
      // connected
      _logger.severe(
          'Dispatcher: Cannot send connect - not connected or no clientId. State: $_state, clientId: $_clientId');
      throw FayeError.network('Not connected');
    }

    final message = {
      'channel': '/meta/connect',
      'clientId': _clientId,
      'connectionType': _transport?.name ?? 'long-polling',
    };

    _logger.info('Dispatcher: Sending connect message: $message');
    await _sendMessage(message);
  }

  /// Send subscribe message
  Future<Map<String, dynamic>> subscribe(String channel) async {
    _logger.info('Dispatcher: Subscribing to channel: $channel');
    _logger.info('Dispatcher: Current state: $_state, clientId: $_clientId');


    // Allow subscriptions during connecting state (2) as well as connected state (3)
    // This is needed because extensions may try to subscribe during handshake response processing
    if ((_state != 3 && _state != 2) || _clientId == null) {
      // connected or connecting
      _logger.severe(
          'Dispatcher: Cannot subscribe - not connected/connecting or no clientId. State: $_state, clientId: $_clientId');
      throw FayeError.network('Not connected');
    }

    final message = {
      'channel': '/meta/subscribe',
      'clientId': _clientId,
      'subscription': channel,
      'id': _generateMessageId(),
    };

    // Apply extension if available
    Map<String, dynamic> processedMessage = message;
    if (_extension != null) {
      try {
        _logger.info('Dispatcher: Original subscription message: $message');
        processedMessage = _extension.outgoing(message);
        _logger.info('Dispatcher: Extension returned: $processedMessage');
        _logger.info('Dispatcher: Applied extension to subscription message');
      } catch (e) {
        _logger.warning('Dispatcher: Extension processing failed: $e');
      }
    }

    _logger.info('Dispatcher: Subscribing with message: $processedMessage');
    final response = await _sendMessage(processedMessage);
    _logger.info('Dispatcher: Subscribe response: $response');
    _logger.info('Dispatcher: Subscribe response type: ${response.runtimeType}');
    return response;
  }

  /// Send unsubscribe message
  Future<Map<String, dynamic>> unsubscribe(String channel) async {
    if (_state != 3 || _clientId == null) {
      // connected
      throw FayeError.network('Not connected');
    }

    return await _sendMessage({
      'channel': '/meta/unsubscribe',
      'clientId': _clientId,
      'subscription': channel,
      'id': _generateMessageId(),
    });
  }

  /// Extension for message processing
  dynamic _extension;

  /// Get extension for message processing
  dynamic get extension => _extension;

  /// Set extension for message processing
  void setExtension(dynamic extension) {
    _extension = extension;
    _logger.info('Dispatcher: Extension set: $extension');
    _logger.info('Dispatcher: Extension type: ${extension.runtimeType}');
    _logger.info(
        'Dispatcher: Extension methods: ${extension.runtimeType.toString()}');
  }

  /// Send publish message
  Future<Map<String, dynamic>> publish(String channel, dynamic data) async {
    _logger.info('Dispatcher: Publishing to channel: $channel');
    _logger.info('Dispatcher: Current state: $_state, clientId: $_clientId');

    if (_state != 3 || _clientId == null) {
      // connected
      _logger.severe(
          'Dispatcher: Cannot publish - not connected or no clientId. State: $_state, clientId: $_clientId');
      throw FayeError.network('Not connected');
    }

    final message = {
      'channel': channel,
      'data': data,
      'clientId': _clientId,
      'id': _generateMessageId(),
    };

    // Apply extension if available
    Map<String, dynamic> processedMessage = message;
    if (_extension != null) {
      try {
        _logger.info('Dispatcher: Original message: $message');
        processedMessage = _extension.outgoing(message);
        _logger.info('Dispatcher: Extension returned: $processedMessage');
        _logger.info('Dispatcher: Applied extension to message');
      } catch (e) {
        _logger.warning('Dispatcher: Extension processing failed: $e');
      }
    }

    _logger.info('Dispatcher: Publishing message: $processedMessage');
    return await _sendMessage(processedMessage);
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
