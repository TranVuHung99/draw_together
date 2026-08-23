import 'package:draw_together_serverpod_client/draw_together_serverpod_client.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:serverpod_flutter/serverpod_flutter.dart';

/// Where the server is, as this device can reach it.
///
/// On web the host is taken from the page's own URL rather than hardcoded, so
/// a phone that opened the app at `http://10.0.0.5:9999` talks to the server on
/// `10.0.0.5` instead of to itself. `localhost` would resolve to the phone.
///
/// Override it explicitly when the server is somewhere else:
/// `flutter run --dart-define=SERVER_URL=http://10.0.0.5:8080/`
String get serverUrl {
  const override = String.fromEnvironment('SERVER_URL');
  if (override.isNotEmpty) return override;
  if (!kIsWeb) return 'http://localhost:8080/';

  final host = Uri.base.host;
  // `flutter run --web-hostname=0.0.0.0` opens the page on 0.0.0.0, but Chrome
  // has blocked requests to that address since v133, so it cannot be used as an
  // API host. It means "this machine" here, which is what localhost says.
  final apiHost = (host.isEmpty || host == '0.0.0.0') ? 'localhost' : host;
  return 'http://$apiHost:8080/';
}

// Sets up a singleton client object that can be used to talk to the server from
// anywhere in our app. The client is generated from your server code.
final client = Client(serverUrl)
  ..connectivityMonitor = FlutterConnectivityMonitor();
