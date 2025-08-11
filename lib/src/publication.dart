import 'dart:convert';
import 'channel.dart';
import 'error.dart';

/// Represents a message publication to a Bayeux channel
class Publication {
  /// Unique publication ID
  final String id;
  
  /// Channel being published to
  final Channel channel;
  
  /// Message data
  final dynamic data;
  
  /// Extensions data (optional)
  final Map<String, dynamic>? ext;
  
  /// Whether this publication was successful
  bool _successful;
  
  /// Error if publication failed
  FayeError? _error;
  
  /// Timestamp when publication was created
  final DateTime createdAt;
  
  /// Timestamp when publication was completed
  DateTime? _completedAt;
  
  /// Number of subscribers that received the message
  int _subscriberCount;
  
  Publication({
    required this.id,
    required this.channel,
    required this.data,
    this.ext,
  }) : 
    _successful = false,
    createdAt = DateTime.now(),
    _subscriberCount = 0;
  
  /// Whether this publication was successful
  bool get successful => _successful;
  
  /// Error if publication failed
  FayeError? get error => _error;
  
  /// Timestamp when publication was completed
  DateTime? get completedAt => _completedAt;
  
  /// Number of subscribers that received the message
  int get subscriberCount => _subscriberCount;
  
  /// Duration of publication in milliseconds
  int? get duration {
    if (_completedAt == null) return null;
    return _completedAt!.difference(createdAt).inMilliseconds;
  }
  
  /// Mark publication as successful
  void markSuccessful([int subscriberCount = 0]) {
    _successful = true;
    _completedAt = DateTime.now();
    _subscriberCount = subscriberCount;
  }
  
  /// Mark publication as failed
  void markFailed(FayeError error) {
    _successful = false;
    _error = error;
    _completedAt = DateTime.now();
  }
  
  /// Convert to Bayeux message format
  Map<String, dynamic> toBayeux() {
    final message = <String, dynamic>{
      'channel': channel.name,
      'data': data,
    };
    
    if (id.isNotEmpty) {
      message['id'] = id;
    }
    
    if (ext != null && ext!.isNotEmpty) {
      message['ext'] = ext;
    }
    
    return message;
  }
  
  /// Convert to JSON string
  String toJson() {
    return jsonEncode(toBayeux());
  }
  
  /// Create a publication from a Bayeux message
  factory Publication.fromBayeux(Map<String, dynamic> message) {
    final channel = Channel(message['channel'] as String);
    final data = message['data'];
    final id = message['id'] as String? ?? '';
    final ext = message['ext'] as Map<String, dynamic>?;
    
    return Publication(
      id: id,
      channel: channel,
      data: data,
      ext: ext,
    );
  }
  
  /// Get publication statistics
  Map<String, dynamic> get statistics {
    return {
      'id': id,
      'channel': channel.name,
      'successful': _successful,
      'error': _error?.toBayeux(),
      'createdAt': createdAt.toIso8601String(),
      'completedAt': _completedAt?.toIso8601String(),
      'duration': duration,
      'subscriberCount': _subscriberCount,
    };
  }
  
  @override
  String toString() {
    final status = _successful ? 'successful' : 'failed';
    final error = _error != null ? ' (${_error!.message})' : '';
    return 'Publication(id: $id, channel: ${channel.name}, $status$error)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Publication && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
}
