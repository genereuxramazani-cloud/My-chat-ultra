import 'webrtc_stub.dart';

class WebRTCService {
  static final WebRTCService _instance = WebRTCService._internal();

  factory WebRTCService() => _instance;

  WebRTCService._internal();

  Function(String, String, bool)? onIncomingCall;

  Function()? onCallAnswered;

  Function()? onCallEnded;

  bool get isCallActive => false;

  dynamic get localRenderer => null;

  dynamic get remoteRenderer => null;

  Future<void> initRenderers() async {}

  Future<void> getLocalStream({bool video = true, bool audio = true}) async {}

  Future<bool> startCall(String a, String b,
          {bool video = true, String callerPhone = ''}) async =>
      false;

  Future<bool> joinCall(String id, {bool video = true}) async => false;

  Future<void> endCall(String id) async {}

  Future<void> toggleMute(bool m) async {}

  Future<void> toggleCamera(bool e) async {}

  Future<void> switchCamera() async {}

  void listenForIncomingCalls(String p) {}

  Future<void> dispose() async {}
}
