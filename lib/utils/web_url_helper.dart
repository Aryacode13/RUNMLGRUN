// Web-only URL helper using conditional import
// Export the class from the appropriate implementation
export 'web_url_helper_stub.dart' if (dart.library.html) 'web_url_helper_web.dart';

