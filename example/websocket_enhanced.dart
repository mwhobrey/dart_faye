import 'package:dart_faye/dart_faye.dart';

void main() async {
  print('🚀 Starting Enhanced WebSocket Transport Example');
  
  // Create a client with WebSocket endpoint
  final client = Client('ws://localhost:8000/bayeux', {
    'timeout': 30,
    'interval': 1000,
  });
  
  // Set WebSocket transport
  client.setTransport('websocket');
  
  // Get the WebSocket transport instance (for demonstration)
  // Note: In a real application, you'd access this through the transport layer
  
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
  
  // Listen to all messages
  client.messageStream.listen((message) {
    print('📨 Raw message: $message');
  });
  
  try {
    // Connect to the server
    print('🔗 Connecting to WebSocket server...');
    await client.connect();
    
    // Subscribe to multiple channels
    print('📡 Subscribing to channels...');
    
    final chatSubscription = await client.subscribe('/chat/**', (data) {
      print('💬 Chat message: $data');
    });
    
    final notificationSubscription = await client.subscribe('/notifications', (data) {
      print('🔔 Notification: $data');
    });
    
    final statusSubscription = await client.subscribe('/status/*', (data) {
      print('📊 Status update: $data');
    });
    
    // Wait for subscriptions to be established
    await Future.delayed(Duration(seconds: 2));
    
    // Publish messages to different channels
    print('📤 Publishing messages...');
    
    await client.publish('/chat/room1', {
      'user': 'Alice',
      'message': 'Hello from room 1!',
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    await Future.delayed(Duration(seconds: 1));
    
    await client.publish('/chat/room2', {
      'user': 'Bob',
      'message': 'Hello from room 2!',
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    await Future.delayed(Duration(seconds: 1));
    
    await client.publish('/notifications', {
      'type': 'info',
      'title': 'System Update',
      'message': 'Server maintenance completed',
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    await Future.delayed(Duration(seconds: 1));
    
    await client.publish('/status/alice', {
      'status': 'online',
      'lastSeen': DateTime.now().toIso8601String(),
    });
    
    await Future.delayed(Duration(seconds: 1));
    
    await client.publish('/status/bob', {
      'status': 'away',
      'lastSeen': DateTime.now().toIso8601String(),
    });
    
    // Wait for messages to be processed
    await Future.delayed(Duration(seconds: 3));
    
    // Get client statistics
    final stats = client.statistics;
    print('📊 Client statistics:');
    print('  - State: ${stats['state']}');
    print('  - Client ID: ${stats['clientId']}');
    print('  - Transport: ${stats['transport']}');
    print('  - Subscriptions: ${stats['subscriptions'].length}');
    
    // Print subscription details
    for (final subscription in stats['subscriptions']) {
      print('    - ${subscription.channel.name} (${subscription.messageCount} messages)');
    }
    
    // Unsubscribe from channels
    print('📡 Unsubscribing from channels...');
    await client.unsubscribe('/chat/**');
    await client.unsubscribe('/notifications');
    await client.unsubscribe('/status/*');
    
    // Wait for unsubscriptions to complete
    await Future.delayed(Duration(seconds: 2));
    
  } catch (e) {
    print('❌ Error during operation: $e');
  } finally {
    // Disconnect
    print('🔌 Disconnecting...');
    await client.disconnect();
    print('✅ Enhanced WebSocket example completed');
  }
}

/// Example of how to configure WebSocket transport settings
/// (This would typically be done through the transport layer)
void configureWebSocketTransport() {
  // Create WebSocket transport
  final wsTransport = WebSocketTransport();
  
  // Configure auto-reconnection
  wsTransport.setAutoReconnect(
    true,
    maxAttempts: 10,
    delay: 2000,
  );
  
  // Configure heartbeat
  wsTransport.setHeartbeatInterval(30000); // 30 seconds
  
  // Configure protocols
  wsTransport.setProtocols(['bayeux', 'websocket']);
  
  print('🔧 WebSocket transport configured:');
  print('  - Auto-reconnect: enabled (max 10 attempts, 2s delay)');
  print('  - Heartbeat interval: 30 seconds');
  print('  - Protocols: bayeux, websocket');
}
