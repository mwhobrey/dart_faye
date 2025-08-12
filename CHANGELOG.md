# Changelog

## 1.2.0

### Features
- **Enhanced Extension Support**: Improved extension processing for both incoming and outgoing messages
  - Extension processing now applied to incoming messages in Client
  - Better error handling and logging for extension operations
  - Extension type and method availability logging for debugging
- **Improved Subscription State Management**: Enhanced subscription handling during connection phases
  - Allow subscriptions during connecting state (not just connected state)
  - Better support for extensions that need to subscribe during handshake response processing
  - More robust state validation for subscription operations

### Bug Fixes
- **Extension Access**: Added proper extension getter in Dispatcher for Client access
- **Message Processing**: Fixed extension processing in incoming message handling
- **State Management**: Improved connection state handling for subscription operations

### Technical Improvements
- Enhanced logging for extension operations and debugging
- Better error handling in extension processing
- Improved state validation for subscription operations
- More comprehensive extension integration throughout the message flow

## 1.1.0

### Features
- **Extension Support**: Added support for Faye extensions to enable authentication and message transformation
  - New `setExtension()` method on Client and Dispatcher classes
  - Extension processing in outgoing messages for authentication headers
  - Support for custom extension classes implementing `outgoing()` and `incoming()` methods
- **Comprehensive Logging**: Added extensive logging throughout the package for debugging
  - Logger integration in Client, Dispatcher, and Transport classes
  - Detailed connection state tracking and error reporting
  - Debug information for message processing and extension handling
- **Improved WebSocket Transport**: Enhanced WebSocket transport reliability
  - Better handling of batch messages (arrays) from server responses
  - Improved connection order (transport connection before handshake)
  - Automatic transport selection for WebSocket URLs (wss://, ws://)
  - Removed protocol restrictions to allow server protocol selection

### Bug Fixes
- **Connection Order**: Fixed dispatcher to connect transport before handshake
- **State Constants**: Corrected state constant usage (integer values instead of enum-like constants)
- **Message Processing**: Fixed extension message processing to ensure modified messages are returned
- **Batch Message Handling**: Added support for server responses in array format
- **Transport Selection**: Improved automatic transport selection logic

### Technical Improvements
- Enhanced error handling and debugging capabilities
- Better integration with Flutter applications
- Improved authentication flow with extension support
- More robust connection management

## 1.0.0

### Features
- Complete Dart implementation of Faye publish-subscribe messaging system
- Bayeux protocol compliance with channel validation and pattern matching
- HTTP transport support (long-polling and callback-polling)
- WebSocket transport with automatic reconnection and heartbeat
- Channel pattern matching with wildcards (`*` and `**`)
- Subscription management with callbacks
- Publication tracking and error handling
- Comprehensive error types (network, timeout, protocol, authentication, etc.)
- Utility classes for channel namespaces and validation
- Stream-based API for reactive programming
- Flutter compatibility

### Technical Details
- Dart SDK: >=3.0.0
- Flutter: >=3.0.0
- Dependencies: http, web_socket_channel, crypto, uuid, logging, json_annotation
- All tests passing (38 tests)
- MIT License
