// Web implementation using dart:html
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class WebUrlHelper {
  static String? extractCodeFromUrl() {
    try {
      final uri = Uri.parse(html.window.location.href);
      return uri.queryParameters['code'];
    } catch (e) {
      return null;
    }
  }

  static String? extractErrorFromUrl() {
    try {
      final uri = Uri.parse(html.window.location.href);
      return uri.queryParameters['error'];
    } catch (e) {
      return null;
    }
  }

  static void clearUrlParameters() {
    html.window.history.replaceState({}, '', html.window.location.pathname);
  }

  static String getCurrentUrl() {
    return html.window.location.href;
  }

  /// Get the origin URL of the current app (e.g., http://localhost:8080)
  static String getAppOrigin() {
    return html.window.location.origin;
  }
}

