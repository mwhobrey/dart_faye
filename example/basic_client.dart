import 'package:dart_faye/dart_faye.dart';

void main() async {
  print('🚀 Starting Faye Basic Client Example');
  
  // Create a client
  final client = Client('http://localhost:8000/bayeux');
  
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
    
    // Publish a message
    print('📤 Publishing message...');
    await client.publish('/chat/room1', {
      'user': 'Alice',
      'message': 'Hello, world!',
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Wait for message to be processed
    await Future.delayed(Duration(seconds: 2));
    
    // Publish another message
    print('📤 Publishing another message...');
    await client.publish('/chat/room1', {
      'user': 'Bob',
      'message': 'Hello from Bob!',
      'timestamp': DateTime.now().toIso8601String(),
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
    print('✅ Example completed');
  }
}
