library dart_faye;

import 'dart:convert';

export 'src/client.dart';
export 'src/channel.dart';
export 'src/subscription.dart';
export 'src/publication.dart';
export 'src/error.dart';
export 'src/transport/transport.dart';
export 'src/transport/http_transport.dart';
export 'src/transport/websocket_transport.dart';
export 'src/protocol/grammar.dart';
export 'src/protocol/dispatcher.dart';
export 'src/util/constants.dart';
export 'src/util/namespace.dart';

/// Main Faye library class containing constants and utility methods
class Faye {
  /// Current version of the Dart Faye implementation
  static const String version = '1.0.0';
  
  /// Bayeux protocol version
  static const String bayeuxVersion = '1.0';
  
  /// JSONP callback parameter name
  static const String jsonpCallback = 'jsonpcallback';
  
  /// Supported connection types
  static const List<String> connectionTypes = [
    'long-polling',
    'cross-origin-long-polling', 
    'callback-polling',
    'websocket',
    'eventsource',
    'in-process'
  ];
  
  /// Mandatory connection types that must be supported
  static const List<String> mandatoryConnectionTypes = [
    'long-polling',
    'callback-polling',
    'in-process'
  ];
  
  /// Default connection timeout in seconds
  static const int connectionTimeout = 60;
  
  /// Default endpoint for Bayeux server
  static const String defaultEndpoint = '/bayeux';
  
  /// Default retry interval in milliseconds
  static const int defaultInterval = 0;
  
  /// Client states
  static const int unconnected = 1;
  static const int connecting = 2;
  static const int connected = 3;
  static const int disconnected = 4;
  
  /// Reconnection advice types
  static const String handshake = 'handshake';
  static const String retry = 'retry';
  static const String none = 'none';
  
  /// Deep copy an object (Map, List, or primitive)
  static dynamic copyObject(dynamic object) {
    if (object is Map) {
      return Map.fromEntries(
        object.entries.map((entry) => MapEntry(entry.key, copyObject(entry.value)))
      );
    } else if (object is List) {
      return object.map((item) => copyObject(item)).toList();
    } else {
      return object;
    }
  }
  
  /// Convert value to JSON string
  static String toJson(dynamic value) {
    if (value is Map || value is List) {
      return jsonEncode(value);
    } else if (value is String) {
      return jsonEncode(value);
    } else if (value == null) {
      return 'null';
    } else {
      return value.toString();
    }
  }
  
  /// Extract client ID from messages
  static String? clientIdFromMessages(List<Map<String, dynamic>> messages) {
    try {
      final connectMessage = messages.firstWhere(
        (message) => message['channel'] == '/meta/connect',
      );
      return connectMessage['clientId'] as String?;
    } catch (e) {
      return null;
    }
  }
}
