// ignore_for_file: avoid_print
import 'package:flutter/widgets.dart';

class RTCVideoRenderer {
  dynamic srcObject;
  Future<void> initialize() async {}
  Future<void> dispose() async {}
}

class MediaStream {
  List getAudioTracks() => [];
  List getVideoTracks() => [];
  List getTracks() => [];
}

class RTCPeerConnection {
  Future<void> close() async {}
}

class RTCSessionDescription {
  RTCSessionDescription(this.sdp, this.type);
  String? sdp;
  String? type;
}

class RTCIceCandidate {
  RTCIceCandidate(this.candidate, this.sdpMid, this.sdpMLineIndex);
  String? candidate;
  String? sdpMid;
  int? sdpMLineIndex;
}

class RTCTrackEvent {
  dynamic track;
  List streams = [];
}

class RTCVideoView extends StatelessWidget {
  final dynamic srcObject;
  final bool mirror;
  final String objectFit;

  const RTCVideoView(this.srcObject,
      {super.key, this.mirror = false, this.objectFit = 'cover'});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<RTCPeerConnection> createPeerConnection(Map config) async =>
    RTCPeerConnection();
Future<MediaStream> createLocalMediaStream(String label) async => MediaStream();
