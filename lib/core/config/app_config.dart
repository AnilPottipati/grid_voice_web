import 'package:web/web.dart' as web;

/// Where the Grid server is.
///
/// By default the app talks to the server it was loaded from, so the login
/// cookie works (the server sets a same-site cookie). To point a local run at
/// another server use `--dart-define=SERVER_URL=https://host`.
class AppConfig {
  const AppConfig._();

  static const _override = String.fromEnvironment('SERVER_URL');

  /// `https://host[:port]`, no trailing slash.
  static String get serverOrigin =>
      _override.isNotEmpty ? _override : web.window.location.origin;

  /// The live voice socket, e.g. `wss://host/ws/live`.
  static Uri liveSocketUri(Map<String, String> query) {
    final origin = Uri.parse(serverOrigin);
    return Uri(
      scheme: origin.scheme == 'https' ? 'wss' : 'ws',
      host: origin.host,
      port: origin.hasPort ? origin.port : null,
      path: '/ws/live',
      queryParameters: query,
    );
  }

  /// The assistant gives up listening after this long without any news.
  static const idleStop = Duration(minutes: 5);
}
