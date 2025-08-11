import 'dart:core';

/// Grammar patterns for Bayeux protocol validation
class Grammar {
  /// Channel name pattern - matches valid channel names
  /// Format: /segment1/segment2/segment3 where segments contain alphanumeric, -, _, !, ~, (, ), $, @
  static final RegExp channelName = RegExp(
    r'^/(((([a-z]|[A-Z])|[0-9])|(\-|\_|\!|\~|\(|\)|\$|\@)))+(\/(((([a-z]|[A-Z])|[0-9])|(\-|\_|\!|\~|\(|\)|\$|\@)))+)*$',
  );
  
  /// Channel pattern - matches channel patterns with wildcards
  /// Format: /segment1/segment2/* or /segment1/** or /segment1/*/segment2
  static final RegExp channelPattern = RegExp(
    r'^(\/(((([a-z]|[A-Z])|[0-9])|(\-|\_|\!|\~|\(|\)|\$|\@)))+|\*{1,2})+$',
  );
  
  /// Error pattern - matches Bayeux error codes
  /// Format: 3-digit code followed by optional description
  static final RegExp error = RegExp(
    r'^([0-9][0-9][0-9]:(((([a-z]|[A-Z])|[0-9])|(\-|\_|\!|\~|\(|\)|\$|\@)| |/|\*|\.))*(,(((([a-z]|[A-Z])|[0-9])|(\-|\_|\!|\~|\(|\)|\$|\@)| |/|\*|\.))*)*:(((([a-z]|[A-Z])|[0-9])|(\-|\_|\!|\~|\(|\)|\$|\@)| |/|\*|\.))*|[0-9][0-9][0-9]::(((([a-z]|[A-Z])|[0-9])|(\-|\_|\!|\~|\(|\)|\$|\@)| |/|\*|\.))*)$',
  );
  
  /// Version pattern - matches semantic versioning format
  /// Format: major.minor.patch with optional pre-release and build metadata
  static final RegExp version = RegExp(
    r'^([0-9])+(\.(([a-z]|[A-Z])|[0-9])(((([a-z]|[A-Z])|[0-9])|\-|\_))*)*$',
  );
  
  /// Check if a string is a valid channel name
  static bool isValidChannelName(String channel) {
    return channelName.hasMatch(channel);
  }
  
  /// Check if a string is a valid channel pattern (with wildcards)
  static bool isValidChannelPattern(String pattern) {
    // First check if it starts with / and contains only valid characters and wildcards
    if (!pattern.startsWith('/')) return false;
    
    // Split by / and check each segment
    final segments = pattern.split('/').where((s) => s.isNotEmpty).toList();
    
    bool hasWildcard = false;
    for (final segment in segments) {
      // Allow wildcards
      if (segment == '*' || segment == '**') {
        hasWildcard = true;
        continue;
      }
      
      // Check if segment contains only valid characters
      final validSegment = RegExp(r'^((([a-z]|[A-Z])|[0-9])|(\-|\_|\!|\~|\(|\)|\$|\@))+$');
      if (!validSegment.hasMatch(segment)) return false;
    }
    
    // Must contain at least one wildcard to be a pattern
    return hasWildcard;
  }
  
  /// Check if a string is a valid error code
  static bool isValidError(String errorCode) {
    return error.hasMatch(errorCode);
  }
  
  /// Check if a string is a valid version
  static bool isValidVersion(String versionString) {
    return version.hasMatch(versionString);
  }
  
  /// Check if a channel matches a pattern
  static bool channelMatches(String channel, String pattern) {
    if (!isValidChannelName(channel) || !isValidChannelPattern(pattern)) {
      return false;
    }
    
    // Convert pattern to regex
    final regexPattern = pattern
        .replaceAll('**', '.*')  // ** matches any number of segments
        .replaceAll('*', '[^/]*'); // * matches any characters except /
    
    final regex = RegExp('^$regexPattern\$');
    return regex.hasMatch(channel);
  }
}
