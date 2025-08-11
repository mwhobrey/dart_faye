import 'protocol/grammar.dart';

/// Represents a Bayeux channel with validation and pattern matching
class Channel {
  /// Channel name
  final String name;
  
  /// Whether this channel is a pattern (contains wildcards)
  final bool isPattern;
  
  /// Whether this is a meta channel (starts with /meta/)
  final bool isMeta;
  
  /// Whether this is a service channel (starts with /service/)
  final bool isService;
  
  /// Whether this is a wildcard pattern (**)
  final bool isWildcard;
  
  Channel(this.name) : 
    isPattern = Grammar.isValidChannelPattern(name),
    isMeta = name.startsWith('/meta/'),
    isService = name.startsWith('/service/'),
    isWildcard = name.endsWith('/**');
  
  /// Create a channel from a string
  factory Channel.fromString(String channelName) {
    if (!Grammar.isValidChannelName(channelName) && 
        !Grammar.isValidChannelPattern(channelName)) {
      throw ArgumentError('Invalid channel name: $channelName');
    }
    return Channel(channelName);
  }
  
  /// Check if this channel matches a pattern
  bool matches(String pattern) {
    return Grammar.channelMatches(name, pattern);
  }
  
  /// Check if this channel matches another channel
  bool matchesChannel(Channel other) {
    if (isPattern) {
      return Grammar.channelMatches(other.name, name);
    } else if (other.isPattern) {
      return Grammar.channelMatches(name, other.name);
    } else {
      return name == other.name;
    }
  }
  
  /// Get the parent channel (remove last segment)
  Channel? get parent {
    if (name == '/' || name == '/**') return null;
    
    final segments = name.split('/');
    if (segments.length <= 2) return null;
    
    segments.removeLast();
    return Channel(segments.join('/'));
  }
  
  /// Get all parent channels
  List<Channel> get parents {
    final parents = <Channel>[];
    var current = this.parent;
    
    while (current != null) {
      parents.add(current);
      current = current.parent;
    }
    
    return parents;
  }
  
  /// Get the segments of this channel
  List<String> get segments {
    return name.split('/').where((segment) => segment.isNotEmpty).toList();
  }
  
  /// Get the depth of this channel (number of segments)
  int get depth {
    return segments.length;
  }
  
  /// Check if this channel is a child of another channel
  bool isChildOf(Channel parent) {
    if (!name.startsWith(parent.name)) return false;
    if (name == parent.name) return false;
    
    final parentSegments = parent.segments;
    final childSegments = segments;
    
    if (childSegments.length <= parentSegments.length) return false;
    
    for (int i = 0; i < parentSegments.length; i++) {
      if (childSegments[i] != parentSegments[i]) return false;
    }
    
    return true;
  }
  
  /// Check if this channel is a parent of another channel
  bool isParentOf(Channel child) {
    return child.isChildOf(this);
  }
  
  /// Get the wildcard pattern for this channel
  Channel get wildcardPattern {
    if (isPattern) return this;
    return Channel('$name/*');
  }
  
  /// Get the deep wildcard pattern for this channel
  Channel get deepWildcardPattern {
    if (isPattern) return this;
    return Channel('$name/**');
  }
  
  /// Convert to string
  @override
  String toString() => name;
  
  /// Equality operator
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Channel && other.name == name;
  }
  
  /// Hash code
  @override
  int get hashCode => name.hashCode;
}

/// Extension to add channel functionality to strings
extension ChannelString on String {
  /// Convert string to Channel
  Channel get asChannel => Channel.fromString(this);
  
  /// Check if string is a valid channel name
  bool get isValidChannel => Grammar.isValidChannelName(this);
  
  /// Check if string is a valid channel pattern
  bool get isValidChannelPattern => Grammar.isValidChannelPattern(this);
  
  /// Check if this channel matches a pattern
  bool matchesChannel(String pattern) {
    return Grammar.channelMatches(this, pattern);
  }
}
