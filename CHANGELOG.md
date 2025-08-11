# Changelog

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
