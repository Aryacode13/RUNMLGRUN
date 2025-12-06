import 'dart:html' as html;

/// Helper untuk menangkap OAuth code dari URL browser (web only)
class UrlHelper {
  /// Extract code dari current URL
  static String? extractCodeFromUrl() {
    try {
      final uri = Uri.parse(html.window.location.href);
      return uri.queryParameters['code'];
    } catch (e) {
      return null;
    }
  }

  /// Extract error dari current URL
  static String? extractErrorFromUrl() {
    try {
      final uri = Uri.parse(html.window.location.href);
      return uri.queryParameters['error'];
    } catch (e) {
      return null;
    }
  }

  /// Check if current URL contains OAuth callback
  static bool isOAuthCallback() {
    final url = html.window.location.href;
    return url.contains('code=') || url.contains('error=');
  }

  /// Clear URL parameters (remove code/error from URL)
  static void clearUrlParameters() {
    html.window.history.replaceState({}, '', html.window.location.pathname);
  }
}



















