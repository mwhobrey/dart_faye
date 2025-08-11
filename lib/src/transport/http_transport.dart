import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;
import '../util/constants.dart';
import '../error.dart';
import 'transport.dart';

/// HTTP transport implementation for Bayeux protocol
class HttpTransport extends BaseTransport {
  /// Logger
  static final Logger _logger = Logger('FayeHttpTransport');
  
  /// Transport name
  @override
  String get name => 'http';
  
  /// Whether this transport is supported (always true for HTTP)
  @override
  bool get supported => true;
  
  /// HTTP client
  final http.Client _client = http.Client();
  
  /// Current connection URL
  String? _url;
  
  /// Current headers
  Map<String, String>? _headers;
  
  /// Whether we're currently polling
  bool _polling = false;
  
  /// Polling timer
  Timer? _pollingTimer;
  
  /// Connection type (long-polling, callback-polling, etc.)
  String _connectionType = 'long-polling';
  
  /// Polling interval in milliseconds
  int _pollingInterval = 1000;
  
  /// JSONP callback name (for callback-polling)
  String? _jsonpCallback;
  
  /// Set connection type
  void setConnectionType(String type) {
    _connectionType = type;
  }
  
  /// Set polling interval
  void setPollingInterval(int interval) {
    _pollingInterval = interval;
  }
  
  /// Set JSONP callback name
  void setJsonpCallback(String callback) {
    _jsonpCallback = callback;
  }
  
  @override
  Future<void> connect(String url, {Map<String, String>? headers}) async {
    _logger.info('HTTP: Starting connection to $url');
    _logger.info('HTTP: Current connected state: $connected');
    
    if (connected) {
      _logger.info('HTTP: Already connected, skipping connection');
      return;
    }
    
    final startTime = DateTime.now();
    
    try {
      _url = url;
      _headers = headers ?? {};
      _logger.info('HTTP: URL set to $_url');
      _logger.info('HTTP: Headers: $_headers');
      
      // Set default headers
      _headers!.putIfAbsent('Content-Type', () => Constants.contentTypeJson);
      _headers!.putIfAbsent('Accept', () => Constants.contentTypeJson);
      _headers!.putIfAbsent('User-Agent', () => Constants.userAgent);
      _logger.info('HTTP: Default headers set');
      
      // Test connection with a handshake
      final handshake = {
        'channel': '/meta/handshake',
        'version': '1.0',
        'supportedConnectionTypes': ['long-polling'],
      };
      _logger.info('HTTP: Sending handshake: $handshake');
      
      final response = await _sendRequest(handshake);
      _logger.info('HTTP: Handshake response: $response');
      
      if (response['successful'] == true) {
        updateConnectionState(true);
        recordConnectTime(DateTime.now().difference(startTime).inMilliseconds);
        _logger.info('HTTP: Connection established successfully');
        
        // Start polling if using long-polling
        if (_connectionType == 'long-polling') {
          _logger.info('HTTP: Starting long-polling');
          _startPolling();
        }
      } else {
        _logger.severe('HTTP: Handshake failed: ${response['error']}');
        throw FayeError.fromBayeux(response['error'] ?? {});
      }
    } catch (e) {
      _logger.severe('HTTP: Connection failed: $e');
      emitError(FayeError.network('Failed to connect: $e'));
      rethrow;
    }
  }
  
  @override
  Future<void> disconnect() async {
    if (!connected) return;
    
    _stopPolling();
    updateConnectionState(false);
  }
  
  @override
  Future<void> send(Map<String, dynamic> message) async {
    _logger.info('HTTP: Sending message: $message');
    _logger.info('HTTP: Connected state: $connected');
    
    if (!connected) {
      _logger.severe('HTTP: Cannot send message - not connected');
      throw FayeError.network('Not connected');
    }
    
    try {
      _logger.info('HTTP: Sending request...');
      await _sendRequest(message);
      recordMessageSent(message);
      _logger.info('HTTP: Message sent successfully');
    } catch (e) {
      _logger.severe('HTTP: Failed to send message: $e');
      emitError(FayeError.network('Failed to send message: $e'));
      rethrow;
    }
  }
  
