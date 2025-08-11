import 'channel.dart';

/// Callback function type for subscription messages
typedef SubscriptionCallback = void Function(dynamic data);

/// Represents a subscription to a Bayeux channel
class Subscription {
  /// Unique subscription ID
  final String id;
  
  /// Channel being subscribed to
  final Channel channel;
  
  /// Callback function to handle messages
  final SubscriptionCallback callback;
  
  /// Whether this subscription is active
  bool _active;
  
  /// Timestamp when subscription was created
  final DateTime createdAt;
  
  /// Timestamp when subscription was last used
  DateTime? _lastUsed;
  
  /// Number of messages received
  int _messageCount;
  
  /// Error count
  int _errorCount;
  
  Subscription({
    required this.id,
    required this.channel,
    required this.callback,
  }) : 
    _active = true,
    createdAt = DateTime.now(),
    _messageCount = 0,
    _errorCount = 0;
  
  /// Whether this subscription is active
  bool get active => _active;
  
  /// Timestamp when subscription was last used
  DateTime? get lastUsed => _lastUsed;
  
  /// Number of messages received
  int get messageCount => _messageCount;
  
  /// Error count
  int get errorCount => _errorCount;
  
  /// Age of subscription in milliseconds
  int get age => DateTime.now().difference(createdAt).inMilliseconds;
  
  /// Time since last use in milliseconds
  int? get timeSinceLastUse {
    if (_lastUsed == null) return null;
    return DateTime.now().difference(_lastUsed!).inMilliseconds;
  }
  
  /// Success rate (messages vs errors)
  double get successRate {
    final total = _messageCount + _errorCount;
    if (total == 0) return 1.0;
    return _messageCount / total;
  }
  
  /// Cancel this subscription
  void cancel() {
    _active = false;
  }
  
  /// Reactivate this subscription
  void reactivate() {
    _active = true;
  }
  
  /// Handle a message for this subscription
  void handleMessage(dynamic data) {
    if (!_active) return;
    
    try {
      _lastUsed = DateTime.now();
      _messageCount++;
      callback(data);
    } catch (error) {
      _errorCount++;
      rethrow;
    }
  }
  
  /// Handle an error for this subscription
  void handleError(dynamic error) {
    if (!_active) return;
    
    _lastUsed = DateTime.now();
    _errorCount++;
  }
  
  /// Check if this subscription matches a channel
  bool matches(Channel channel) {
    return this.channel.matchesChannel(channel);
  }
  
  /// Check if this subscription matches a channel name
  bool matchesChannel(String channelName) {
    return matches(Channel(channelName));
  }
  
  /// Get subscription statistics
  Map<String, dynamic> get statistics {
    return {
      'id': id,
      'channel': channel.name,
      'active': _active,
      'createdAt': createdAt.toIso8601String(),
      'lastUsed': _lastUsed?.toIso8601String(),
      'messageCount': _messageCount,
      'errorCount': _errorCount,
      'successRate': successRate,
      'age': age,
      'timeSinceLastUse': timeSinceLastUse,
    };
  }
  
  @override
  String toString() {
    return 'Subscription(id: $id, channel: ${channel.name}, active: $_active)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Subscription && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
}
