import 'package:logging/logging.dart';

/// Faye extension interface for authentication and message transformation
abstract class FayeExtension {
  /// Process outgoing messages (e.g., add authentication headers)
  Map<String, dynamic> outgoing(Map<String, dynamic> message);
  
  /// Process incoming messages (e.g., validate authentication)
  Map<String, dynamic> incoming(Map<String, dynamic> message);
}

/// Default Faye extension implementation with authentication support
class DefaultFayeExtension implements FayeExtension {
  /// Logger
  static final Logger _logger = Logger('FayeExtension');
  
  /// API key for authentication
  final String api;
  
  /// Authentication token
  final String token;
  
  /// Logging callback
  final Function(String level, dynamic data)? onLog;
  
  /// Constructor
  DefaultFayeExtension({
    required this.api,
    required this.token,
    this.onLog,
  }) {
    _logger.info('Extension: Creating extension with API: $api');
    _log('info', 'Extension created with API: $api');
  }
  
  /// Process outgoing messages
  @override
  Map<String, dynamic> outgoing(Map<String, dynamic> message) {
    _logger.info('Extension: Processing outgoing message: $message');
    _log('debug', 'Processing outgoing message: $message');
    
    // Add authentication headers to ext field
    final ext = message['ext'] as Map<String, dynamic>? ?? <String, dynamic>{};
    ext['api'] = api;
    ext['token'] = token;
    
    final processedMessage = Map<String, dynamic>.from(message);
    processedMessage['ext'] = ext;
    
    _logger.info('Extension: Outgoing message processed: $processedMessage');
    _log('debug', 'Outgoing message processed: $processedMessage');
    
    return processedMessage;
  }
  
  /// Process incoming messages
  @override
  Map<String, dynamic> incoming(Map<String, dynamic> message) {
    _logger.info('Extension: Processing incoming message: $message');
    _log('debug', 'Processing incoming message: $message');
    
    // For now, just return the message as-is
    // In a real implementation, you might validate authentication here
    final processedMessage = Map<String, dynamic>.from(message);
    
    _logger.info('Extension: Incoming message processed: $processedMessage');
    _log('debug', 'Incoming message processed: $processedMessage');
    
    return processedMessage;
  }
  
  /// Log message using callback if provided
  void _log(String level, dynamic data) {
    if (onLog != null) {
      try {
        onLog!(level, data);
      } catch (e) {
        _logger.warning('Extension: Log callback failed: $e');
      }
    }
  }
}

/// Custom extension for message transformation
class CustomFayeExtension implements FayeExtension {
  /// Logger
  static final Logger _logger = Logger('CustomFayeExtension');
  
  /// Custom outgoing processor
  final Map<String, dynamic> Function(Map<String, dynamic>)? outgoingProcessor;
  
  /// Custom incoming processor
  final Map<String, dynamic> Function(Map<String, dynamic>)? incomingProcessor;
  
  /// Constructor
  CustomFayeExtension({
    this.outgoingProcessor,
    this.incomingProcessor,
  }) {
    _logger.info('CustomExtension: Creating custom extension');
  }
  
  /// Process outgoing messages
  @override
  Map<String, dynamic> outgoing(Map<String, dynamic> message) {
    _logger.info('CustomExtension: Processing outgoing message: $message');
    
    if (outgoingProcessor != null) {
      try {
        final processed = outgoingProcessor!(message);
        _logger.info('CustomExtension: Outgoing message processed: $processed');
        return processed;
      } catch (e) {
        _logger.severe('CustomExtension: Outgoing processing failed: $e');
        return message;
      }
    }
    
    return message;
  }
  
  /// Process incoming messages
  @override
  Map<String, dynamic> incoming(Map<String, dynamic> message) {
    _logger.info('CustomExtension: Processing incoming message: $message');
    
    if (incomingProcessor != null) {
      try {
        final processed = incomingProcessor!(message);
        _logger.info('CustomExtension: Incoming message processed: $processed');
        return processed;
      } catch (e) {
        _logger.severe('CustomExtension: Incoming processing failed: $e');
        return message;
      }
    }
    
    return message;
  }
}
