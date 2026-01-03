/// Safely converts any error to a string, handling JS objects
/// This prevents infinite error loops in Flutter Web when JS objects
/// are passed to the error rendering system
String safeErrorToString(dynamic error) {
  try {
    if (error == null) return 'Unknown error';
    if (error is String) return error;
    if (error is Exception) return error.toString();
    // Try toString first
    final str = error.toString();
    // If toString returns something that looks like a JS object, extract message
    if (str.contains('LegacyJavaScriptObject') || str.contains('Instance of')) {
      return 'An error occurred. Please try again.';
    }
    return str;
  } catch (e) {
    // If even toString fails, return a safe message
    return 'An error occurred. Please try again.';
  }
}
