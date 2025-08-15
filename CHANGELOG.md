# Changelog

## 1.2.3

### Bug Fixes
- **Dispatcher Type Check**: Fixed unnecessary type check warning in dispatcher's `_sendMessage` method
  - Removed redundant type check that was flagged by the Dart analyzer
  - Improved code quality and eliminated linter warnings

### Dependency Updates
- **Package Cleanup**: Removed unused dependencies and updated to latest versions
  - Removed unused `crypto`, `convert`, and `json_annotation` dependencies from core package
  - Updated `http` from ^1.1.0 to ^1.2.0
  - Updated `web_socket_channel` from ^2.4.0 to ^3.0.3
  - Updated `uuid` from ^4.0.0 to ^4.3.3
  - Updated `meta` from ^1.9.0 to ^1.12.0
  - Updated `lints` from ^3.0.0 to ^6.0.0
  - Moved `crypto` and `convert` to dev_dependencies for test scripts

### Technical Improvements
- Reduced package size by removing unused dependencies
- Improved dependency management and version compatibility
- Enhanced code quality with latest linter rules

## 1.2.2

### Bug Fixes
- **Bayeux Response Handling**: Fixed critical bug where the package failed to handle Bayeux protocol responses that come as JSON arrays
  - Added `extractBayeuxMessage()` helper function to handle both single object and array responses
  - Updated HTTP transport, Client, and Dispatcher to properly handle array responses
  - Fixed "type 'String' is not a subtype of type 'int' of 'index'" error when accessing response properties
  - Enhanced HTTP transport's `send()` method to properly handle responses for immediate requests
  - Added comprehensive tests for Bayeux response handling scenarios
  - Made the package compatible with servers that return responses in the standard Bayeux array format

### Technical Improvements
- Added helper functions for consistent Bayeux response handling across all components
- Enhanced error handling for empty arrays and invalid response types
- Improved compatibility with various Bayeux server implementations
- Added test coverage for response handling edge cases

## 1.2.1

### Maintenance
- Fixed repository urls

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
