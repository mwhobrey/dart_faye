import 'dart:async';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';
import 'channel.dart';
import 'subscription.dart';
import 'publication.dart';
import 'error.dart';
import 'protocol/dispatcher.dart';

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
    _initialize();
  }
  
  /// Initialize the client
  void _initialize() {
    // Listen to dispatcher events
    _dispatcher.messageStream.listen(_handleMessage);
    _dispatcher.stateStream.listen(_handleStateChange);
    _dispatcher.errorStream.listen(_handleError);
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
    if (_state != unconnected) return;
    
    _logger.info('Connecting to $_endpoint');
    
    try {
      await _dispatcher.connect(headers: headers);
      _state = connected;
      _stateController.add(_state);
      
      _logger.info('Connected successfully');
    } catch (e) {
      _state = disconnected;
      _stateController.add(_state);
      _logger.severe('Connection failed: $e');
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
  Future<Subscription> subscribe(String channel, SubscriptionCallback callback) async {
    if (_state != connected) {
      throw FayeError.network('Not connected');
    }
    
    if (!channel.isValidChannel && !channel.isValidChannelPattern) {
      throw FayeError.channel(channel, 'Invalid channel name');
    }
    
    final channelObj = Channel(channel);
    final subscriptionId = _uuid.v4();
    
    _logger.info('Subscribing to $channel');
    
    try {
      final response = await _dispatcher.subscribe(channel);
      
      if (response['successful'] == true) {
        final subscription = Subscription(
          id: subscriptionId,
          channel: channelObj,
          callback: callback,
        );
        
        _subscriptions[subscriptionId] = subscription;
        
        _logger.info('Subscribed to $channel successfully');
        return subscription;
      } else {
        throw FayeError.fromBayeux(response['error'] ?? {});
      }
    } catch (e) {
      _logger.severe('Subscription to $channel failed: $e');
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
      
      if (response['successful'] == true) {
        // Remove all subscriptions for this channel
        _subscriptions.removeWhere((id, subscription) => 
          subscription.channel.name == channel);
        
        _logger.info('Unsubscribed from $channel successfully');
      } else {
        throw FayeError.fromBayeux(response['error'] ?? {});
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
  
  /// Publish a message to a channel
  Future<Publication> publish(String channel, dynamic data) async {
    if (_state != connected) {
      throw FayeError.network('Not connected');
    }
    
    if (!channel.isValidChannel) {
      throw FayeError.channel(channel, 'Invalid channel name');
    }
    
    final channelObj = Channel(channel);
    final publicationId = _uuid.v4();
    
    _logger.info('Publishing to $channel');
    
    try {
      final response = await _dispatcher.publish(channel, data);
      
      final publication = Publication(
        id: publicationId,
        channel: channelObj,
        data: data,
      );
      
      if (response['successful'] == true) {
        publication.markSuccessful();
        _logger.info('Published to $channel successfully');
      } else {
        final error = FayeError.fromBayeux(response['error'] ?? {});
        publication.markFailed(error);
        _logger.severe('Publication to $channel failed: $error');
      }
      
      return publication;
    } catch (e) {
      final publication = Publication(
        id: publicationId,
        channel: channelObj,
        data: data,
      );
      
      final error = FayeError.network('Publication failed: $e');
      publication.markFailed(error);
      
      _logger.severe('Publication to $channel failed: $e');
      return publication;
    }
  }
  
  /// Handle incoming messages
  void _handleMessage(Map<String, dynamic> message) {
    final channel = message['channel'] as String?;
    
    if (channel == null) {
      _logger.warning('Received message without channel: $message');
      return;
    }
    
    // Handle meta messages
    if (channel.startsWith('/meta/')) {
      _handleMetaMessage(message);
      return;
    }
    
    // Handle regular messages
    _handleRegularMessage(message);
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
    final matchingSubscriptions = _subscriptions.values.where(
      (subscription) => subscription.channel.matchesChannel(Channel(channel))
    ).toList();
    
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
    _state = newState;
    _stateController.add(newState);
  }
  
  /// Handle errors
  void _handleError(FayeError error) {
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
