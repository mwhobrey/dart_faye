import 'dart:async';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';
import 'channel.dart';
import 'subscription.dart';
import 'publication.dart';
import 'error.dart';
import 'protocol/dispatcher.dart';
import 'dart:convert'; // Added for jsonDecode

/// Main Faye client for Bayeux protocol communication
class Client {
  /// Logger
  static final Logger _logger = Logger('FayeClient');

  /// Client state constants
  static const int unconnected = 1;
  static const int connecting = 2;
  static const int connected = 3;
  static const int disconnected = 4;

  /// Reconnection advice constants
  static const String handshake = 'handshake';
  static const String retry = 'retry';
  static const String none = 'none';

  /// Connection timeout in seconds
  static const int connectionTimeout = 60;

  /// Default endpoint
  static const String defaultEndpoint = '/bayeux';

  /// Default interval
  static const int defaultInterval = 0;

  /// Dispatcher for protocol handling
  final Dispatcher _dispatcher;

  /// Subscriptions
  final Map<String, Subscription> _subscriptions = {};

  /// Current state
  int _state = unconnected;

  /// Connection advice
  Map<String, dynamic> _advice = {
    'reconnect': retry,
    'interval': 1000 * defaultInterval,
    'timeout': 1000 * connectionTimeout,
  };

  /// UUID generator
  final Uuid _uuid = Uuid();

  /// Message stream controller
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// State change stream controller
  final StreamController<int> _stateController =
      StreamController<int>.broadcast();

  /// Error stream controller
  final StreamController<FayeError> _errorController =
      StreamController<FayeError>.broadcast();

  /// Connection endpoint
  final String _endpoint;

  Client(String endpoint, [Map<String, dynamic>? options])
      : _endpoint = endpoint,
        _dispatcher = Dispatcher(endpoint, options ?? {}) {
    _logger.info('Client: Creating client for endpoint: $_endpoint');
    _logger.info('Client: Options: $options');
    _initialize();
    _logger.info('Client: Client created successfully');
  }

