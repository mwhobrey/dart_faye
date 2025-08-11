# Faye for Dart

A Dart implementation of the Faye publish-subscribe messaging system, compatible with the Bayeux protocol.

## Features

- **Bayeux Protocol Support**: Full implementation of the Bayeux protocol for real-time messaging
- **Multiple Transport Types**: Support for HTTP long-polling, WebSocket, and callback-polling
- **Channel Management**: Comprehensive channel validation and pattern matching
- **Error Handling**: Robust error handling with detailed error types
- **Streaming API**: Modern Dart streams for reactive programming
- **Cross-Platform**: Works on Dart VM, Flutter, and web platforms
- **Type Safety**: Full type safety with Dart's strong typing system

## Installation

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  faye: ^1.0.0
```

Then run:

```bash
dart pub get
```

## Quick Start

### Basic Usage

```dart
import 'package:faye/faye.dart';

void main() async {
  // Create a client
  final client = Client('http://localhost:8000/bayeux');
  
  // Connect to the server
  await client.connect();
  
  // Subscribe to a channel
  final subscription = await client.subscribe('/chat/room1', (data) {
    print('Received message: $data');
  });
  
  // Publish a message
  await client.publish('/chat/room1', {
    'user': 'Alice',
    'message': 'Hello, world!'
  });
  
  // Unsubscribe when done
  await client.unsubscribe('/chat/room1');
  
  // Disconnect
  await client.disconnect();
}
```

### Advanced Usage

```dart
import 'package:faye/faye.dart';

void main() async {
  // Create client with options
  final client = Client('http://localhost:8000/bayeux', {
    'timeout': 30,
    'interval': 1000,
  });
  
  // Listen to connection state changes
  client.stateStream.listen((state) {
    switch (state) {
      case Client.unconnected:
        print('Disconnected');
        break;
      case Client.connecting:
        print('Connecting...');
        break;
      case Client.connected:
        print('Connected');
        break;
      case Client.disconnected:
        print('Disconnected');
        break;
    }
  });
  
  // Listen to errors
  client.errorStream.listen((error) {
    print('Error: ${error.message}');
  });
  
  // Connect
  await client.connect();
  
  // Subscribe to multiple channels
  final chatSubscription = await client.subscribe('/chat/**', (data) {
    print('Chat message: $data');
  });
  
  final notificationSubscription = await client.subscribe('/notifications', (data) {
    print('Notification: $data');
  });
  
  // Publish messages
  await client.publish('/chat/room1', {'message': 'Hello from room 1'});
  await client.publish('/chat/room2', {'message': 'Hello from room 2'});
  await client.publish('/notifications', {'type': 'info', 'text': 'System update'});
  
  // Get client statistics
  final stats = client.statistics;
  print('Client stats: $stats');
  
  // Clean up
  await client.close();
}
```

## API Reference

### Client

The main client class for connecting to a Bayeux server.

#### Constructor

```dart
Client(String endpoint, [Map<String, dynamic>? options])
```

- `endpoint`: The Bayeux server endpoint URL
- `options`: Optional configuration options

#### Methods

- `connect({Map<String, String>? headers})`: Connect to the server
- `disconnect()`: Disconnect from the server
- `subscribe(String channel, SubscriptionCallback callback)`: Subscribe to a channel
- `unsubscribe(String channel)`: Unsubscribe from a channel
- `publish(String channel, dynamic data)`: Publish a message to a channel
- `close()`: Close the client and clean up resources

#### Properties

- `state`: Current connection state
- `clientId`: Server-assigned client ID
- `transport`: Current transport type
- `subscriptions`: List of active subscriptions
- `messageStream`: Stream of incoming messages
- `stateStream`: Stream of state changes
- `errorStream`: Stream of errors

### Channel

Represents a Bayeux channel with validation and pattern matching.

```dart
final channel = Channel('/chat/room1');
print(channel.isMeta); // false
print(channel.isService); // false
print(channel.isPattern); // false
print(channel.matches('/chat/*')); // true
```

### Subscription

Represents a subscription to a channel.

```dart
final subscription = await client.subscribe('/chat/room1', (data) {
  print('Received: $data');
});

print(subscription.active); // true
print(subscription.messageCount); // 0
subscription.cancel(); // Cancel the subscription
```

### Error Handling

The library provides comprehensive error handling with specific error types:

```dart
client.errorStream.listen((error) {
  if (error.isNetworkError) {
    print('Network error: ${error.message}');
  } else if (error.isAuthenticationError) {
    print('Authentication error: ${error.message}');
  } else if (error.isSubscriptionError) {
    print('Subscription error: ${error.message}');
  }
});
```

## Transport Types

### HTTP Long-Polling

Default transport that works with any HTTP server supporting the Bayeux protocol.

```dart
client.setTransport('http');
```

### WebSocket

For better performance when the server supports WebSocket transport.

```dart
client.setTransport('websocket');
```

### Callback-Polling

For environments where WebSocket is not available and JSONP is required.

```dart
client.setTransport('callback-polling');
```

## Channel Patterns

The library supports channel patterns for subscribing to multiple channels:

- `/chat/*`: Matches `/chat/room1`, `/chat/room2`, etc.
- `/chat/**`: Matches `/chat/room1`, `/chat/room1/messages`, etc.
- `/users/*/status`: Matches `/users/alice/status`, `/users/bob/status`, etc.

## Error Types

- `FayeError.network()`: Network-related errors
- `FayeError.timeout()`: Timeout errors
- `FayeError.protocol()`: Protocol errors
- `FayeError.authentication()`: Authentication errors
- `FayeError.subscription()`: Subscription errors
- `FayeError.publication()`: Publication errors
- `FayeError.channel()`: Channel validation errors

## Examples

See the `example/` directory for complete working examples:

- `basic_client.dart`: Basic client usage
- `chat_app.dart`: Simple chat application
- `multi_transport.dart`: Using multiple transport types
- `error_handling.dart`: Comprehensive error handling

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

This implementation is based on the original Faye library by James Coglan and follows the Bayeux protocol specification.
