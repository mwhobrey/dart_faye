import 'dart:convert';

/// Faye error class for handling Bayeux protocol errors
class FayeError implements Exception {
  /// Error code (3-digit number)
  final String code;
  
  /// Error message
  final String message;
  
  /// Error parameters (optional)
  final List<String>? params;
  
  /// Error arguments (optional)
  final Map<String, dynamic>? args;
  
  /// HTTP status code (optional)
  final int? httpCode;
  
  /// HTTP response body (optional)
  final String? httpBody;
  
  /// Stack trace
  final StackTrace? stackTrace;
  
  FayeError(
    this.code,
    this.message, {
    this.params,
    this.args,
    this.httpCode,
    this.httpBody,
    this.stackTrace,
  });
  
  /// Create an error from a Bayeux error response
  factory FayeError.fromBayeux(Map<String, dynamic> error) {
    final code = error['code'] as String? ?? '000';
    final message = error['message'] as String? ?? 'Unknown error';
    final params = error['params'] as List<String>?;
    final args = error['args'] as Map<String, dynamic>?;
    
    return FayeError(code, message, params: params, args: args);
  }
  
  /// Create an error from HTTP response
  factory FayeError.fromHttp(int statusCode, String body) {
    String code;
    String message;
    
    switch (statusCode) {
      case 400:
        code = '400';
        message = 'Bad Request';
        break;
      case 401:
        code = '401';
        message = 'Unauthorized';
        break;
      case 403:
        code = '403';
        message = 'Forbidden';
        break;
      case 404:
        code = '404';
        message = 'Not Found';
        break;
      case 405:
        code = '405';
        message = 'Method Not Allowed';
        break;
      case 500:
        code = '500';
        message = 'Internal Server Error';
        break;
      case 503:
        code = '503';
        message = 'Service Unavailable';
        break;
      default:
        code = '000';
        message = 'HTTP Error $statusCode';
    }
    
    return FayeError(
      code,
      message,
      httpCode: statusCode,
      httpBody: body,
    );
  }
  
  /// Create a network error
  factory FayeError.network(String message, {StackTrace? stackTrace}) {
    return FayeError('000', 'Network Error: $message', stackTrace: stackTrace);
  }
  
  /// Create a timeout error
  factory FayeError.timeout(String operation) {
    return FayeError('408', 'Timeout: $operation');
  }
  
  /// Create a protocol error
  factory FayeError.protocol(String message) {
    return FayeError('400', 'Protocol Error: $message');
  }
  
  /// Create an authentication error
  factory FayeError.authentication(String message) {
    return FayeError('401', 'Authentication Error: $message');
  }
  
  /// Create a subscription error
  factory FayeError.subscription(String channel, String reason) {
    return FayeError('403', 'Subscription Error: $reason', params: [channel]);
  }
  
  /// Create a publication error
  factory FayeError.publication(String channel, String reason) {
    return FayeError('403', 'Publication Error: $reason', params: [channel]);
  }
  
  /// Create a channel error
  factory FayeError.channel(String channel, String reason) {
    return FayeError('400', 'Channel Error: $reason', params: [channel]);
  }
  
  /// Check if this is a network error
  bool get isNetworkError => code == '000' && message.startsWith('Network Error');
  
  /// Check if this is a timeout error
  bool get isTimeoutError => code == '408';
  
  /// Check if this is a protocol error
  bool get isProtocolError => code == '400' && message.startsWith('Protocol Error');
  
  /// Check if this is an authentication error
  bool get isAuthenticationError => code == '401';
  
  /// Check if this is a subscription error
  bool get isSubscriptionError => code == '403' && message.startsWith('Subscription Error');
  
  /// Check if this is a publication error
  bool get isPublicationError => code == '403' && message.startsWith('Publication Error');
  
  /// Check if this is a channel error
  bool get isChannelError => code == '400' && message.startsWith('Channel Error');
  
  /// Convert error to Bayeux format
  Map<String, dynamic> toBayeux() {
    final result = <String, dynamic>{
      'code': code,
      'message': message,
    };
    
    if (params != null && params!.isNotEmpty) {
      result['params'] = params;
    }
    
    if (args != null && args!.isNotEmpty) {
      result['args'] = args;
    }
    
    return result;
  }
  
  /// Convert error to JSON string
  String toJson() {
    return jsonEncode(toBayeux());
  }
  
  @override
  String toString() {
    final parts = <String>[code, message];
    
    if (params != null && params!.isNotEmpty) {
      parts.add('params: ${params!.join(', ')}');
    }
    
    if (args != null && args!.isNotEmpty) {
      parts.add('args: $args');
    }
    
    if (httpCode != null) {
      parts.add('HTTP: $httpCode');
    }
    
    return 'FayeError(${parts.join(', ')})';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FayeError &&
        other.code == code &&
        other.message == message &&
        other.params == params &&
        other.args == args &&
        other.httpCode == httpCode;
  }
  
  @override
  int get hashCode {
    return Object.hash(code, message, params, args, httpCode);
  }
}