  /// Extract the first message from a Bayeux response
  /// Bayeux responses can be either a single object or an array of objects
  Map<String, dynamic> extractBayeuxMessage(dynamic response) {
    _logger
        .info('Client: extractBayeuxMessage called with response: $response');
    _logger.info('Client: Response type: ${response.runtimeType}');
    _logger.info('Client: Response is String: ${response is String}');
    _logger.info('Client: Response is Map: ${response is Map<String, dynamic>}');
    _logger.info('Client: Response is List: ${response is List}');


    if (response is String) {
      // Parse string response as JSON
      try {
        _logger.info('Client: Parsing string response as JSON');
        final decoded = jsonDecode(response);
        _logger.info('Client: Decoded response: $decoded');
        _logger.info('Client: Decoded type: ${decoded.runtimeType}');

        if (decoded is List) {
          if (decoded.isEmpty) {
            throw FayeError.network('Empty response array from server');
          }
          final firstItem = decoded.first;
          _logger.info('Client: First item from list: $firstItem');
          _logger.info('Client: First item type: ${firstItem.runtimeType}');

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
        _logger.severe('Client: Failed to parse response as JSON: $e');
        throw FayeError.network('Failed to parse response as JSON: $e');
      }
    } else if (response is List) {
      if (response.isEmpty) {
        throw FayeError.network('Empty response array from server');
      }
      final firstItem = response.first;
      _logger.info('Client: First item from list: $firstItem');
      _logger.info('Client: First item type: ${firstItem.runtimeType}');

      if (firstItem is Map<String, dynamic>) {
        return firstItem;
      } else {
        throw FayeError.network(
            'Invalid first item type in response array: ${firstItem.runtimeType}');
      }
    } else if (response is Map<String, dynamic>) {
      return response;
    } else {
      _logger.severe('Client: Invalid response type: ${response.runtimeType}');
      throw FayeError.network(
          'Invalid response type from server: ${response.runtimeType}');
    }
  }

  /// Initialize the client
  void _initialize() {
    _logger.info('Client: Initializing client...');
    // Listen to dispatcher events
    _dispatcher.messageStream.listen(_handleMessage);
    _dispatcher.stateStream.listen(_handleStateChange);
    _dispatcher.errorStream.listen(_handleError);
    _logger.info('Client: Client initialized successfully');
  }

  /// Get current state
  int get state => _state;

  /// Get client ID
  String? get clientId => _dispatcher.clientId;

  /// Get current transport
  String? get transport => _dispatcher.transport?.name;

  /// Get message stream
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// Get state change stream
  Stream<int> get stateStream => _stateController.stream;

  /// Get error stream
  Stream<FayeError> get errorStream => _errorController.stream;

  /// Get all subscriptions
  List<Subscription> get subscriptions => _subscriptions.values.toList();

  /// Get connection advice
  Map<String, dynamic> get advice => Map.from(_advice);

  /// Set transport
  void setTransport(String transportName) {
    _dispatcher.setTransport(transportName);
  }

  /// Add WebSocket extension
  void addWebSocketExtension(dynamic extension) {
    // TODO: Implement WebSocket extensions
    _logger.warning('WebSocket extensions not yet implemented');
  }

  /// Disable a feature
  void disable(String feature) {
    // TODO: Implement feature disabling
    _logger.warning('Feature disabling not yet implemented: $feature');
  }

  /// Set HTTP header
  void setHeader(String name, String value) {
    // TODO: Implement header setting
    _logger.warning('Header setting not yet implemented: $name = $value');
  }

  /// Connect to the server
  Future<void> connect({Map<String, String>? headers}) async {
    _logger.info('Client: Starting connection to $_endpoint');
    _logger.info('Client: Current state: $_state');

    if (_state != unconnected) {
      _logger.warning(
          'Client: Cannot connect, not in unconnected state. Current state: $_state');
      return;
    }

    _logger.info('Client: Calling dispatcher.connect()...');

    try {
      await _dispatcher.connect(headers: headers);
      _logger.info('Client: Dispatcher.connect() completed successfully');

      _state = connected;
      _stateController.add(_state);
      _logger.info('Client: State updated to connected and broadcasted');

      _logger.info('Client: Connection completed successfully');
    } catch (e) {
      _logger.severe('Client: Connection failed: $e');
      _state = disconnected;
      _stateController.add(_state);
      _logger.severe('Client: State updated to disconnected due to error');
      rethrow;
    }
  }

  /// Disconnect from the server
  Future<void> disconnect() async {
    if (_state == unconnected) return;

    _logger.info('Disconnecting from $_endpoint');

    try {
      await _dispatcher.disconnect();
      _state = unconnected;
      _stateController.add(_state);

      _logger.info('Disconnected successfully');
    } catch (e) {
      _logger.severe('Disconnect failed: $e');
      rethrow;
    }
  }

  /// Subscribe to a channel
  Future<Subscription> subscribe(
      String channel, SubscriptionCallback callback) async {
    _logger.info('Client: Subscribing to channel: $channel');
    _logger.info('Client: Current state: $_state');

    // Allow subscriptions during connecting state (2) as well as connected state (3)
    // This is needed because extensions may try to subscribe during handshake response processing
    if (_state != connected && _state != connecting) {
      _logger.severe(
          'Client: Cannot subscribe - not connected or connecting. State: $_state');
      throw FayeError.network('Not connected');
    }

    if (!channel.isValidChannel && !channel.isValidChannelPattern) {
      _logger.severe('Client: Invalid channel name: $channel');
      throw FayeError.channel(channel, 'Invalid channel name');
    }

    final channelObj = Channel(channel);
    final subscriptionId = _uuid.v4();

    _logger.info('Client: Calling dispatcher.subscribe()...');

    try {
      final response = await _dispatcher.subscribe(channel);
      _logger.info('Client: Dispatcher.subscribe() response: $response');

      final responseMessage = extractBayeuxMessage(response);

      if (responseMessage['successful'] == true) {
        final subscription = Subscription(
          id: subscriptionId,
          channel: channelObj,
          callback: callback,
        );

        _subscriptions[subscriptionId] = subscription;

        _logger.info('Client: Subscribed to $channel successfully');
        return subscription;
      } else {
        _logger.severe(
            'Client: Subscription to $channel failed: ${responseMessage['error']}');
        final error = responseMessage['error'];
        if (error is Map<String, dynamic>) {
          throw FayeError.fromBayeux(error);
        } else if (error is String) {
          throw FayeError.network('Subscription failed: $error');
        } else {
          throw FayeError.network('Subscription failed: Unknown error');
        }
      }
    } catch (e) {
      _logger
          .severe('Client: Subscription to $channel failed with exception: $e');
      rethrow;
    }
  }

  /// Unsubscribe from a channel
  Future<void> unsubscribe(String channel) async {
    if (_state != connected) {
      throw FayeError.network('Not connected');
    }

    _logger.info('Unsubscribing from $channel');

    try {
      final response = await _dispatcher.unsubscribe(channel);
      final responseMessage = extractBayeuxMessage(response);

      if (responseMessage['successful'] == true) {
        // Remove all subscriptions for this channel
        _subscriptions.removeWhere(
            (id, subscription) => subscription.channel.name == channel);

        _logger.info('Unsubscribed from $channel successfully');
      } else {
        throw FayeError.fromBayeux(responseMessage['error'] ?? {});
      }
    } catch (e) {
      _logger.severe('Unsubscription from $channel failed: $e');
      rethrow;
    }
  }

  /// Unsubscribe using subscription object
  Future<void> unsubscribeSubscription(Subscription subscription) async {
    await unsubscribe(subscription.channel.name);
  }

  /// Set extension for message processing
  void setExtension(dynamic extension) {
    _dispatcher.setExtension(extension);
    _logger.info('Client: Extension set: $extension');
  }

  /// Publish a message to a channel
  Future<Publication> publish(String channel, dynamic data) async {
    _logger.info('Client: Publishing to channel: $channel');
    _logger.info('Client: Current state: $_state');
    _logger.info('Client: Data: $data');

    if (_state != connected) {
      _logger.severe('Client: Cannot publish - not connected. State: $_state');
      throw FayeError.network('Not connected');
    }

    if (!channel.isValidChannel) {
      _logger.severe('Client: Invalid channel name: $channel');
      throw FayeError.channel(channel, 'Invalid channel name');
    }

    final channelObj = Channel(channel);
    final publicationId = _uuid.v4();

    _logger.info('Client: Calling dispatcher.publish()...');

    try {
      final response = await _dispatcher.publish(channel, data);
      _logger.info('Client: Dispatcher.publish() response: $response');

      final publication = Publication(
        id: publicationId,
        channel: channelObj,
        data: data,
      );

      final responseMessage = extractBayeuxMessage(response);

      if (responseMessage['successful'] == true) {
        publication.markSuccessful();
        _logger.info('Client: Published to $channel successfully');
      } else {
        final error = FayeError.fromBayeux(responseMessage['error'] ?? {});
        publication.markFailed(error);
        _logger.severe('Client: Publication to $channel failed: $error');
      }

      return publication;
    } catch (e) {
      _logger
          .severe('Client: Publication to $channel failed with exception: $e');

      final publication = Publication(
        id: publicationId,
        channel: channelObj,
        data: data,
      );

      final error = FayeError.network('Publication failed: $e');
      publication.markFailed(error);

      return publication;
    }
  }

  /// Handle incoming messages
  void _handleMessage(Map<String, dynamic> message) {
    _logger.info('Client: Received message: $message');

    // Apply extension to incoming message if available
    Map<String, dynamic> processedMessage = message;
    if (_dispatcher.extension != null) {
      try {
        _logger
            .info('Client: Applying extension to incoming message: $message');
        _logger.info(
            'Client: Extension type: ${_dispatcher.extension.runtimeType}');
        _logger.info(
            'Client: Extension methods available: ${_dispatcher.extension.runtimeType.toString()}');
        processedMessage = _dispatcher.extension.incoming(message);
        _logger.info('Client: Extension returned: $processedMessage');
        _logger.info('Client: Applied extension to incoming message');
      } catch (e) {
        _logger.warning('Client: Extension processing failed: $e');
        _logger.warning('Client: Extension error stack trace: ${e.toString()}');
      }
    } else {
      _logger.info('Client: No extension available for incoming message');
    }

    final channel = processedMessage['channel'] as String?;

    if (channel == null) {
      _logger.warning(
          'Client: Received message without channel: $processedMessage');
      return;
    }

    // Handle meta messages
    if (channel.startsWith('/meta/')) {
      _logger.info('Client: Handling meta message for channel: $channel');
      _handleMetaMessage(processedMessage);
      return;
    }

    // Handle regular messages
    _logger.info('Client: Handling regular message for channel: $channel');
    _handleRegularMessage(processedMessage);
  }

  /// Handle meta messages
  void _handleMetaMessage(Map<String, dynamic> message) {
    final channel = message['channel'] as String;

    switch (channel) {
      case '/meta/connect':
        _handleConnectMessage(message);
        break;
      case '/meta/disconnect':
        _handleDisconnectMessage(message);
        break;
      case '/meta/subscribe':
        _handleSubscribeMessage(message);
        break;
      case '/meta/unsubscribe':
        _handleUnsubscribeMessage(message);
        break;
      default:
        _logger.warning('Unknown meta channel: $channel');
    }
  }

  /// Handle connect message
  void _handleConnectMessage(Map<String, dynamic> message) {
    // Update advice if provided
    if (message['advice'] != null) {
      _advice.addAll(message['advice'] as Map<String, dynamic>);
    }

    // Send next connect message if needed
    if (_state == connected) {
      _dispatcher.sendConnect();
    }
  }

  /// Handle disconnect message
  void _handleDisconnectMessage(Map<String, dynamic> message) {
    _logger.info('Received disconnect message');
  }

  /// Handle subscribe message
  void _handleSubscribeMessage(Map<String, dynamic> message) {
    final subscription = message['subscription'] as String?;
    final successful = message['successful'] as bool? ?? false;

    if (successful) {
      _logger.info('Subscription confirmed: $subscription');
    } else {
      _logger.warning('Subscription failed: $subscription');
    }
  }

  /// Handle unsubscribe message
  void _handleUnsubscribeMessage(Map<String, dynamic> message) {
    final subscription = message['subscription'] as String?;
    final successful = message['successful'] as bool? ?? false;

    if (successful) {
      _logger.info('Unsubscription confirmed: $subscription');
    } else {
      _logger.warning('Unsubscription failed: $subscription');
    }
  }

  /// Handle regular messages
  void _handleRegularMessage(Map<String, dynamic> message) {
    final channel = message['channel'] as String;
    final data = message['data'];

    // Find matching subscriptions
    final matchingSubscriptions = _subscriptions.values
        .where((subscription) =>
            subscription.channel.matchesChannel(Channel(channel)))
        .toList();

    if (matchingSubscriptions.isEmpty) {
      _logger.warning('No subscriptions found for channel: $channel');
      return;
    }

    // Deliver message to all matching subscriptions
    for (final subscription in matchingSubscriptions) {
      try {
        subscription.handleMessage(data);
      } catch (e) {
        _logger.severe('Error in subscription callback: $e');
        subscription.handleError(e);
      }
    }

    // Emit message to general message stream
    _messageController.add(message);
  }

  /// Handle state changes
  void _handleStateChange(int newState) {
    _logger.info('Client: State change from $_state to $newState');
    _state = newState;
    _stateController.add(newState);
    _logger.info('Client: State updated and broadcasted');
  }

  /// Handle errors
  void _handleError(FayeError error) {
    _logger.severe('Client: Error received: $error');
    _errorController.add(error);
  }

  /// Close the client
  Future<void> close() async {
    _logger.info('Closing client');

    // Cancel all subscriptions
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();

    // Close dispatcher
    await _dispatcher.close();

    // Close streams
    await _messageController.close();
    await _stateController.close();
    await _errorController.close();

    _logger.info('Client closed');
  }

  /// Get client statistics
  Map<String, dynamic> get statistics {
    return {
      'state': _state,
      'clientId': clientId,
      'transport': transport,
      'subscriptions': _subscriptions.length,
      'advice': _advice,
      'dispatcher': _dispatcher.statistics,
    };
  }

  @override
  String toString() {
    return 'FayeClient(endpoint: $_endpoint, state: $_state)';
  }
}
