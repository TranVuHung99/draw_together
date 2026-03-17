import 'package:draw_together_serverpod_client/draw_together_serverpod_client.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

// Sets up a singleton client object that can be used to talk to the server from
// anywhere in our app. The client is generated from your server code.
// The client is set up to connect to a Serverpod running on a local server on
// the default port.
//
// You can connect to a different host by specifying the 'host' parameter.
// Example: Client('http://10.0.2.2:8080/')
// For flutter web: Client('http://localhost:8080/')
final client = Client('http://localhost:8080/')
  ..connectivityMonitor = FlutterConnectivityMonitor();
