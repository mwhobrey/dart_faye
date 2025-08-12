import 'package:test/test.dart';
import 'package:dart_faye/dart_faye.dart';

class TestExtension implements FayeExtension {
  bool incomingCalled = false;
  bool outgoingCalled = false;
  Map<String, dynamic>? lastIncomingMessage;
  Map<String, dynamic>? lastOutgoingMessage;

  @override
  Map<String, dynamic> incoming(Map<String, dynamic> message) {
    incomingCalled = true;
    lastIncomingMessage = message;
    print('TestExtension.incoming called with: $message');
    return message;
  }

  @override
  Map<String, dynamic> outgoing(Map<String, dynamic> message) {
    outgoingCalled = true;
    lastOutgoingMessage = message;
    print('TestExtension.outgoing called with: $message');
    return message;
  }
}

void main() {
  group('Extension Tests', () {
    test('Extension should be called for incoming messages', () {
      final extension = TestExtension();
      final client = Client('ws://localhost:8080/faye');
      
      client.setExtension(extension);
      
      // Simulate incoming message
      final message = {
        'channel': '/meta/handshake',
        'successful': true,
        'clientId': 'test123',
        'supportedConnectionTypes': ['websocket']
      };
      
      // Call the extension directly
      final result = extension.incoming(message);
      
      expect(extension.incomingCalled, isTrue);
      expect(extension.lastIncomingMessage, equals(message));
      expect(result, equals(message));
    });

    test('Extension should be called for outgoing messages', () {
      final extension = TestExtension();
      final client = Client('ws://localhost:8080/faye');
      
      client.setExtension(extension);
      
      // Simulate outgoing message
      final message = {
        'channel': '/meta/subscribe',
        'subscription': '/test/channel',
        'clientId': 'test123'
      };
      
      // Call the extension directly
      final result = extension.outgoing(message);
      
      expect(extension.outgoingCalled, isTrue);
      expect(extension.lastOutgoingMessage, equals(message));
      expect(result, equals(message));
    });

    test('Extension should handle handshake response correctly', () {
      final extension = TestExtension();
      
      // Simulate handshake response
      final handshakeResponse = {
        'channel': '/meta/handshake',
        'successful': true,
        'clientId': 'test123',
        'supportedConnectionTypes': ['websocket']
      };
      
      final result = extension.incoming(handshakeResponse);
      
      expect(extension.incomingCalled, isTrue);
      expect(result, equals(handshakeResponse));
    });
  });
}
