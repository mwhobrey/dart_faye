import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:dart_faye/faye.dart';

class ChatApp {
  final Client client;
  final String username;
  final List<String> rooms = ['/chat/general', '/chat/random', '/chat/help'];
  final Map<String, Subscription> subscriptions = {};
  
  ChatApp(this.client, this.username);
  
  Future<void> start() async {
    print('🚀 Starting Chat App for user: $username');
    
    // Set up event listeners
    _setupEventListeners();
    
    try {
      // Connect to server
      await client.connect();
      
      // Subscribe to all rooms
      await _subscribeToRooms();
      
      // Start chat loop
      await _chatLoop();
      
    } catch (e) {
      print('❌ Error in chat app: $e');
    } finally {
      await _cleanup();
    }
  }
  
  void _setupEventListeners() {
    // Listen to connection state changes
    client.stateStream.listen((state) {
      switch (state) {
        case Client.connected:
          print('✅ Connected to chat server');
          break;
        case Client.disconnected:
          print('❌ Disconnected from chat server');
          break;
        case Client.connecting:
          print('🔄 Connecting to chat server...');
          break;
        case Client.unconnected:
          print('📡 Not connected');
          break;
      }
    });
    
    // Listen to errors
    client.errorStream.listen((error) {
      print('❌ Chat error: ${error.message}');
    });
    
    // Listen to all messages
    client.messageStream.listen((message) {
      final channel = message['channel'] as String?;
      final data = message['data'];
      
      if (channel != null && data != null && data is Map) {
        final sender = data['user'] as String?;
        final msg = data['message'] as String?;
        
        if (sender != null && msg != null && sender != username) {
          print('💬 [$channel] $sender: $msg');
        }
      }
    });
  }
  
  Future<void> _subscribeToRooms() async {
    print('📡 Subscribing to chat rooms...');
    
    for (final room in rooms) {
      try {
        final subscription = await client.subscribe(room, (data) {
          // This will be handled by the general message stream
        });
        
        subscriptions[room] = subscription;
        print('✅ Subscribed to $room');
      } catch (e) {
        print('❌ Failed to subscribe to $room: $e');
      }
    }
  }
  
  Future<void> _chatLoop() async {
    print('\n💬 Chat started! Type your messages:');
    print('  Format: <room> <message>');
    print('  Example: general Hello everyone!');
    print('  Type "quit" to exit\n');
    
    final inputStream = stdin.transform(systemEncoding.decoder).transform(const LineSplitter());
    
    await for (final line in inputStream) {
      if (line.toLowerCase() == 'quit') {
        break;
      }
      
      final parts = line.split(' ');
      if (parts.length < 2) {
        print('❌ Invalid format. Use: <room> <message>');
        continue;
      }
      
      final roomName = parts[0];
      final message = parts.skip(1).join(' ');
      final room = '/chat/$roomName';
      
      if (!rooms.contains(room)) {
        print('❌ Unknown room: $roomName. Available rooms: ${rooms.map((r) => r.split('/').last).join(', ')}');
        continue;
      }
      
      try {
        await client.publish(room, {
          'user': username,
          'message': message,
          'timestamp': DateTime.now().toIso8601String(),
        });
        
        print('📤 Sent to $roomName: $message');
      } catch (e) {
        print('❌ Failed to send message: $e');
      }
    }
  }
  
  Future<void> _cleanup() async {
    print('\n🧹 Cleaning up...');
    
    // Unsubscribe from all rooms
    for (final room in rooms) {
      try {
        await client.unsubscribe(room);
        print('✅ Unsubscribed from $room');
      } catch (e) {
        print('❌ Failed to unsubscribe from $room: $e');
      }
    }
    
    // Disconnect
    await client.disconnect();
    print('✅ Chat app closed');
  }
}

void main() async {
  print('🎯 Faye Chat Application Example');
  print('================================\n');
  
  // Get username from command line arguments or prompt
  String username;
  stdout.write('Enter your username: ');
  username = stdin.readLineSync() ?? 'Anonymous';
  
  // Create client
  final client = Client('http://localhost:8000/bayeux', {
    'timeout': 30,
    'interval': 1000,
  });
  
  // Create and start chat app
  final chatApp = ChatApp(client, username);
  await chatApp.start();
}
