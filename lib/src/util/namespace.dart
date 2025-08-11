/// Utility class for handling Bayeux channel namespaces
class Namespace {
  /// Check if a channel is in a namespace
  static bool isInNamespace(String channel, String namespace) {
    if (!channel.startsWith('/') || !namespace.startsWith('/')) {
      return false;
    }
    
    if (namespace == '/') {
      return true;
    }
    
    if (channel == namespace) {
      return true;
    }
    
    return channel.startsWith('$namespace/');
  }
  
  /// Get the namespace of a channel
  static String? getNamespace(String channel) {
    if (!channel.startsWith('/')) {
      return null;
    }
    
    final segments = channel.split('/').where((s) => s.isNotEmpty).toList();
    
    if (segments.isEmpty) {
      return '/';
    }
    
    return '/${segments.first}';
  }
  
  /// Get the relative path from a namespace
  static String? getRelativePath(String channel, String namespace) {
    if (!isInNamespace(channel, namespace)) {
      return null;
    }
    
    if (namespace == '/') {
      return channel;
    }
    
    if (channel == namespace) {
      return '/';
    }
    
    return channel.substring(namespace.length);
  }
  
  /// Check if a channel is a meta channel
  static bool isMetaChannel(String channel) {
    return channel.startsWith('/meta/');
  }
  
  /// Check if a channel is a service channel
  static bool isServiceChannel(String channel) {
    return channel.startsWith('/service/');
  }
  
  /// Check if a channel is a wildcard pattern
  static bool isWildcardPattern(String channel) {
    return channel.contains('*');
  }
  
  /// Get all parent namespaces of a channel
  static List<String> getParentNamespaces(String channel) {
    if (!channel.startsWith('/')) {
      return [];
    }
    
    final segments = channel.split('/').where((s) => s.isNotEmpty).toList();
    final namespaces = <String>[];
    
    for (int i = 0; i < segments.length; i++) {
      final namespace = '/${segments.take(i + 1).join('/')}';
      namespaces.add(namespace);
    }
    
    return namespaces;
  }
  
  /// Get all child namespaces of a namespace
  static List<String> getChildNamespaces(String namespace, List<String> channels) {
    if (!namespace.startsWith('/')) {
      return [];
    }
    
    return channels.where((channel) => isInNamespace(channel, namespace)).toList();
  }
  
  /// Normalize a channel name
  static String normalize(String channel) {
    if (!channel.startsWith('/')) {
      channel = '/$channel';
    }
    
    // Remove trailing slash unless it's the root
    if (channel.length > 1 && channel.endsWith('/')) {
      channel = channel.substring(0, channel.length - 1);
    }
    
    return channel;
  }
  
  /// Join namespace parts
  static String join(List<String> parts) {
    final normalizedParts = parts.map((part) {
      if (part.startsWith('/')) {
        return part.substring(1);
      }
      return part;
    }).where((part) => part.isNotEmpty).toList();
    
    return '/${normalizedParts.join('/')}';
  }
  
  /// Split a channel into parts
  static List<String> split(String channel) {
    if (!channel.startsWith('/')) {
      return [];
    }
    
    return channel.split('/').where((part) => part.isNotEmpty).toList();
  }
}
