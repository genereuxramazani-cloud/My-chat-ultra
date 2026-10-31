// Conditional export: use the real `flutter_webrtc` on native (io),
// and the local stub on web to avoid pulling the package into the web bundle.
export 'webrtc_stub.dart'
    if (dart.library.io) 'package:flutter_webrtc/flutter_webrtc.dart';
