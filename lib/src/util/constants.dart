/// Constants used throughout the Faye implementation
class Constants {
  /// Maximum message ID value
  static const int maxMessageId = 9007199254740991; // 2^53 - 1
  
  /// Default timeout for HTTP requests in seconds
  static const int defaultTimeout = 30;
  
  /// Default retry delay in milliseconds
  static const int defaultRetryDelay = 1000;
  
  /// Maximum retry attempts
  static const int maxRetryAttempts = 5;
  
  /// WebSocket close codes
  static const int wsNormalClosure = 1000;
  static const int wsGoingAway = 1001;
  static const int wsProtocolError = 1002;
  static const int wsUnsupportedData = 1003;
  static const int wsNoStatusReceived = 1005;
  static const int wsAbnormalClosure = 1006;
  static const int wsInvalidFramePayloadData = 1007;
  static const int wsPolicyViolation = 1008;
  static const int wsMessageTooBig = 1009;
  static const int wsInternalServerError = 1011;
  
  /// HTTP status codes
  static const int httpOk = 200;
  static const int httpBadRequest = 400;
  static const int httpUnauthorized = 401;
  static const int httpForbidden = 403;
  static const int httpNotFound = 404;
  static const int httpMethodNotAllowed = 405;
  static const int httpInternalServerError = 500;
  static const int httpServiceUnavailable = 503;
  
  /// Content types
  static const String contentTypeJson = 'application/json';
  static const String contentTypeText = 'text/plain';
  static const String contentTypeForm = 'application/x-www-form-urlencoded';
  
  /// HTTP headers
  static const String headerContentType = 'Content-Type';
  static const String headerAccept = 'Accept';
  static const String headerUserAgent = 'User-Agent';
  static const String headerAuthorization = 'Authorization';
  static const String headerCacheControl = 'Cache-Control';
  static const String headerConnection = 'Connection';
  static const String headerUpgrade = 'Upgrade';
  static const String headerSecWebSocketKey = 'Sec-WebSocket-Key';
  static const String headerSecWebSocketAccept = 'Sec-WebSocket-Accept';
  static const String headerSecWebSocketProtocol = 'Sec-WebSocket-Protocol';
  static const String headerSecWebSocketVersion = 'Sec-WebSocket-Version';
  
  /// User agent string for the Dart Faye client
  static const String userAgent = 'Dart-Faye/1.0.0';
  
  /// Default WebSocket protocols
  static const List<String> defaultWebSocketProtocols = ['bayeux'];
  
  /// Default polling interval in milliseconds
  static const int defaultPollingInterval = 1000;
  
  /// Maximum message size in bytes
  static const int maxMessageSize = 1024 * 1024; // 1MB
  
  /// Default heartbeat interval in milliseconds
  static const int defaultHeartbeatInterval = 30000; // 30 seconds
  
  /// Default connection keep-alive timeout in milliseconds
  static const int defaultKeepAliveTimeout = 60000; // 60 seconds
}