  @override
  Future<void> sendBatch(List<Map<String, dynamic>> messages) async {
          if (!connected) {
        throw FayeError.network('Not connected');
      }
      
      try {
        final response = await _sendRequest(messages);
        
        // Handle batch response
        if (response is List) {
          for (final message in response) {
            emitMessage(message);
          }
        } else {
          emitMessage(response);
        }
        
        for (final message in messages) {
          recordMessageSent(message);
        }
      } catch (e) {
        emitError(FayeError.network('Failed to send batch: $e'));
        rethrow;
      }
  }
  
  /// Send HTTP request
  Future<dynamic> _sendRequest(dynamic data) async {
    _logger.info('HTTP: Sending request with data: $data');
    
    if (_url == null) {
      _logger.severe('HTTP: No URL configured');
      throw FayeError.network('No URL configured');
    }
    
    final uri = Uri.parse(_url!);
    final body = jsonEncode(data);
    _logger.info('HTTP: Parsed URI: $uri');
    _logger.info('HTTP: Request body: $body');
    _logger.info('HTTP: Headers: $_headers');
    
    http.Response response;
    
    if (_connectionType == 'callback-polling' && _jsonpCallback != null) {
      // JSONP request
      _logger.info('HTTP: Making JSONP request');
      final callbackParam = '$_jsonpCallback=${DateTime.now().millisecondsSinceEpoch}';
      final separator = uri.query.isNotEmpty ? '&' : '?';
      final jsonpUri = Uri.parse('${uri.toString()}$separator$callbackParam');
      
      response = await _client.get(jsonpUri, headers: _headers);
    } else {
      // Regular POST request
      _logger.info('HTTP: Making POST request to $uri');
      response = await _client.post(
        uri,
        headers: _headers,
        body: body,
      ).timeout(Duration(seconds: timeout));
    }
    
    _logger.info('HTTP: Response status: ${response.statusCode}');
    _logger.info('HTTP: Response body: ${response.body}');
    
    if (response.statusCode != Constants.httpOk) {
      _logger.severe('HTTP: Request failed with status ${response.statusCode}');
      throw FayeError.fromHttp(response.statusCode, response.body);
    }
    
    final responseBody = response.body;
    if (responseBody.isEmpty) {
      _logger.info('HTTP: Empty response body, returning empty map');
      return <String, dynamic>{};
    }
    
    // Handle JSONP response
    if (_connectionType == 'callback-polling' && _jsonpCallback != null) {
      _logger.info('HTTP: Processing JSONP response');
      final jsonpMatch = RegExp(r'^\w+\((.*)\)$').firstMatch(responseBody);
      if (jsonpMatch != null) {
        final jsonData = jsonDecode(jsonpMatch.group(1)!);
        _logger.info('HTTP: JSONP response parsed: $jsonData');
        return jsonData;
      }
    }
    
    final jsonData = jsonDecode(responseBody);
    _logger.info('HTTP: Response parsed: $jsonData');
    return jsonData;
  }
  
  /// Start polling for messages
  void _startPolling() {
    if (_polling) return;
    
    _polling = true;
    _pollingTimer = Timer.periodic(Duration(milliseconds: _pollingInterval), (timer) {
      _poll();
    });
  }
  
  /// Stop polling
  void _stopPolling() {
    _polling = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }
  
  /// Poll for messages
  Future<void> _poll() async {
    if (!connected || !_polling) return;
    
    try {
      final connectMessage = {
        'channel': '/meta/connect',
        'clientId': 'temp', // Will be replaced by actual client ID
        'connectionType': _connectionType,
      };
      
      final response = await _sendRequest(connectMessage);
      
      if (response is List) {
        for (final message in response) {
          emitMessage(message);
        }
      } else if (response is Map<String, dynamic>) {
        emitMessage(response);
      }
    } catch (e) {
      emitError(FayeError.network('Polling failed: $e'));
      _stopPolling();
    }
  }
  
  @override
  Future<void> close() async {
    _stopPolling();
    _client.close();
    await super.close();
  }
  
  @override
  Map<String, dynamic> get statistics {
    final stats = super.statistics;
    stats['connectionType'] = _connectionType;
    stats['polling'] = _polling;
    stats['pollingInterval'] = _pollingInterval;
    stats['jsonpCallback'] = _jsonpCallback;
    return stats;
  }
}
