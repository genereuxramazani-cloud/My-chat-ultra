import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/webrtc_service.dart';
import '../services/webrtc_types.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme.dart';

class LiveScreen extends StatefulWidget {
  final String userPhone;

  const LiveScreen({super.key, required this.userPhone});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final _webrtcService = WebRTCService();
  bool _joined = false;
  bool _micMuted = false;
  bool _camOff = false;
  bool _isStarting = false;
  String? _remoteUserId;
  String? _error;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _leaveLiveRoom();
    super.dispose();
  }

  Future<void> _startWebRTC() async {
    // WebRTC Live implementation triggered explicitly by the user.
    if (kIsWeb) {
      setState(() {
        _error = 'Live indisponible sur web';
      });
      return;
    }

    final result = await [Permission.camera, Permission.microphone].request();
    if (result[Permission.camera] != PermissionStatus.granted ||
        result[Permission.microphone] != PermissionStatus.granted) {
      setState(() {
        _error = 'Autorisation caméra/micro requise pour démarrer le live.';
      });
      return;
    }

    setState(() {
      _isStarting = true;
      _error = null;
    });

    try {
      await _webrtcService.initRenderers();
      await _webrtcService.getLocalStream(video: true, audio: true);

      setState(() {
        _joined = true;
      });
    } catch (e) {
      setState(() {
        _error = 'Échec du live : $e';
      });
    } finally {
      setState(() {
        _isStarting = false;
      });
    }
  }

  Future<void> _leaveLiveRoom() async {
    try {
      if (!kIsWeb) {
        await _webrtcService.dispose();
      }
      setState(() {
        _joined = false;
        _remoteUserId = null;
      });
    } catch (_) {
      // ignore errors on dispose
    }
  }

  void _toggleMic() async {
    _micMuted = !_micMuted;
    if (!kIsWeb) {
      await _webrtcService.toggleMute(_micMuted);
    }
    setState(() {});
  }

  void _toggleCam() async {
    _camOff = !_camOff;
    if (!kIsWeb) {
      await _webrtcService.toggleCamera(!_camOff);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.18),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Live public',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: kGradientBg),
        child: _error != null
            ? _buildErrorState()
            : !_joined
                ? _buildLoadingState()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 700;
                      final controlSize = isWide ? 64.0 : 56.0;

                      return Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRect(
                                child: !kIsWeb
                                    ? (_remoteUserId != null
                                        ? RTCVideoView(
                                            _webrtcService.remoteRenderer)
                                        : RTCVideoView(
                                            _webrtcService.localRenderer))
                                    : Center(
                                        child: Text(
                                          'Live WebRTC désactivé sur le web',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 16),
                                        ),
                                      )),
                          ),
                          if (!kIsWeb)
                            Positioned(
                              top: 16,
                              left: 16,
                              right: 16,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _glassPill(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              color: Colors.greenAccent,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          const Text(
                                            'EN DIRECT',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            _remoteUserId != null
                                                ? 'À 1 spectateur'
                                                : 'En attente',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _glassPill(
                                    child: Text(
                                      'ROOM PUBLIC LIVE',
                                      style: TextStyle(
                                        color: kCyan,
                                        fontSize: isWide ? 12 : 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (!kIsWeb && _remoteUserId != null && !_camOff)
                            Positioned(
                              top: 88,
                              right: 16,
                              width: isWide ? 180 : 128,
                              height: isWide ? 240 : 180,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: kCyan.withOpacity(0.35)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.25),
                                        blurRadius: 24,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: RTCVideoView(
                                      _webrtcService.localRenderer),
                                ),
                              ),
                            ),
                          if (!kIsWeb)
                            Positioned(
                              bottom: 18,
                              left: 16,
                              right: 16,
                              child: SafeArea(
                                top: false,
                                child: Center(
                                  child: Container(
                                    constraints:
                                        const BoxConstraints(maxWidth: 360),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.24),
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                          color:
                                              Colors.white.withOpacity(0.12)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 30,
                                          offset: const Offset(0, 12),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _liveControlButton(
                                          icon: _micMuted
                                              ? Icons.mic_off
                                              : Icons.mic,
                                          color: _micMuted ? Colors.red : kCyan,
                                          size: controlSize,
                                          onTap: _toggleMic,
                                        ),
                                        _liveControlButton(
                                          icon: Icons.call_end,
                                          color: Colors.red,
                                          size: controlSize + 8,
                                          onTap: () =>
                                              Navigator.of(context).maybePop(),
                                        ),
                                        _liveControlButton(
                                          icon: _camOff
                                              ? Icons.videocam_off
                                              : Icons.videocam,
                                          color: _camOff ? Colors.red : kViolet,
                                          size: controlSize,
                                          onTap: _toggleCam,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.24),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Prêt à démarrer le live',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Appuie sur le bouton pour lancer la caméra et le micro.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 24),
            if (_isStarting) ...[
              const SizedBox(
                width: 42,
                height: 42,
                child:
                    CircularProgressIndicator(color: kViolet, strokeWidth: 3),
              ),
              const SizedBox(height: 18),
              const Text(
                'Démarrage du live...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ] else ...[
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kViolet,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                ),
                onPressed: _startWebRTC,
                child: const Text('Démarrer le live'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.24),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.live_tv_outlined, color: kPink, size: 34),
            const SizedBox(height: 14),
            const Text(
              'Live indisponible',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.25)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => _startWebRTC(),
                  child: const Text('Réessayer'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kViolet,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Retour'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassPill({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: child,
    );
  }

  Widget _liveControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double size = 50,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.18),
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(icon, color: color, size: size * 0.45),
      ),
    );
  }
}
