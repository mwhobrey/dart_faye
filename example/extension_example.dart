import 'package:dart_faye/dart_faye.dart';

void main() async {
  print('🚀 Starting Faye Extension Example');
  
  // Create a client
  final client = Client('http://localhost:8000/bayeux', {
    'timeout': 30,
    'interval': 1000,
  });
  
  // Create an authentication extension
  final authExtension = DefaultFayeExtension(
    api: 'your-api-key-here',
    token: 'your-auth-token-here',
    onLog: (level, data) {
      print('🔐 [Extension $level] $data');
    },
  );
  
  // Set the extension on the client
  client.setExtension(authExtension);
  
  // Create a custom extension for message transformation
  final customExtension = CustomFayeExtension(
    outgoingProcessor: (message) {
      // Add timestamp to all outgoing messages
      if (message['data'] != null && message['data'] is Map) {
        final data = Map<String, dynamic>.from(message['data']);
        data['timestamp'] = DateTime.now().toIso8601String();
        message['data'] = data;
      }
      return message;
    },
    incomingProcessor: (message) {
      // Log all incoming messages
      print('📥 Received message: $message');
      return message;
    },
  );
  
  // Set the custom extension (this will replace the auth extension)
  client.setExtension(customExtension);
  
  // Listen to connection state changes
  client.stateStream.listen((state) {
    switch (state) {
      case Client.unconnected:
        print('📡 Disconnected');
        break;
      case Client.connecting:
        print('🔄 Connecting...');
        break;
      case Client.connected:
        print('✅ Connected');
        break;
      case Client.disconnected:
        print('❌ Disconnected');
        break;
    }
  });
  
  // Listen to errors
  client.errorStream.listen((error) {
    print('❌ Error: ${error.message}');
  });
  
  try {
    // Connect to the server
    print('🔗 Connecting to server...');
    await client.connect();
    
    // Subscribe to a channel
    print('📡 Subscribing to /chat/room1...');
    await client.subscribe('/chat/room1', (data) {
      print('📨 Received message: $data');
    });
    
    // Wait a moment for subscription to be established
    await Future.delayed(Duration(seconds: 1));
    
    // Publish a message (extension will add timestamp)
    print('📤 Publishing message...');
    await client.publish('/chat/room1', {
      'user': 'Alice',
      'message': 'Hello, world!',
    });
    
    // Wait for message to be processed
    await Future.delayed(Duration(seconds: 2));
    
    // Publish another message
    print('📤 Publishing another message...');
    await client.publish('/chat/room1', {
      'user': 'Bob',
      'message': 'Hello from Bob!',
    });
    
    // Wait for message to be processed
    await Future.delayed(Duration(seconds: 2));
    
    // Unsubscribe
    print('📡 Unsubscribing from /chat/room1...');
    await client.unsubscribe('/chat/room1');
    
    // Get client statistics
    final stats = client.statistics;
    print('📊 Client statistics:');
    print('  - State: ${stats['state']}');
    print('  - Client ID: ${stats['clientId']}');
    print('  - Transport: ${stats['transport']}');
    print('  - Subscriptions: ${stats['subscriptions']}');
    
  } catch (e) {
    print('❌ Error during operation: $e');
  } finally {
    // Disconnect
    print('🔌 Disconnecting...');
    await client.disconnect();
    print('✅ Extension example completed');
  }
}
