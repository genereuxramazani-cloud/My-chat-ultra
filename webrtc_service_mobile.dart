import 'dart:async';
import 'package:flutter/foundation.dart';
import 'webrtc_stub.dart';

class WebRTCService {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  RTCPeerConnection? _peerConnection;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  MediaStream? _localStream;
  String? _currentCallId = null;
  bool _isCaller = false;

  RTCVideoRenderer get localRenderer => _localRenderer;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;
  bool get isCallActive => _peerConnection != null;

  Function(String callId, String callerId, bool isVideo)? onIncomingCall;
  Function()? onCallAnswered;
  Function()? onCallEnded;

  static final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {
        'urls': ['stun:stun.l.google.com:19302']
      },
      {
        'urls': ['stun:stun1.l.google.com:19302']
      },
    ]
  };

  // ── INIT ──────────────────────────────────────────────────────────────────
  Future<void> initRenderers() async {}

  Future<MediaStream?> getLocalStream(
          {bool video = true, bool audio = true}) async =>
      null;

  // ── ÉCOUTER LES APPELS ENTRANTS ──────────────────────────────────────────
  void listenForIncomingCalls(String myPhone) {}

  // ── APPELANT ──────────────────────────────────────────────────────────────
  Future<bool> startCall(
    String callId,
    String receiverId, {
    bool video = true,
    String callerPhone = '',
  }) async =>
      false;

  // ── DESTINATAIRE ──────────────────────────────────────────────────────────
  Future<bool> joinCall(String callId, {bool video = true}) async => false;

  // ── CONTRÔLES ─────────────────────────────────────────────────────────────
  Future<void> toggleMute(bool mute) async {}

  Future<void> toggleCamera(bool enable) async {}

  Future<void> switchCamera() async {}

  // ── FIN D'APPEL ───────────────────────────────────────────────────────────
  Future<void> endCall(String callId) async {}

  // ── DISPOSE ───────────────────────────────────────────────────────────────
  Future<void> dispose() async {}
}
