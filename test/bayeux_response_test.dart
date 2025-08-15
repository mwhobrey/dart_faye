import 'package:test/test.dart';
import 'package:dart_faye/dart_faye.dart';

void main() {
  group('Bayeux Response Handling', () {
    test('should handle single object response', () {
      final response = {
        'successful': true,
        'clientId': 'test-client-id',
        'advice': {'reconnect': 'handshake'}
      };

      // Test the helper function
      final client = Client('http://localhost:8000/bayeux');
      final extracted = client.extractBayeuxMessage(response);

      expect(extracted, equals(response));
      expect(extracted['successful'], isTrue);
      expect(extracted['clientId'], equals('test-client-id'));
    });

    test('should handle array response', () {
      final response = [
        {
          'successful': true,
          'clientId': 'test-client-id',
          'advice': {'reconnect': 'handshake'}
        }
      ];

      // Test the helper function
      final client = Client('http://localhost:8000/bayeux');
      final extracted = client.extractBayeuxMessage(response);

      expect(extracted, equals(response.first));
      expect(extracted['successful'], isTrue);
      expect(extracted['clientId'], equals('test-client-id'));
    });

    test('should handle array response with multiple items', () {
      final response = [
        {
          'successful': true,
          'clientId': 'test-client-id',
          'advice': {'reconnect': 'handshake'}
        },
        {'channel': '/meta/connect', 'successful': true}
      ];

      // Test the helper function
      final client = Client('http://localhost:8000/bayeux');
      final extracted = client.extractBayeuxMessage(response);

      expect(extracted, equals(response.first));
      expect(extracted['successful'], isTrue);
      expect(extracted['clientId'], equals('test-client-id'));
    });

    test('should throw error for empty array', () {
      final response = <Map<String, dynamic>>[];

      // Test the helper function
      final client = Client('http://localhost:8000/bayeux');

      expect(
          () => client.extractBayeuxMessage(response),
          throwsA(isA<FayeError>().having((e) => e.message, 'message',
              contains('Empty response array from server'))));
    });

    test('should throw error for invalid response type', () {
      final response = 'invalid response';

      // Test the helper function
      final client = Client('http://localhost:8000/bayeux');

      expect(
          () => client.extractBayeuxMessage(response),
          throwsA(isA<FayeError>().having((e) => e.message, 'message',
              contains('Failed to parse response as JSON'))));
    });
  });
}
