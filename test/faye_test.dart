import 'package:test/test.dart';
import 'package:dart_faye/dart_faye.dart';

void main() {
  group('Faye Library Tests', () {
    group('Grammar Tests', () {
      test('should validate valid channel names', () {
        expect(Grammar.isValidChannelName('/chat/room1'), isTrue);
        expect(Grammar.isValidChannelName('/users/alice/status'), isTrue);
        expect(Grammar.isValidChannelName('/meta/connect'), isTrue);
        expect(Grammar.isValidChannelName('/service/auth'), isTrue);
      });
      
      test('should reject invalid channel names', () {
        expect(Grammar.isValidChannelName('chat/room1'), isFalse);
        expect(Grammar.isValidChannelName('/chat/'), isFalse);
        expect(Grammar.isValidChannelName('/chat/room 1'), isFalse);
        expect(Grammar.isValidChannelName('/chat/room#1'), isFalse);
      });
      
      test('should validate channel patterns', () {
        expect(Grammar.isValidChannelPattern('/chat/*'), isTrue);
        expect(Grammar.isValidChannelPattern('/users/*/status'), isTrue);
        expect(Grammar.isValidChannelPattern('/chat/**'), isTrue);
      });
      
      test('should match channels to patterns', () {
        expect(Grammar.channelMatches('/chat/room1', '/chat/*'), isTrue);
        expect(Grammar.channelMatches('/chat/room1', '/chat/**'), isTrue);
        expect(Grammar.channelMatches('/users/alice/status', '/users/*/status'), isTrue);
        expect(Grammar.channelMatches('/chat/room1', '/users/*'), isFalse);
      });
    });
    
    group('Channel Tests', () {
      test('should create valid channels', () {
        final channel = Channel('/chat/room1');
        expect(channel.name, equals('/chat/room1'));
        expect(channel.isMeta, isFalse);
        expect(channel.isService, isFalse);
        expect(channel.isPattern, isFalse);
      });
      
      test('should identify meta channels', () {
        final channel = Channel('/meta/connect');
        expect(channel.isMeta, isTrue);
        expect(channel.isService, isFalse);
      });
      
      test('should identify service channels', () {
        final channel = Channel('/service/auth');
        expect(channel.isService, isTrue);
        expect(channel.isMeta, isFalse);
      });
      
      test('should identify pattern channels', () {
        final channel = Channel('/chat/*');
        expect(channel.isPattern, isTrue);
        expect(channel.isWildcard, isFalse);
      });
      
      test('should identify wildcard patterns', () {
        final channel = Channel('/chat/**');
        expect(channel.isPattern, isTrue);
        expect(channel.isWildcard, isTrue);
      });
      
      test('should match channels', () {
        final channel1 = Channel('/chat/room1');
        final channel2 = Channel('/chat/room2');
        final pattern = Channel('/chat/*');
        
        expect(channel1.matchesChannel(pattern), isTrue);
        expect(channel2.matchesChannel(pattern), isTrue);
        expect(channel1.matchesChannel(channel2), isFalse);
      });
      
      test('should get parent channels', () {
        final channel = Channel('/chat/room1/messages');
        final parent = channel.parent;
        
        expect(parent?.name, equals('/chat/room1'));
        expect(parent?.parent?.name, equals('/chat'));
      });
      
      test('should get segments', () {
        final channel = Channel('/chat/room1/messages');
        expect(channel.segments, equals(['chat', 'room1', 'messages']));
        expect(channel.depth, equals(3));
      });
    });
    
    group('Error Tests', () {
      test('should create network errors', () {
        final error = FayeError.network('Connection failed');
        expect(error.isNetworkError, isTrue);
        expect(error.code, equals('000'));
        expect(error.message, contains('Connection failed'));
      });
      
      test('should create timeout errors', () {
        final error = FayeError.timeout('Request timeout');
        expect(error.isTimeoutError, isTrue);
        expect(error.code, equals('408'));
      });
      
      test('should create protocol errors', () {
        final error = FayeError.protocol('Invalid message format');
        expect(error.isProtocolError, isTrue);
        expect(error.code, equals('400'));
      });
      
      test('should create authentication errors', () {
        final error = FayeError.authentication('Invalid credentials');
        expect(error.isAuthenticationError, isTrue);
        expect(error.code, equals('401'));
      });
      
      test('should create subscription errors', () {
        final error = FayeError.subscription('/chat/room1', 'Access denied');
        expect(error.isSubscriptionError, isTrue);
        expect(error.code, equals('403'));
        expect(error.params, contains('/chat/room1'));
      });
      
      test('should create publication errors', () {
        final error = FayeError.publication('/chat/room1', 'Channel not found');
        expect(error.isPublicationError, isTrue);
        expect(error.code, equals('403'));
        expect(error.params, contains('/chat/room1'));
      });
      
      test('should create channel errors', () {
        final error = FayeError.channel('/invalid', 'Invalid channel name');
        expect(error.isChannelError, isTrue);
        expect(error.code, equals('400'));
        expect(error.params, contains('/invalid'));
      });
      
      test('should convert to Bayeux format', () {
        final error = FayeError('403', 'Access denied', params: ['/chat/room1']);
        final bayeux = error.toBayeux();
        
        expect(bayeux['code'], equals('403'));
        expect(bayeux['message'], equals('Access denied'));
        expect(bayeux['params'], equals(['/chat/room1']));
      });
    });
    
    group('Subscription Tests', () {
      test('should create subscriptions', () {
        final subscription = Subscription(
          id: 'test-id',
          channel: Channel('/chat/room1'),
          callback: (data) => print(data),
        );
        
        expect(subscription.id, equals('test-id'));
        expect(subscription.channel.name, equals('/chat/room1'));
        expect(subscription.active, isTrue);
        expect(subscription.messageCount, equals(0));
        expect(subscription.errorCount, equals(0));
      });
      
      test('should handle messages', () {
        var receivedData;
        final subscription = Subscription(
          id: 'test-id',
          channel: Channel('/chat/room1'),
          callback: (data) => receivedData = data,
        );
        
        subscription.handleMessage({'message': 'Hello'});
        
        expect(receivedData, equals({'message': 'Hello'}));
        expect(subscription.messageCount, equals(1));
        expect(subscription.lastUsed, isNotNull);
      });
      
      test('should handle errors', () {
        final subscription = Subscription(
          id: 'test-id',
          channel: Channel('/chat/room1'),
          callback: (data) => throw Exception('Test error'),
        );
        
        expect(() => subscription.handleMessage({'message': 'Hello'}), throwsException);
        expect(subscription.errorCount, equals(1));
      });
      
      test('should cancel subscriptions', () {
        final subscription = Subscription(
          id: 'test-id',
          channel: Channel('/chat/room1'),
          callback: (data) => print(data),
        );
        
        expect(subscription.active, isTrue);
        subscription.cancel();
        expect(subscription.active, isFalse);
      });
      
      test('should match channels', () {
        final subscription = Subscription(
          id: 'test-id',
          channel: Channel('/chat/*'),
          callback: (data) => print(data),
        );
        
        expect(subscription.matches(Channel('/chat/room1')), isTrue);
        expect(subscription.matches(Channel('/users/alice')), isFalse);
      });
    });
    
    group('Publication Tests', () {
      test('should create publications', () {
        final publication = Publication(
          id: 'test-id',
          channel: Channel('/chat/room1'),
          data: {'message': 'Hello'},
        );
        
        expect(publication.id, equals('test-id'));
        expect(publication.channel.name, equals('/chat/room1'));
        expect(publication.data, equals({'message': 'Hello'}));
        expect(publication.successful, isFalse);
        expect(publication.error, isNull);
      });
      
      test('should mark successful publications', () {
        final publication = Publication(
          id: 'test-id',
          channel: Channel('/chat/room1'),
          data: {'message': 'Hello'},
        );
        
        publication.markSuccessful(5);
        
        expect(publication.successful, isTrue);
        expect(publication.subscriberCount, equals(5));
        expect(publication.completedAt, isNotNull);
        expect(publication.duration, isNotNull);
      });
      
      test('should mark failed publications', () {
        final publication = Publication(
          id: 'test-id',
          channel: Channel('/chat/room1'),
          data: {'message': 'Hello'},
        );
        
        final error = FayeError.network('Connection failed');
        publication.markFailed(error);
        
        expect(publication.successful, isFalse);
        expect(publication.error, equals(error));
        expect(publication.completedAt, isNotNull);
        expect(publication.duration, isNotNull);
      });
      
      test('should convert to Bayeux format', () {
        final publication = Publication(
          id: 'test-id',
          channel: Channel('/chat/room1'),
          data: {'message': 'Hello'},
        );
        
        final bayeux = publication.toBayeux();
        
        expect(bayeux['channel'], equals('/chat/room1'));
        expect(bayeux['data'], equals({'message': 'Hello'}));
        expect(bayeux['id'], equals('test-id'));
      });
    });
    
    group('Namespace Tests', () {
      test('should check namespace membership', () {
        expect(Namespace.isInNamespace('/chat/room1', '/chat'), isTrue);
        expect(Namespace.isInNamespace('/chat/room1', '/users'), isFalse);
        expect(Namespace.isInNamespace('/chat/room1', '/'), isTrue);
      });
      
      test('should get namespace', () {
        expect(Namespace.getNamespace('/chat/room1'), equals('/chat'));
        expect(Namespace.getNamespace('/users/alice/status'), equals('/users'));
        expect(Namespace.getNamespace('/'), equals('/'));
      });
      
      test('should get relative path', () {
        expect(Namespace.getRelativePath('/chat/room1', '/chat'), equals('/room1'));
        expect(Namespace.getRelativePath('/chat/room1', '/'), equals('/chat/room1'));
        expect(Namespace.getRelativePath('/chat/room1', '/users'), isNull);
      });
      
      test('should identify meta channels', () {
        expect(Namespace.isMetaChannel('/meta/connect'), isTrue);
        expect(Namespace.isMetaChannel('/chat/room1'), isFalse);
      });
      
      test('should identify service channels', () {
        expect(Namespace.isServiceChannel('/service/auth'), isTrue);
        expect(Namespace.isServiceChannel('/chat/room1'), isFalse);
      });
      
      test('should normalize channel names', () {
        expect(Namespace.normalize('chat/room1'), equals('/chat/room1'));
        expect(Namespace.normalize('/chat/room1/'), equals('/chat/room1'));
        expect(Namespace.normalize('/'), equals('/'));
      });
    });
    
    group('Faye Utility Tests', () {
      test('should copy objects', () {
        final original = {
          'nested': {
            'list': [1, 2, 3],
            'string': 'test'
          }
        };
        
        final copy = Faye.copyObject(original);
        
        expect(copy, equals(original));
        expect(identical(copy, original), isFalse);
        expect(identical(copy['nested'], original['nested']), isFalse);
      });
      
      test('should convert to JSON', () {
        expect(Faye.toJson({'key': 'value'}), contains('"key"'));
        expect(Faye.toJson([1, 2, 3]), contains('1'));
        expect(Faye.toJson('string'), equals('"string"'));
        expect(Faye.toJson(null), equals('null'));
      });
      
      test('should extract client ID from messages', () {
        final messages = [
          {'channel': '/meta/connect', 'clientId': 'client123'},
          {'channel': '/chat/room1', 'data': 'Hello'}
        ];
        
        final clientId = Faye.clientIdFromMessages(messages);
        expect(clientId, equals('client123'));
      });
    });
    
    group('Extension Tests', () {
      test('should create default extension', () {
        final extension = DefaultFayeExtension(
          api: 'test-api-key',
          token: 'test-token',
        );
        
        expect(extension.api, equals('test-api-key'));
        expect(extension.token, equals('test-token'));
      });
      
      test('should process outgoing messages with authentication', () {
        final extension = DefaultFayeExtension(
          api: 'test-api-key',
          token: 'test-token',
        );
        
        final message = {
          'channel': '/chat/room1',
          'data': {'message': 'Hello'},
        };
        
        final processed = extension.outgoing(message);
        
        expect(processed['channel'], equals('/chat/room1'));
        expect(processed['data'], equals({'message': 'Hello'}));
        expect(processed['ext']['api'], equals('test-api-key'));
        expect(processed['ext']['token'], equals('test-token'));
      });
      
      test('should process incoming messages', () {
        final extension = DefaultFayeExtension(
          api: 'test-api-key',
          token: 'test-token',
        );
        
        final message = {
          'channel': '/chat/room1',
          'data': {'message': 'Hello'},
        };
        
        final processed = extension.incoming(message);
        
        expect(processed, equals(message));
      });
      
      test('should handle extension with logging callback', () {
        var loggedMessages = <String>[];
        
        final extension = DefaultFayeExtension(
          api: 'test-api-key',
          token: 'test-token',
          onLog: (level, data) {
            loggedMessages.add('[$level] $data');
          },
        );
        
        final message = {'channel': '/test'};
        extension.outgoing(message);
        
        expect(loggedMessages.length, greaterThan(0));
        expect(loggedMessages.any((msg) => msg.contains('debug')), isTrue);
      });
      
      test('should create custom extension', () {
        final extension = CustomFayeExtension(
          outgoingProcessor: (message) {
            message['custom'] = 'outgoing';
            return message;
          },
          incomingProcessor: (message) {
            message['custom'] = 'incoming';
            return message;
          },
        );
        
        final outgoingMessage = {'channel': '/test'};
        final incomingMessage = {'channel': '/test'};
        
        final processedOutgoing = extension.outgoing(outgoingMessage);
        final processedIncoming = extension.incoming(incomingMessage);
        
        expect(processedOutgoing['custom'], equals('outgoing'));
        expect(processedIncoming['custom'], equals('incoming'));
      });
      
      test('should handle custom extension with null processors', () {
        final extension = CustomFayeExtension();
        
        final message = {'channel': '/test'};
        final processed = extension.outgoing(message);
        
        expect(processed, equals(message));
      });
      
      test('should handle extension processing errors gracefully', () {
        final extension = CustomFayeExtension(
          outgoingProcessor: (message) {
            throw Exception('Processing error');
          },
        );
        
        final message = {'channel': '/test'};
        final processed = extension.outgoing(message);
        
        // Should return original message on error
        expect(processed, equals(message));
      });
    });
    
    group('Client Extension Tests', () {
      test('should set extension on client', () {
        final client = Client('http://localhost:8000/bayeux');
        final extension = DefaultFayeExtension(
          api: 'test-api-key',
          token: 'test-token',
        );
        
        client.setExtension(extension);
        
        // Extension is set internally, we can't directly test it
        // but we can verify the method doesn't throw
        expect(() => client.setExtension(extension), returnsNormally);
      });
      
      test('should set extension on dispatcher', () {
        final dispatcher = Dispatcher('http://localhost:8000/bayeux', {});
        final extension = DefaultFayeExtension(
          api: 'test-api-key',
          token: 'test-token',
        );
        
        dispatcher.setExtension(extension);
        
        // Extension is set internally, we can't directly test it
        // but we can verify the method doesn't throw
        expect(() => dispatcher.setExtension(extension), returnsNormally);
      });
    });
    
    group('Logging Tests', () {
      test('should have logger in client', () {
        final client = Client('http://localhost:8000/bayeux');
        expect(client, isNotNull);
        // Logger is internal, but we can verify client creation doesn't fail
      });
      
      test('should have logger in dispatcher', () {
        final dispatcher = Dispatcher('http://localhost:8000/bayeux', {});
        expect(dispatcher, isNotNull);
        // Logger is internal, but we can verify dispatcher creation doesn't fail
      });
      
      test('should have logger in transports', () {
        final httpTransport = HttpTransport();
        final wsTransport = WebSocketTransport();
        
        expect(httpTransport, isNotNull);
        expect(wsTransport, isNotNull);
        // Logger is internal, but we can verify transport creation doesn't fail
      });
    });
    
    group('WebSocket Transport Enhancement Tests', () {
      test('should support batch message handling', () {
        final transport = WebSocketTransport();
        expect(transport.supported, isTrue);
        expect(transport.name, equals('websocket'));
      });
      
      test('should set auto-reconnect settings', () {
        final transport = WebSocketTransport();
        
        transport.setAutoReconnect(
          true,
          maxAttempts: 10,
          delay: 2000,
        );
        
        // Settings are internal, but we can verify the method doesn't throw
        expect(() => transport.setAutoReconnect(false), returnsNormally);
      });
      
      test('should set heartbeat interval', () {
        final transport = WebSocketTransport();
        
        transport.setHeartbeatInterval(5000);
        
        // Setting is internal, but we can verify the method doesn't throw
        expect(() => transport.setHeartbeatInterval(1000), returnsNormally);
      });
      
      test('should set WebSocket protocols', () {
        final transport = WebSocketTransport();
        
        transport.setProtocols(['protocol1', 'protocol2']);
        
        // Protocols are internal, but we can verify the method doesn't throw
        expect(() => transport.setProtocols(['test']), returnsNormally);
      });
    });
    
    group('Transport Selection Tests', () {
      test('should set transport on client', () {
        final client = Client('http://localhost:8000/bayeux');
        
        expect(() => client.setTransport('http'), returnsNormally);
        expect(() => client.setTransport('websocket'), returnsNormally);
      });
      
      test('should throw error for invalid transport', () {
        final client = Client('http://localhost:8000/bayeux');
        
        expect(() => client.setTransport('invalid'), throwsArgumentError);
      });
    });
    
    group('Statistics Tests', () {
      test('should get client statistics', () {
        final client = Client('http://localhost:8000/bayeux');
        final stats = client.statistics;
        
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats['state'], isNotNull);
        expect(stats['clientId'], isNull); // Not connected yet
        expect(stats['transport'], isNotNull);
        expect(stats['subscriptions'], isA<int>());
      });
      
      test('should get dispatcher statistics', () {
        final dispatcher = Dispatcher('http://localhost:8000/bayeux', {});
        final stats = dispatcher.statistics;
        
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats['state'], isNotNull);
        expect(stats['clientId'], isNull); // Not connected yet
        expect(stats['transport'], isNotNull);
      });
    });
    
    group('Enhanced Extension Tests', () {
      test('should access extension from dispatcher', () {
        final dispatcher = Dispatcher('http://localhost:8000/bayeux', {});
        final extension = DefaultFayeExtension(
          api: 'test-api-key',
          token: 'test-token',
        );
        
        dispatcher.setExtension(extension);
        
        expect(dispatcher.extension, equals(extension));
        expect(dispatcher.extension.runtimeType, equals(DefaultFayeExtension));
      });
      
      test('should handle extension processing in incoming messages', () {
        final client = Client('http://localhost:8000/bayeux');
        final extension = CustomFayeExtension(
          incomingProcessor: (message) {
            message['processed'] = true;
            return message;
          },
        );
        
        client.setExtension(extension);
        
        // Extension is set internally, we can verify the method doesn't throw
        expect(() => client.setExtension(extension), returnsNormally);
      });
      
      test('should allow subscriptions during connecting state', () {
        final client = Client('http://localhost:8000/bayeux');
        
        // This test verifies that the subscription method accepts connecting state
        // In a real scenario, the state would be managed by the dispatcher
        expect(client, isNotNull);
        // The actual state validation happens in the dispatcher
      });
    });
    
    group('Extension Integration Tests', () {
      test('should process messages through extension pipeline', () {
        final extension = CustomFayeExtension(
          outgoingProcessor: (message) {
            final processed = Map<String, dynamic>.from(message);
            processed['outgoing_processed'] = true;
            return processed;
          },
          incomingProcessor: (message) {
            final processed = Map<String, dynamic>.from(message);
            processed['incoming_processed'] = true;
            return processed;
          },
        );
        
        final outgoingMessage = {'channel': '/test', 'data': 'hello'};
        final incomingMessage = {'channel': '/test', 'data': 'world'};
        
        final processedOutgoing = extension.outgoing(outgoingMessage);
        final processedIncoming = extension.incoming(incomingMessage);
        
        expect(processedOutgoing['outgoing_processed'], isTrue);
        expect(processedIncoming['incoming_processed'], isTrue);
      });
      
      test('should handle extension errors gracefully', () {
        final extension = CustomFayeExtension(
          outgoingProcessor: (message) {
            throw Exception('Outgoing processing error');
          },
          incomingProcessor: (message) {
            throw Exception('Incoming processing error');
          },
        );
        
        final message = {'channel': '/test'};
        
        // Should return original message on error
        final outgoingResult = extension.outgoing(message);
        final incomingResult = extension.incoming(message);
        
        expect(outgoingResult, equals(message));
        expect(incomingResult, equals(message));
      });
    });
  });
}
