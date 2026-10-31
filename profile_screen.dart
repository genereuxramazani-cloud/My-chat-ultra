import 'dart:async';

import 'dart:io';

import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_storage/firebase_storage.dart';

import 'package:flutter_contacts/flutter_contacts.dart';

import 'package:image_picker/image_picker.dart';

import 'package:file_picker/file_picker.dart';

import 'package:mime/mime.dart';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import 'package:permission_handler/permission_handler.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:audioplayers/audioplayers.dart';

import 'package:record/record.dart';

import '../theme.dart';
import '../app_localizations.dart';

import '../presence_service.dart';

import '../widgets/glass_add_button.dart';

class ProfileScreen extends StatefulWidget {
  final String userPhone;

  final ValueNotifier<bool>? privateChatNotifier;

  final VoidCallback? onReturnToFeed;

  final String? initialContact;

  final Map<String, dynamic>? initialContactData;

  const ProfileScreen({
    super.key,
    required this.userPhone,
    this.privateChatNotifier,
    this.onReturnToFeed,
    this.initialContact,
    this.initialContactData,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  String? _selectedContact;

  Map<String, dynamic>? _selectedContactData;

  final _msgC = TextEditingController();

  String _contactsSearch = '';

  bool _isTyping = false;

  bool _isAddingContact = false;

  bool _ghostMode = false;

  bool _isRecording = false;

  bool _isSendingFile = false;

  double _voiceUploadProgress = 0.0;

  String _voiceUploadStatus = '';

  static const int _voiceSampleRate = 44100;

  static const int _voiceChannels = 1;

  // Private screen settings

  int _privateFontSize = 5; // 1..10, default 5

  Map<String, dynamic>? _replyToMessage;

  String? _editingMessageId;

  Map<String, dynamic>? _pinnedMessage;

  final _recorder = AudioRecorder();

  final _audioPlayer = AudioPlayer();

  String? _tempAudioPath;

  late final AnimationController _voiceMeterController;

  String t(String key, [Map<String, String>? params]) =>
      AppLocalizations.of(context)?.translate(key, params) ?? key;

  BytesBuilder? _voiceRecordingBuffer;

  StreamSubscription<Uint8List>? _voiceRecordingSubscription;

  RtcEngine? _agoraEngine;

  bool _inCall = false;

  bool _isVideoCall = false;

  bool _micMuted = false;

  bool _camOff = false;

  int? _remoteUid;

  String _getChatId(String a, String b) {
    final sorted = [a, b]..sort();

    return '${sorted[0]}_${sorted[1]}';
  }

  String _resolveThreadPeer(Map<String, dynamic> data) {
    final members = List<String>.from(data['members'] ?? const []);

    for (final phone in members) {
      if (phone.isNotEmpty && phone != widget.userPhone) {
        return phone;
      }
    }

    final peer = data['peer'] as String?;

    if (peer != null && peer.isNotEmpty && peer != widget.userPhone) {
      return peer;
    }

    final lastSender = data['lastSender'] as String?;

    if (lastSender != null &&
        lastSender.isNotEmpty &&
        lastSender != widget.userPhone) {
      return lastSender;
    }

    return '';
  }

  Future<void> _upsertConversationThread(
      String peerPhone, String lastMessage, String lastMessageType) async {
    final chatId = _getChatId(widget.userPhone, peerPhone);

    final threadRef =
        FirebaseFirestore.instance.collection('private_threads').doc(chatId);

    await threadRef.set({
      'chatId': chatId,
      'members': [widget.userPhone, peerPhone],
      'peer': peerPhone,
      'lastMessage': lastMessage,
      'lastMessageType': lastMessageType,
      'lastSender': widget.userPhone,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await threadRef.update({
      'unreadCountByUser.$peerPhone': FieldValue.increment(1),
    });
  }

  String _previewMessage(String text, String type) {
    switch (type) {
      case 'image':
        return t('photo');

      case 'video':
        return t('video');

      case 'audio':
        return t('voiceMessage');

      case 'file':
        return t('file');

      default:
        return text;
    }
  }

  void _openConversation(String phone, {Map<String, dynamic>? data}) {
    setState(() {
      _selectedContact = phone;

      _selectedContactData = data ?? {'contact': phone, 'name': phone};

      _replyToMessage = null;

      _editingMessageId = null;

      _pinnedMessage = null;
    });

    widget.privateChatNotifier?.value = true;
  }

  void _onTypingChanged() {
    if (_selectedContact == null || _ghostMode) return;

    final chatId = _getChatId(widget.userPhone, _selectedContact!);

    final typing = _msgC.text.isNotEmpty;

    if (typing != _isTyping) {
      _isTyping = typing;

      PresenceService.setTyping(widget.userPhone, chatId, typing);
    }
  }

  @override
  void initState() {
    super.initState();

    _msgC.addListener(_onTypingChanged);

    _voiceMeterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _loadPrivateFontSize();

    if (widget.initialContact != null && widget.initialContact!.isNotEmpty) {
      _selectedContact = widget.initialContact;

      _selectedContactData = widget.initialContactData ??
          {
            'contact': widget.initialContact,
            'name': widget.initialContact,
          };
    }
  }

  @override
  void dispose() {
    if (_selectedContact != null) {
      final chatId = _getChatId(widget.userPhone, _selectedContact!);

      PresenceService.setTyping(widget.userPhone, chatId, false);
    }

    // reset private chat notifier if provided

    widget.privateChatNotifier?.value = false;

    _msgC.dispose();

    _recorder.dispose();

    _audioPlayer.dispose();

    _voiceMeterController.dispose();

    _agoraEngine?.leaveChannel();

    _agoraEngine?.release();

    super.dispose();
  }

  // ── AGORA APPELS ─────────────────────────────────────────────────────────

  Future<void> _initAgora({required bool isVideo}) async {
    if (kIsWeb) {
      _showSnack(t('callsUnavailableWeb'), Colors.orange);

      return;
    }

    await [Permission.microphone, Permission.camera].request();

    final agoraAppId = dotenv.env['AGORA_APP_ID'] ?? '';

    final agoraToken = dotenv.env['AGORA_TEMP_TOKEN'] ?? '';

    if (agoraAppId.isEmpty || agoraToken.isEmpty) {
      _showSnack(t('agoraNotConfigured'), Colors.orange);

      return;
    }

    _agoraEngine = createAgoraRtcEngine();

    await _agoraEngine!.initialize(RtcEngineContext(appId: agoraAppId));

    _agoraEngine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (c, e) => setState(() => _inCall = true),
      onUserJoined: (c, uid, e) => setState(() => _remoteUid = uid),
      onUserOffline: (c, uid, r) {
        setState(() => _remoteUid = null);

        _endCall();
      },
      onLeaveChannel: (c, s) => setState(() {
        _inCall = false;

        _remoteUid = null;
      }),
    ));

    if (isVideo) {
      await _agoraEngine!.enableVideo();

      await _agoraEngine!.startPreview();
    } else {
      await _agoraEngine!.disableVideo();
    }

    final chatId = _getChatId(widget.userPhone, _selectedContact!);

    await _agoraEngine!.joinChannel(
      token: agoraToken,
      channelId: chatId,
      uid: 0,
      options: ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    await FirebaseFirestore.instance.collection('calls').doc(chatId).set({
      'caller': widget.userPhone,
      'receiver': _selectedContact,
      'type': isVideo ? 'video' : 'voice',
      'status': 'calling',
      'channelId': chatId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    setState(() {
      _inCall = true;

      _isVideoCall = isVideo;
    });
  }

  Future<void> _endCall() async {
    final chatId = _getChatId(widget.userPhone, _selectedContact!);

    await _agoraEngine?.leaveChannel();

    await _agoraEngine?.release();

    _agoraEngine = null;

    await FirebaseFirestore.instance
        .collection('calls')
        .doc(chatId)
        .update({'status': 'ended'});

    setState(() {
      _inCall = false;

      _isVideoCall = false;

      _remoteUid = null;

      _micMuted = false;

      _camOff = false;
    });
  }

  void _toggleMic() async {
    _micMuted = !_micMuted;

    await _agoraEngine?.muteLocalAudioStream(_micMuted);

    setState(() {});
  }

  void _toggleCam() async {
    _camOff = !_camOff;

    await _agoraEngine?.muteLocalVideoStream(_camOff);

    setState(() {});
  }

  // ── ENREGISTREMENT AUDIO ─────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (_isRecording) {
      return;
    }

    try {
      // Demande explicite de permission micro avant de vérifier
      final status = await Permission.microphone.request();

      if (!status.isGranted) {
        if (mounted) {
          _showSnack(
            status.isPermanentlyDenied
                ? t('microphoneDeniedPermanently')
                : t('permissionMicroDenied'),
            Colors.orange,
          );
        }

        return;
      }

      final hasPermission = await _recorder.hasPermission();

      if (!hasPermission) {
        if (mounted) {
          _showSnack(
            t('microphoneUnauthorized'),
            Colors.orange,
          );
        }

        return;
      }

      _voiceRecordingBuffer = BytesBuilder(copy: false);

      final config = RecordConfig(
        encoder: kIsWeb ? AudioEncoder.wav : AudioEncoder.aacLc,
        sampleRate: _voiceSampleRate,
        numChannels: _voiceChannels,
      );

      await _recorder.start(config, path: _tempAudioPath ?? '');

      if (mounted) {
        setState(() => _isRecording = true);

        _voiceMeterController.repeat(reverse: true);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ _startRecording error: \$e');

      debugPrint(stackTrace.toString());

      if (mounted) {
        _showSnack(t('recordingStartError', {'error': e.toString()}), kPink);
      }
    }
  }

  Future<void> _stopAndSendRecording() async {
    if (!_isRecording) {
      return;
    }

    final buffer = _voiceRecordingBuffer;

    final streamSubscription = _voiceRecordingSubscription;

    _voiceRecordingBuffer = null;

    _voiceRecordingSubscription = null;

    await _recorder.stop();

    await streamSubscription?.cancel();

    if (mounted) {
      setState(() => _isRecording = false);

      _voiceMeterController.stop();

      _voiceMeterController.value = 0;
    }

    final pcmBytes = buffer?.takeBytes();

    if (pcmBytes == null || pcmBytes.isEmpty) {
      return;
    }

    final wavBytes = kIsWeb
        ? pcmBytes
        : _buildWavBytes(
            pcmBytes,
            sampleRate: _voiceSampleRate,
            channels: _voiceChannels,
          );

    await _uploadVoiceMessage(
      bytes: wavBytes,
      fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.wav',
    );
  }

  Uint8List _buildWavBytes(
    Uint8List pcmBytes, {
    required int sampleRate,
    required int channels,
  }) {
    const bitsPerSample = 16;

    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;

    final blockAlign = channels * bitsPerSample ~/ 8;

    final dataSize = pcmBytes.length;

    final totalSize = 44 + dataSize;

    final bytes = Uint8List(totalSize);

    final data = ByteData.sublistView(bytes);

    void writeAscii(int offset, String text) {
      for (var i = 0; i < text.length; i++) {
        data.setUint8(offset + i, text.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');

    data.setUint32(4, 36 + dataSize, Endian.little);

    writeAscii(8, 'WAVE');

    writeAscii(12, 'fmt ');

    data.setUint32(16, 16, Endian.little);

    data.setUint16(20, 1, Endian.little);

    data.setUint16(22, channels, Endian.little);

    data.setUint32(24, sampleRate, Endian.little);

    data.setUint32(28, byteRate, Endian.little);

    data.setUint16(32, blockAlign, Endian.little);

    data.setUint16(34, bitsPerSample, Endian.little);

    writeAscii(36, 'data');

    data.setUint32(40, dataSize, Endian.little);

    bytes.setRange(44, totalSize, pcmBytes);

    return bytes;
  }

  Future<void> _uploadVoiceMessage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    setState(() {
      _isSendingFile = true;

      _voiceUploadProgress = 0.0;

      _voiceUploadStatus = t('voiceUploadInProgress');
    });

    StreamSubscription<TaskSnapshot>? progressSubscription;

    try {
      final chatId = _getChatId(widget.userPhone, _selectedContact!);

      final ref = FirebaseStorage.instance
          .ref()
          .child('private_files/$chatId/$fileName');

      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: 'audio/wav'),
      );

      progressSubscription = uploadTask.snapshotEvents.listen((event) {
        final totalBytes = event.totalBytes;

        if (totalBytes <= 0 || !mounted) {
          return;
        }

        final progress = event.bytesTransferred / totalBytes;

        setState(() {
          _voiceUploadProgress = progress.clamp(0.0, 1.0);

          _voiceUploadStatus = event.state == TaskState.success
              ? t('voiceUploadFinalizing')
              : t('voiceUploadInProgress');
        });
      });

      await uploadTask;

      await progressSubscription.cancel();

      final url = await ref.getDownloadURL();

      await _sendMediaMessage(
        url: url,
        type: 'audio',
        name: fileName,
        size: bytes.length,
      );
    } catch (e) {
      _showSnack(t('voiceUploadError'), kPink);
    } finally {
      await progressSubscription?.cancel();

      if (mounted) {
        setState(() {
          _isSendingFile = false;

          _voiceUploadProgress = 0.0;

          _voiceUploadStatus = '';
        });
      } else {
        _isSendingFile = false;

        _voiceUploadProgress = 0.0;

        _voiceUploadStatus = '';
      }
    }
  }

  // ── UPLOAD FICHIERS ──────────────────────────────────────────────────────

  Future<void> _pickAndSendImage() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (file == null) return;

    await _uploadAndSendFile(
        path: file.path, type: 'image', name: file.name, xFile: file);
  }

  Future<void> _pickAndSendVideo() async {
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);

    if (file == null) return;

    await _uploadAndSendFile(
        path: file.path, type: 'video', name: file.name, xFile: file);
  }

  Future<void> _pickAndSendImageFromCamera() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 80);

    if (file == null) return;

    await _uploadAndSendFile(
        path: file.path, type: 'image', name: file.name, xFile: file);
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform
        .pickFiles(allowMultiple: false, withData: kIsWeb);

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;

    setState(() => _isSendingFile = true);

    try {
      final chatId = _getChatId(widget.userPhone, _selectedContact!);

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';

      final ref = FirebaseStorage.instance
          .ref()
          .child('private_files/$chatId/$fileName');

      if (kIsWeb && file.bytes != null) {
        final mime = lookupMimeType(file.name) ?? 'application/octet-stream';

        await ref.putData(file.bytes!, SettableMetadata(contentType: mime));
      } else if (!kIsWeb && file.path != null) {
        await ref.putFile(File(file.path!));
      }

      final url = await ref.getDownloadURL();

      final mime = lookupMimeType(file.name) ?? 'application/octet-stream';

      String type = 'file';

      if (mime.startsWith('image/')) type = 'image';

      if (mime.startsWith('video/')) type = 'video';

      if (mime.startsWith('audio/')) type = 'audio';

      await _sendMediaMessage(
          url: url, type: type, name: file.name, size: file.size);
    } catch (e) {
      _showSnack(t('fileUploadError'), kPink);
    } finally {
      if (mounted) setState(() => _isSendingFile = false);
    }
  }

  Future<void> _uploadAndSendFile({
    required String path,
    required String type,
    required String name,
    XFile? xFile,
  }) async {
    setState(() => _isSendingFile = true);

    try {
      final chatId = _getChatId(widget.userPhone, _selectedContact!);

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$name';

      final ref = FirebaseStorage.instance
          .ref()
          .child('private_files/$chatId/$fileName');

      if (kIsWeb && xFile != null) {
        final bytes = await xFile.readAsBytes();

        final mime = lookupMimeType(name) ?? 'application/octet-stream';

        await ref.putData(bytes, SettableMetadata(contentType: mime));
      } else {
        await ref.putFile(File(path));
      }

      final url = await ref.getDownloadURL();

      await _sendMediaMessage(url: url, type: type, name: name);
    } catch (e) {
      _showSnack(t('sendError'), kPink);
    } finally {
      if (mounted) setState(() => _isSendingFile = false);
    }
  }

  Future<void> _sendMediaMessage({
    required String url,
    required String type,
    required String name,
    int? size,
  }) async {
    final chatId = _getChatId(widget.userPhone, _selectedContact!);

    await FirebaseFirestore.instance
        .collection('private_messages')
        .doc(chatId)
        .collection('msgs')
        .add({
      'url': url,
      'type': type,
      'fileName': name,
      'fileSize': size,
      'sender': widget.userPhone,
      'time': FieldValue.serverTimestamp(),
      'seenAt': null,
      if (_replyToMessage != null)
        'replyTo': {
          'text': _replyToMessage!['text'] ?? '',
          'sender': _replyToMessage!['sender'],
        },
    });

    await _upsertConversationThread(
        _selectedContact!, _previewMessage(name, type), type);

    setState(() => _replyToMessage = null);
  }

  // ── ACTIONS MESSAGES ─────────────────────────────────────────────────────

  void _showMessageActions(
      BuildContext context, Map<String, dynamic> data, String docId) {
    final isMe = data['sender'] == widget.userPhone;

    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                  color: kTextDim.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['❤️', '😂', '😮', '😢', '🔥', '👏'].map((emoji) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);

                    _addReaction(docId, emoji);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: kCard, borderRadius: BorderRadius.circular(12)),
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(color: kCard),
          _ActionTile(
              icon: Icons.reply,
              label: t('reply'),
              color: kCyan,
              onTap: () {
                Navigator.pop(context);

                setState(() => _replyToMessage = {...data, 'id': docId});
              }),
          _ActionTile(
              icon: Icons.forward,
              label: t('forward'),
              color: kViolet,
              onTap: () {
                Navigator.pop(context);

                _showForwardDialog(data['text'] ?? '');
              }),
          _ActionTile(
              icon: Icons.push_pin_outlined,
              label: t('pin'),
              color: kGold,
              onTap: () {
                Navigator.pop(context);

                setState(() => _pinnedMessage = {...data, 'id': docId});
              }),
          _ActionTile(
              icon: Icons.copy,
              label: t('copy'),
              color: kTextDim,
              onTap: () {
                Navigator.pop(context);

                Clipboard.setData(ClipboardData(text: data['text'] ?? ''));

                _showSnack(t('copied'), kCyan);
              }),
          if (isMe) ...[
            _ActionTile(
                icon: Icons.edit_outlined,
                label: t('edit'),
                color: kPink,
                onTap: () {
                  Navigator.pop(context);

                  setState(() {
                    _editingMessageId = docId;

                    _msgC.text = data['text'] ?? '';
                  });
                }),
            _ActionTile(
                icon: Icons.timer_outlined,
                label: t('ephemeralMessage'),
                color: kGold,
                onTap: () {
                  Navigator.pop(context);

                  _setEphemeral(docId);
                }),
            _ActionTile(
                icon: Icons.delete_outline,
                label: t('delete'),
                color: kPink,
                onTap: () {
                  Navigator.pop(context);

                  _deleteMessage(docId);
                }),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _addReaction(String docId, String emoji) {
    final chatId = _getChatId(widget.userPhone, _selectedContact!);

    FirebaseFirestore.instance
        .collection('private_messages')
        .doc(chatId)
        .collection('msgs')
        .doc(docId)
        .update({'reactions.${widget.userPhone}': emoji});
  }

  void _deleteMessage(String docId) {
    final chatId = _getChatId(widget.userPhone, _selectedContact!);

    FirebaseFirestore.instance
        .collection('private_messages')
        .doc(chatId)
        .collection('msgs')
        .doc(docId)
        .update({'text': t('messageDeleted'), 'deleted': true});
  }

  void _setEphemeral(String docId) {
    final chatId = _getChatId(widget.userPhone, _selectedContact!);

    final expiresAt =
        DateTime.now().add(const Duration(seconds: 30)).millisecondsSinceEpoch;

    FirebaseFirestore.instance
        .collection('private_messages')
        .doc(chatId)
        .collection('msgs')
        .doc(docId)
        .update({'ephemeralAt': expiresAt});
  }

  void _showForwardDialog(String text) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        title: Text(t('forwardTo'), style: const TextStyle(color: kText)),
        content: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('contacts')
              .where('owner', isEqualTo: widget.userPhone)
              .snapshots(),
          builder: (ctx, snap) {
            if (!snap.hasData)
              return const CircularProgressIndicator(color: kViolet);

            final docs = snap.data!.docs;

            return SizedBox(
              width: double.maxFinite,
              child: ListView(
                  shrinkWrap: true,
                  children: docs.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;

                    final contact = d['contact'] as String;

                    final name = d['name'] as String? ?? contact;

                    return ListTile(
                      leading: _buildContactAvatar(d, size: 36),
                      title: Text(name, style: const TextStyle(color: kText)),
                      subtitle: Text(contact,
                          style:
                              const TextStyle(color: kTextDim, fontSize: 11)),
                      onTap: () {
                        Navigator.pop(context);

                        _forwardMessage(contact, text);
                      },
                    );
                  }).toList()),
            );
          },
        ),
      ),
    );
  }

  Future<void> _forwardMessage(String toContact, String text) async {
    final chatId = _getChatId(widget.userPhone, toContact);

    FirebaseFirestore.instance
        .collection('private_messages')
        .doc(chatId)
        .collection('msgs')
        .add({
      'text': text,
      'sender': widget.userPhone,
      'time': FieldValue.serverTimestamp(),
      'forwarded': true,
    });

    await _upsertConversationThread(toContact, text, 'text');

    _showSnack(t('transferred'), kViolet);
  }

  // ── ENVOI MESSAGE TEXTE ──────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _msgC.text.trim();

    if (text.isEmpty || _selectedContact == null) return;

    final chatId = _getChatId(widget.userPhone, _selectedContact!);

    if (_editingMessageId != null) {
      FirebaseFirestore.instance
          .collection('private_messages')
          .doc(chatId)
          .collection('msgs')
          .doc(_editingMessageId)
          .update({'text': text, 'edited': true});

      setState(() => _editingMessageId = null);
    } else {
      final Map<String, dynamic> payload = {
        'text': text,
        'type': 'text',
        'sender': widget.userPhone,
        'time': FieldValue.serverTimestamp(),
        'seenAt': null,
      };

      if (_replyToMessage != null) {
        payload['replyTo'] = {
          'text': _replyToMessage!['text'],
          'sender': _replyToMessage!['sender']
        };
      }

      FirebaseFirestore.instance
          .collection('private_messages')
          .doc(chatId)
          .collection('msgs')
          .add(payload);

      await _upsertConversationThread(_selectedContact!, text, 'text');

      setState(() => _replyToMessage = null);
    }

    PresenceService.setTyping(widget.userPhone, chatId, false);

    _isTyping = false;

    _msgC.clear();
  }

  // ── CONTACTS ─────────────────────────────────────────────────────────────

  Future<void> _pickContactFromPhone() async {
    if (_isAddingContact) return;

    if (kIsWeb) {
      await _showAddContactDialog();

      return;
    }

    setState(() => _isAddingContact = true);

    try {
      final hasPermission = await FlutterContacts.requestPermission();

      if (!hasPermission) {
        await _showAddContactDialog();

        return;
      }

      final contact = await FlutterContacts.openExternalPick();

      if (contact == null || contact.phones.isEmpty) return;

      String phone =
          contact.phones.first.number.replaceAll(RegExp(r'[^0-9+]'), '');

      final name = contact.displayName.isNotEmpty ? contact.displayName : phone;

      await _saveContact(phone, name: name);
    } catch (e) {
      await _showAddContactDialog();
    } finally {
      if (mounted) setState(() => _isAddingContact = false);
    }
  }

  // ── SUPPRIMER CONTACT ────────────────────────────────────────────────────

  Future<void> _deleteContact(
      String docId, String contactPhone, String contactName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t('deleteContactTitle'),
            style: const TextStyle(color: kPink, fontSize: 16)),
        content: Text(
          t('deleteContactConfirmation', {
            'name': contactName,
            'phone': contactPhone,
          }),
          style: const TextStyle(color: kTextDim, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('deleteContactCancel'),
                style: const TextStyle(color: kTextDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('deleteContactConfirm'),
                style:
                    const TextStyle(color: kPink, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance.collection('contacts').doc(docId).delete();

    _showSnack(t('deleteContactSuccess', {'name': contactName}), kPink);
  }

  // ── DIALOG AJOUTER CONTACT ───────────────────────────────────────────────

  Future<void> _showAddContactDialog({
    String? initialPhone,
    String? initialName,
  }) async {
    final phoneCtrl = TextEditingController(text: initialPhone ?? '');

    final nameCtrl = TextEditingController(text: initialName ?? '');

    final emailCtrl = TextEditingController();

    String? pickedPhotoPath;

    Uint8List? pickedPhotoBytes;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: kSurface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(t('newContact'),
              style: const TextStyle(
                  color: kCyan, fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Avatar (facultatif)

              GestureDetector(
                onTap: () async {
                  final file = await ImagePicker()
                      .pickImage(source: ImageSource.gallery, imageQuality: 75);

                  if (file == null) return;

                  if (kIsWeb) {
                    final bytes = await file.readAsBytes();

                    setDialogState(() => pickedPhotoBytes = bytes);
                  } else {
                    setDialogState(() => pickedPhotoPath = file.path);
                  }
                },
                child: Container(
                  width: 80,
                  height: 80,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kViolet.withOpacity(0.1),
                    border:
                        Border.all(color: kViolet.withOpacity(0.5), width: 2),
                  ),
                  child: ClipOval(
                    child: (pickedPhotoBytes != null)
                        ? Image.memory(pickedPhotoBytes!, fit: BoxFit.cover)
                        : (pickedPhotoPath != null && !kIsWeb)
                            ? Image.file(File(pickedPhotoPath!),
                                fit: BoxFit.cover)
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    const Icon(Icons.add_a_photo,
                                        color: kViolet, size: 24),
                                    const SizedBox(height: 2),
                                    Text(t('photo'),
                                        style: TextStyle(
                                            color: kViolet.withOpacity(0.7),
                                            fontSize: 9)),
                                  ]),
                  ),
                ),
              ),

              // Numéro (obligatoire)

              _buildDialogField(
                  controller: phoneCtrl,
                  hint: t('phoneNumberHint'),
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone),

              const SizedBox(height: 12),

              // Nom (obligatoire)

              _buildDialogField(
                  controller: nameCtrl,
                  hint: t('nameHint'),
                  icon: Icons.person_outline),

              const SizedBox(height: 12),

              // Email (facultatif)

              _buildDialogField(
                  controller: emailCtrl,
                  hint: t('emailOptional'),
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress),

              const SizedBox(height: 8),

              Text(t('requiredFields'),
                  style: TextStyle(
                      color: kTextDim.withOpacity(0.6), fontSize: 10)),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('cancel'), style: const TextStyle(color: kTextDim)),
            ),
            TextButton(
              onPressed: () async {
                final phone = phoneCtrl.text.replaceAll(RegExp(r'[^0-9+]'), '');

                final name = nameCtrl.text.trim();

                if (phone.isEmpty || name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(t('phoneNameRequired')),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ));

                  return;
                }

                Navigator.pop(ctx);

                await _saveContact(phone,
                    name: name,
                    email: emailCtrl.text.trim().isEmpty
                        ? null
                        : emailCtrl.text.trim(),
                    photoPath: pickedPhotoPath,
                    photoBytes: pickedPhotoBytes);
              },
              child: Text(t('addContact'),
                  style: const TextStyle(
                      color: kViolet, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: kText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kTextDim),
        prefixIcon: Icon(icon, color: kViolet, size: 20),
        filled: true,
        fillColor: kCard,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kViolet.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kViolet),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Future<void> _saveContact(
    String phone, {
    required String name,
    String? email,
    String? photoPath,
    Uint8List? photoBytes,
  }) async {
    if (phone.isEmpty) {
      _showSnack(t('invalidNumber'), Colors.orange);

      return;
    }

    if (phone == widget.userPhone) {
      _showSnack(t('cannotAddYourself'), Colors.orange);

      return;
    }

    final existing = await FirebaseFirestore.instance
        .collection('contacts')
        .where('owner', isEqualTo: widget.userPhone)
        .where('contact', isEqualTo: phone)
        .get();

    if (existing.docs.isNotEmpty) {
      _showSnack(t('alreadyInContacts', {'phone': phone}), Colors.orange);

      return;
    }

    String? photoUrl;

    if (photoBytes != null || photoPath != null) {
      try {
        final fileName =
            'contact_photos/${widget.userPhone}/${phone}_${DateTime.now().millisecondsSinceEpoch}.jpg';

        final ref = FirebaseStorage.instance.ref().child(fileName);

        if (kIsWeb && photoBytes != null) {
          await ref.putData(
              photoBytes, SettableMetadata(contentType: 'image/jpeg'));
        } else if (photoPath != null) {
          await ref.putFile(File(photoPath));
        }

        photoUrl = await ref.getDownloadURL();
      } catch (_) {}
    }

    await FirebaseFirestore.instance.collection('contacts').add({
      'owner': widget.userPhone,
      'contact': phone,
      'name': name,
      if (email != null) 'email': email,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _showSnack(t('addedSuccessfully', {'name': name}), Colors.green);
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // Load user's saved private font size from Firestore

  Future<void> _loadPrivateFontSize() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userPhone)
          .get();

      final val = doc.data()?['privateFontSize'];

      if (val is int) setState(() => _privateFontSize = val.clamp(1, 10));
    } catch (_) {}
  }

  Future<void> _savePrivateFontSize(int v) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userPhone)
          .set({'privateFontSize': v}, SetOptions(merge: true));
    } catch (_) {}
  }

  void _openPrivateSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: kSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            gradient: const LinearGradient(
                colors: [Color(0xFF0B0B1A), Color(0xFF111125)]),
            border: Border.all(color: kViolet.withOpacity(0.3))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: kViolet, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.settings, color: kCyan),
            const SizedBox(width: 8),
            Text(t('privateSettings'),
                style:
                    const TextStyle(color: kCyan, fontWeight: FontWeight.bold)),
            const Spacer(),
          ]),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.group_add, color: kViolet),
            title: Text(t('createGroup'), style: const TextStyle(color: kText)),
            subtitle: Text(t('createGroupSubtitle'),
                style: const TextStyle(color: kTextDim)),
            onTap: () {
              Navigator.pop(context);
              _showCreateGroupDialog();
            },
          ),
          const Divider(color: kCard),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(children: [
              const Icon(Icons.format_size, color: kCyan),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(t('fontSizeLabel', {'size': '$_privateFontSize'}),
                      style: const TextStyle(color: kText))),
            ]),
          ),
          Slider(
            value: _privateFontSize.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            activeColor: kViolet,
            inactiveColor: kTextDim,
            label: '$_privateFontSize',
            onChanged: (v) {
              final vi = v.round();

              setState(() => _privateFontSize = vi);
            },
            onChangeEnd: (v) async {
              final vi = v.round();

              await _savePrivateFontSize(vi);
            },
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Future<void> _showCreateGroupDialog() async {
    final nameCtrl = TextEditingController();

    final selected = <String>{};

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(t('createGroup'),
            style: const TextStyle(color: kCyan, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('contacts')
                .where('owner', isEqualTo: widget.userPhone)
                .snapshots(),
            builder: (c, snap) {
              if (!snap.hasData)
                return const CircularProgressIndicator(color: kViolet);

              final docs = snap.data!.docs;

              return Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: kText),
                    decoration: InputDecoration(
                        hintText: t('groupNameHint'),
                        hintStyle: const TextStyle(color: kTextDim))),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    children: docs.map((d) {
                      final data = d.data() as Map<String, dynamic>;

                      final contact = data['contact'] as String;

                      final name = data['name'] as String? ?? contact;

                      final checked = selected.contains(contact) ||
                          contact == widget.userPhone;

                      return CheckboxListTile(
                        value: checked,
                        onChanged: (_) {
                          setState(() {
                            if (selected.contains(contact))
                              selected.remove(contact);
                            else
                              selected.add(contact);
                          });
                        },
                        title: Text(name, style: const TextStyle(color: kText)),
                        subtitle: Text(contact,
                            style:
                                const TextStyle(color: kTextDim, fontSize: 11)),
                        secondary: _buildContactAvatar(data, size: 36),
                      );
                    }).toList(),
                  ),
                ),
              ]);
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text(t('cancel'), style: const TextStyle(color: kTextDim))),
          TextButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();

                if (name.isEmpty) {
                  _showSnack(t('nameRequired'), Colors.orange);
                  return;
                }

                final members = selected.isEmpty
                    ? [widget.userPhone]
                    : ([widget.userPhone] + selected.toList());

                await FirebaseFirestore.instance.collection('groups').add({
                  'name': name,
                  'owner': widget.userPhone,
                  'members': members,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                Navigator.pop(ctx);

                _showSnack(t('groupCreated'), Colors.green);
              },
              child: Text(t('createGroup'),
                  style: const TextStyle(
                      color: kViolet, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _markAsSeen(List<QueryDocumentSnapshot> docs, String chatId) {
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      if (data['sender'] != widget.userPhone && data['seenAt'] == null) {
        doc.reference.update({'seenAt': DateTime.now().millisecondsSinceEpoch});
      }
    }

    if (docs.isNotEmpty) {
      unawaited(
        FirebaseFirestore.instance
            .collection('private_threads')
            .doc(chatId)
            .update({
          'unreadCountByUser.${widget.userPhone}': 0,
        }),
      );

      unawaited(
        FirebaseFirestore.instance
            .collection('private_threads')
            .doc(chatId)
            .set({
          'readAtByUser': {
            widget.userPhone: DateTime.now().millisecondsSinceEpoch,
          },
        }, SetOptions(merge: true)),
      );

      unawaited(
        FirebaseFirestore.instance
            .collection('private_threads')
            .doc(chatId)
            .collection('reads')
            .doc(widget.userPhone)
            .set({
          'lastReadAt': DateTime.now().millisecondsSinceEpoch,
        }, SetOptions(merge: true)),
      );
    }
  }

  // ── HELPERS AVATAR ────────────────────────────────────────────────────────

  Widget _buildContactAvatar(Map<String, dynamic> data, {double size = 48}) {
    final photoUrl = data['photoUrl'] as String?;

    final name = data['name'] as String? ?? data['contact'] as String? ?? '?';

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(photoUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildInitialsAvatar(name, size)),
      );
    }

    return _buildInitialsAvatar(name, size);
  }

  Widget _buildInitialsAvatar(String name, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kViolet, width: 1.5),
        color: kViolet.withOpacity(0.1),
      ),
      child: Center(
        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
                color: kViolet,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.38)),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  Future<bool> _onWillPop() async {
    if (_selectedContact != null) {
      final chatId = _getChatId(widget.userPhone, _selectedContact!);

      PresenceService.setTyping(widget.userPhone, chatId, false);

      setState(() {
        _selectedContact = null;

        _selectedContactData = null;

        _replyToMessage = null;

        _editingMessageId = null;

        _pinnedMessage = null;
      });

      widget.privateChatNotifier?.value = false;

      return false;
    }

    if (widget.onReturnToFeed != null) {
      widget.onReturnToFeed!();

      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final textScale = (_privateFontSize.clamp(1, 10)) / 5.0;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaleFactor: textScale),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: null,
          body: Container(
            decoration: const BoxDecoration(gradient: kGradientBg),
            child: _inCall
                ? _buildCallScreen()
                : NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) {
                      if (_selectedContact == null) {
                        return [
                          SliverAppBar(
                            pinned: true,
                            floating: false,
                            snap: false,
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            flexibleSpace: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  Color(0xFF050510),
                                  Color(0xFF0D0D2B)
                                ]),
                              ),
                            ),
                            centerTitle: true,
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock,
                                    color: kViolet, size: 18),
                                const SizedBox(width: 8),
                                Text(t('privateMessagingTitle'),
                                    style: const TextStyle(
                                        color: kCyan, fontSize: 14)),
                              ],
                            ),
                            actions: [
                              IconButton(
                                tooltip: t('privateSettingsTooltip'),
                                icon: Icon(Icons.settings, color: kCyan),
                                onPressed: _openPrivateSettings,
                              )
                            ],
                            leading: IconButton(
                              icon: const Icon(Icons.arrow_back, color: kCyan),
                              onPressed: () {
                                if (widget.onReturnToFeed != null) {
                                  widget.onReturnToFeed!();
                                } else {
                                  Navigator.of(context).maybePop();
                                }
                              },
                            ),
                          ),
                        ];
                      }

                      // When a contact is selected we render the chat AppBar as a SliverAppBar

                      return [
                        SliverAppBar(
                          pinned: true,
                          floating: false,
                          snap: false,
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          flexibleSpace: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Color(0xFF050510),
                                Color(0xFF0D0D2B)
                              ]),
                            ),
                          ),
                          title: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                PresenceIndicator(
                                    userPhone: _selectedContact!, size: 10),
                                const SizedBox(width: 10),
                                Text(
                                  _selectedContactData?['name'] ??
                                      _selectedContact!,
                                  style: const TextStyle(
                                      color: kViolet, fontSize: 14),
                                ),
                              ]),
                          leading: IconButton(
                            icon: const Icon(Icons.arrow_back, color: kCyan),
                            onPressed: () {
                              final chatId = _getChatId(
                                  widget.userPhone, _selectedContact!);

                              PresenceService.setTyping(
                                  widget.userPhone, chatId, false);

                              setState(() {
                                _selectedContact = null;

                                _selectedContactData = null;

                                _replyToMessage = null;

                                _editingMessageId = null;

                                _pinnedMessage = null;
                              });

                              widget.privateChatNotifier?.value = false;
                            },
                          ),
                          actions: [
                            IconButton(
                              tooltip: t('saveNumberTooltip'),
                              icon: const Icon(Icons.person_add_alt_1,
                                  color: kGold, size: 20),
                              onPressed: () => _showAddContactDialog(
                                initialPhone: _selectedContact!,
                                initialName:
                                    _selectedContactData?['name'] as String? ??
                                        _selectedContact!,
                              ),
                            ),
                            if (!kIsWeb)
                              IconButton(
                                icon: const Icon(Icons.call,
                                    color: kCyan, size: 20),
                                onPressed: () => _initAgora(isVideo: false),
                              ),
                            if (!kIsWeb)
                              IconButton(
                                icon: const Icon(Icons.videocam,
                                    color: kViolet, size: 20),
                                onPressed: () => _initAgora(isVideo: true),
                              ),
                            IconButton(
                              tooltip: _ghostMode
                                  ? t('ghostModeOn')
                                  : t('ghostModeOff'),
                              icon: Icon(
                                  _ghostMode
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: _ghostMode ? kPink : kTextDim,
                                  size: 20),
                              onPressed: () {
                                setState(() => _ghostMode = !_ghostMode);

                                HapticFeedback.lightImpact();

                                _showSnack(
                                    _ghostMode
                                        ? t('ghostModeOn')
                                        : t('ghostModeOff'),
                                    kViolet);
                              },
                            ),
                          ],
                        ),
                      ];
                    },
                    body: _selectedContact == null
                        ? _buildContactList()
                        : _buildChat(),
                  ),
          ),
          floatingActionButton: _selectedContact == null
              ? GlassAddButton(
                  padding: const EdgeInsets.only(bottom: 12),
                  size: 52,
                  iconSize: 20,
                  busy: _isAddingContact,
                  colors: [kViolet, kPink],
                  onTap: _pickContactFromPhone,
                )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        ),
      ),
    );
  }

  // ── ÉCRAN D'APPEL ─────────────────────────────────────────────────────────

  Widget _buildCallScreen() {
    final contactName = _selectedContactData?['name'] ?? _selectedContact!;

    return Container(
      color: Colors.black,
      child: Stack(children: [
        if (_isVideoCall && _remoteUid != null)
          AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _agoraEngine!,
              canvas: VideoCanvas(uid: _remoteUid),
              connection: RtcConnection(
                  channelId: _getChatId(widget.userPhone, _selectedContact!)),
            ),
          )
        else
          Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              _buildContactAvatar(_selectedContactData ?? {}, size: 100),
              const SizedBox(height: 20),
              Text(contactName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_remoteUid != null ? t('inCall') : t('callOngoing'),
                  style: const TextStyle(color: kTextDim, fontSize: 14)),
            ]),
          ),
        if (_isVideoCall && !_camOff)
          Positioned(
            top: 60,
            right: 16,
            child: SizedBox(
              width: 100,
              height: 150,
              child: AgoraVideoView(
                controller: VideoViewController(
                    rtcEngine: _agoraEngine!,
                    canvas: const VideoCanvas(uid: 0)),
              ),
            ),
          ),
        Positioned(
          bottom: 60,
          left: 0,
          right: 0,
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _callButton(
                icon: _micMuted ? Icons.mic_off : Icons.mic,
                color: _micMuted ? kPink : kCyan,
                onTap: _toggleMic),
            _callButton(
                icon: Icons.call_end, color: kPink, size: 60, onTap: _endCall),
            if (_isVideoCall)
              _callButton(
                  icon: _camOff ? Icons.videocam_off : Icons.videocam,
                  color: _camOff ? kPink : kViolet,
                  onTap: _toggleCam)
            else
              _callButton(icon: Icons.volume_up, color: kViolet, onTap: () {}),
          ]),
        ),
      ]),
    );
  }

  Widget _callButton(
      {required IconData icon,
      required Color color,
      required VoidCallback onTap,
      double size = 50}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.2),
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(icon, color: color, size: size * 0.45),
      ),
    );
  }

  // ── LISTE CONTACTS ────────────────────────────────────────────────────────

  Widget _buildContactList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('private_threads')
          .where('members', arrayContains: widget.userPhone)
          .snapshots(),
      builder: (context, threadSnapshot) {
        if (threadSnapshot.hasError) {
          return Center(
              child: Text(t('error'), style: const TextStyle(color: kPink)));
        }

        if (!threadSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: kViolet));
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('contacts')
              .where('owner', isEqualTo: widget.userPhone)
              .snapshots(),
          builder: (context, contactSnapshot) {
            if (contactSnapshot.hasError) {
              return Center(
                  child:
                      Text(t('error'), style: const TextStyle(color: kPink)));
            }

            if (!contactSnapshot.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: kViolet));
            }

            final contactDocs = contactSnapshot.data!.docs;

            final threadDocs = threadSnapshot.data!.docs;

            final contactMap = <String, Map<String, dynamic>>{};

            for (final doc in contactDocs) {
              final data = doc.data() as Map<String, dynamic>;

              final phone = data['contact'] as String?;

              if (phone != null && phone.isNotEmpty) {
                contactMap[phone] = data;
              }
            }

            final threadCards = threadDocs
                .map((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  final peer = _resolveThreadPeer(data);

                  final contactData = contactMap[peer];

                  final displayName =
                      contactData?['name'] as String? ?? t('unknown');
                  final updatedAt = data['updatedAt'];

                  DateTime? updatedTime;

                  if (updatedAt is Timestamp) {
                    updatedTime = updatedAt.toDate();
                  }

                  return {
                    'peer': peer,
                    'displayName': displayName,
                    'lastMessage': data['lastMessage'] as String? ?? '',
                    'updatedAt': updatedTime,
                    'contactData': contactData,
                  };
                })
                .where((item) => (item['peer'] as String).isNotEmpty)
                .toList();

            threadCards.sort((a, b) {
              final aTime = (a['updatedAt'] as DateTime?) ??
                  DateTime.fromMillisecondsSinceEpoch(0);

              final bTime = (b['updatedAt'] as DateTime?) ??
                  DateTime.fromMillisecondsSinceEpoch(0);

              return bTime.compareTo(aTime);
            });

            final savedContacts = contactDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;

              final phone = data['contact'] as String?;

              return phone != null &&
                  phone.isNotEmpty &&
                  !threadCards.any((item) => item['peer'] == phone);
            }).toList();

            final query = _contactsSearch.trim().toLowerCase();

            final filteredThreads = threadCards.where((item) {
              if (query.isEmpty) return true;

              final peer = (item['peer'] as String).toLowerCase();

              final displayName = (item['displayName'] as String).toLowerCase();

              final lastMessage = (item['lastMessage'] as String).toLowerCase();

              return peer.contains(query) ||
                  displayName.contains(query) ||
                  lastMessage.contains(query);
            }).toList();

            final filteredContacts = savedContacts.where((doc) {
              if (query.isEmpty) return true;

              final data = doc.data() as Map<String, dynamic>;

              final contact = (data['contact'] as String? ?? '').toLowerCase();

              final name = (data['name'] as String? ?? contact).toLowerCase();

              final email = (data['email'] as String? ?? '').toLowerCase();

              return contact.contains(query) ||
                  name.contains(query) ||
                  email.contains(query);
            }).toList();

            if (filteredThreads.isEmpty && filteredContacts.isEmpty) {
              return Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          query.isEmpty
                              ? Icons.chat_bubble_outline
                              : Icons.search_off,
                          size: 60,
                          color: kTextDim),
                      const SizedBox(height: 16),
                      Text(query.isEmpty ? t('noConversation') : t('noResults'),
                          style: const TextStyle(color: kTextDim)),
                      const SizedBox(height: 8),
                      Text(
                          query.isEmpty
                              ? t('addContactPrompt')
                              : t('tryAnotherNameOrNumber'),
                          style:
                              const TextStyle(color: kTextDim, fontSize: 12)),
                    ]),
              );
            }

            final children = <Widget>[];

            children.add(Padding(
              padding: const EdgeInsets.fromLTRB(15, 8, 15, 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    colors: [
                      kSurface.withOpacity(0.96),
                      kCard.withOpacity(0.96),
                    ],
                  ),
                  border: Border.all(color: kViolet.withOpacity(0.18)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [kViolet, kCyan],
                            ),
                          ),
                          child: const Icon(Icons.people_alt_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('privateMessagingTitle'),
                                style: const TextStyle(
                                  color: kText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                t('privateMessagingSubtitle'),
                                style: TextStyle(
                                  color: kTextDim.withOpacity(0.95),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (threadCards.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: kViolet.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                              border:
                                  Border.all(color: kViolet.withOpacity(0.25)),
                            ),
                            child: Text(
                              '${threadCards.length}',
                              style: const TextStyle(
                                color: kViolet,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      onChanged: (value) =>
                          setState(() => _contactsSearch = value),
                      style: const TextStyle(color: kText),
                      decoration: InputDecoration(
                        hintText: t('searchContactHint'),
                        hintStyle: TextStyle(color: kTextDim.withOpacity(0.8)),
                        prefixIcon: const Icon(Icons.search, color: kCyan),
                        suffixIcon: _contactsSearch.isEmpty
                            ? null
                            : IconButton(
                                tooltip: t('clear'),
                                icon: const Icon(Icons.close, color: kTextDim),
                                onPressed: () =>
                                    setState(() => _contactsSearch = ''),
                              ),
                        filled: true,
                        fillColor: kBg.withOpacity(0.45),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ));

            if (filteredThreads.isNotEmpty) {
              children.add(Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                child: Text(t('recentConversations'),
                    style: const TextStyle(
                        color: kCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
              ));

              for (final item in filteredThreads) {
                final peer = item['peer'] as String;

                final displayName = item['displayName'] as String;

                final lastMessage = item['lastMessage'] as String;

                final contactData =
                    item['contactData'] as Map<String, dynamic>?;

                children.add(Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => _openConversation(peer, data: contactData),
                    child: GlassCard(
                      borderColor: contactData == null ? kCyan : kViolet,
                      child: Row(children: [
                        Stack(children: [
                          _buildContactAvatar(
                              contactData ??
                                  {'contact': peer, 'name': displayName},
                              size: 48),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: PresenceIndicator(userPhone: peer, size: 10),
                          ),
                        ]),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      displayName,
                                      style: const TextStyle(
                                          color: kText,
                                          fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (contactData == null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: kCyan.withOpacity(0.12),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                            color: kCyan.withOpacity(0.3)),
                                      ),
                                      child: Text(t('unknown'),
                                          style: const TextStyle(
                                              color: kCyan, fontSize: 10)),
                                    ),
                                ],
                              ),
                              Text(peer,
                                  style: const TextStyle(
                                      color: kTextDim, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(
                                lastMessage.isEmpty
                                    ? t('emptyConversation')
                                    : lastMessage,
                                style: const TextStyle(
                                    color: kTextDim, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: kTextDim),
                      ]),
                    ),
                  ),
                ));
              }
            }

            if (filteredContacts.isNotEmpty) {
              children.add(Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Text(t('contacts'),
                    style: const TextStyle(
                        color: kCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
              ));

              for (final doc in filteredContacts) {
                final data = doc.data() as Map<String, dynamic>;

                final contact = data['contact'] as String;

                final name = data['name'] as String? ?? contact;

                final email = data['email'] as String?;

                children.add(Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Dismissible(
                    key: ValueKey(doc.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: kPink.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kPink.withOpacity(0.4)),
                      ),
                      child: const Icon(Icons.delete_outline,
                          color: kPink, size: 26),
                    ),
                    confirmDismiss: (_) async {
                      await _deleteContact(doc.id, contact, name);

                      return false;
                    },
                    child: GestureDetector(
                      onTap: () => _openConversation(contact, data: data),
                      child: GlassCard(
                        borderColor: kViolet,
                        child: Row(children: [
                          Stack(children: [
                            _buildContactAvatar(data, size: 48),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: PresenceIndicator(
                                  userPhone: contact, size: 10),
                            ),
                          ]),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: const TextStyle(
                                          color: kText,
                                          fontWeight: FontWeight.w500)),
                                  Text(contact,
                                      style: const TextStyle(
                                          color: kTextDim, fontSize: 11)),
                                  if (email != null)
                                    Text(email,
                                        style: const TextStyle(
                                            color: kTextDim, fontSize: 10)),
                                  StreamBuilder<Map<String, dynamic>>(
                                    stream:
                                        PresenceService.watchPresence(contact),
                                    builder: (c, snap) {
                                      final data =
                                          snap.data ?? <String, dynamic>{};

                                      final online = data['online'] == true;

                                      final lastSeenValue = data['lastSeen'];

                                      String status = t('offline');

                                      Color statusColor = kTextDim;

                                      if (online) {
                                        status = t('online');

                                        statusColor = kCyan;
                                      } else if (lastSeenValue != null) {
                                        final time = lastSeenValue is int
                                            ? DateTime
                                                .fromMillisecondsSinceEpoch(
                                                    lastSeenValue)
                                            : lastSeenValue is String
                                                ? DateTime.tryParse(
                                                    lastSeenValue)
                                                : null;

                                        if (time != null) {
                                          final diff =
                                              DateTime.now().difference(time);

                                          if (diff.inMinutes < 60) {
                                            status = t('minutesAgo', {
                                              'minutes':
                                                  diff.inMinutes.toString(),
                                            });

                                            statusColor = kViolet;
                                          } else if (diff.inHours < 24) {
                                            status = t('hoursAgo', {
                                              'hours': diff.inHours.toString(),
                                            });
                                          }
                                        }
                                      }

                                      return Text(status,
                                          style: TextStyle(
                                              color: statusColor,
                                              fontSize: 11));
                                    },
                                  ),
                                ]),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: kPink, size: 20),
                            onPressed: () =>
                                _deleteContact(doc.id, contact, name),
                            tooltip: t('delete'),
                          ),
                          const Icon(Icons.chevron_right, color: kTextDim),
                        ]),
                      ),
                    ),
                  ),
                ));
              }
            }

            return ListView(
              key: const PageStorageKey('privateContacts'),
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 160),
              children: children,
            );
          },
        );
      },
    );
  }

  // ── CHAT ──────────────────────────────────────────────────────────────────

  Widget _buildChat() {
    final chatId = _getChatId(widget.userPhone, _selectedContact!);

    return Column(children: [
      if (_pinnedMessage != null)
        _PinnedMessageBanner(
          text: _pinnedMessage!['text'] ?? '',
          onDismiss: () => setState(() => _pinnedMessage = null),
        ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('private_messages')
              .doc(chatId)
              .collection('msgs')
              .orderBy('time', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return Center(
                  child:
                      Text(t('error'), style: const TextStyle(color: kPink)));

            if (!snapshot.hasData)
              return const Center(
                  child: CircularProgressIndicator(color: kViolet));

            final docs = snapshot.data!.docs;

            if (docs.isEmpty)
              return Center(
                  child: Text(t('startConversation'),
                      style: const TextStyle(color: kTextDim)));

            _markAsSeen(docs, chatId);

            return ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(15),
              itemCount: docs.length,
              itemBuilder: (c, i) {
                final doc = docs[i];

                final data = doc.data() as Map<String, dynamic>;

                final docId = doc.id;

                final ephemeralAt = data['ephemeralAt'] as int?;

                if (ephemeralAt != null &&
                    DateTime.now().millisecondsSinceEpoch > ephemeralAt) {
                  return const SizedBox.shrink();
                }

                final bool isMe = data['sender'] == widget.userPhone;

                return GestureDetector(
                  onLongPress: () => _showMessageActions(context, data, docId),
                  child: _MessageBubble(
                      data: data,
                      isMe: isMe,
                      ephemeralAt: ephemeralAt,
                      audioPlayer: _audioPlayer),
                );
              },
            );
          },
        ),
      ),
      TypingIndicator(chatId: chatId, myPhone: widget.userPhone),
      _buildInputBar(),
    ]);
  }

  // ── BARRE D'ENVOI ─────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Column(children: [
      if (_replyToMessage != null)
        _ReplyBanner(
          text: _replyToMessage!['text'] ?? '',
          sender: _replyToMessage!['sender'] ?? '',
          isMe: _replyToMessage!['sender'] == widget.userPhone,
          onCancel: () => setState(() => _replyToMessage = null),
        ),
      if (_editingMessageId != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: kPink.withOpacity(0.1),
          child: Row(children: [
            const Icon(Icons.edit, color: kPink, size: 14),
            const SizedBox(width: 8),
            Text(t('editingInProgress'),
                style: const TextStyle(color: kPink, fontSize: 12)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() {
                _editingMessageId = null;

                _msgC.clear();
              }),
              child: const Icon(Icons.close, color: kPink, size: 16),
            ),
          ]),
        ),
      if (_isSendingFile)
        LinearProgressIndicator(color: kViolet, backgroundColor: kCard),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kSurface,
          border: Border(
              top: BorderSide(color: kViolet.withOpacity(0.2), width: 1)),
        ),
        child: Row(children: [
          GestureDetector(
            onTap: _showAttachmentMenu,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kCard,
                border: Border.all(color: kViolet.withOpacity(0.3)),
              ),
              child: const Icon(Icons.attach_file, color: kViolet, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          if (_ghostMode)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.visibility_off, color: kPink, size: 16),
            ),
          Expanded(
            child: TextField(
              controller: _msgC,
              style: const TextStyle(color: kText),
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: _editingMessageId != null
                    ? t('editMessageHint')
                    : t('privateMessageHint'),
                hintStyle: const TextStyle(color: kTextDim),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              if (_msgC.text.isNotEmpty) {
                _sendMessage();

                return;
              }

              if (_isRecording) {
                _stopAndSendRecording();
              } else {
                _startRecording();
              }
            },
            onLongPress: _msgC.text.isEmpty ? _startRecording : null,
            onLongPressEnd:
                _msgC.text.isEmpty ? (_) => _stopAndSendRecording() : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isRecording
                      ? [kPink, kViolet]
                      : _editingMessageId != null
                          ? [kPink, kViolet]
                          : [kViolet, kPink],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording ? kPink : kViolet).withOpacity(0.3),
                    blurRadius: 15,
                  )
                ],
              ),
              child: Icon(
                _isRecording
                    ? Icons.stop
                    : _msgC.text.isEmpty
                        ? Icons.mic
                        : _editingMessageId != null
                            ? Icons.check
                            : Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                  color: kTextDim.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2))),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _attachItem(
                icon: Icons.image,
                label: t('photo'),
                color: kCyan,
                onTap: () {
                  Navigator.pop(context);

                  _pickAndSendImage();
                }),
            _attachItem(
                icon: Icons.videocam,
                label: t('video'),
                color: kPink,
                onTap: () {
                  Navigator.pop(context);

                  _pickAndSendVideo();
                }),
            _attachItem(
                icon: Icons.insert_drive_file,
                label: t('file'),
                color: kGold,
                onTap: () {
                  Navigator.pop(context);

                  _pickAndSendFile();
                }),
            _attachItem(
                icon: Icons.camera_alt,
                label: t('camera'),
                color: kViolet,
                onTap: () {
                  Navigator.pop(context);

                  _pickAndSendImageFromCamera();
                }),
          ]),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _attachItem(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.12),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );

    Widget _buildVoiceRecordingIndicator() {
      return AnimatedBuilder(
        animation: _voiceMeterController,
        builder: (context, child) {
          final value = _voiceMeterController.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kPink.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: kPink,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  t('voiceRecordingInProgress'),
                  style: const TextStyle(color: kText, fontSize: 12),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: List.generate(6, (index) {
                      final phase = (value + index * 0.13) % 1.0;

                      final pulse =
                          1 - ((phase - 0.5).abs() * 2).clamp(0.0, 1.0);

                      final height = 6.0 + (pulse * 16.0);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Container(
                          width: 4,
                          height: height,
                          decoration: BoxDecoration(
                            color: kPink.withOpacity(0.55 + (pulse * 0.35)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    Widget _buildVoiceSendingIndicator() {
      final hasProgress = _voiceUploadProgress > 0 && _voiceUploadProgress < 1;

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kViolet.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_upload_outlined,
                    color: kViolet, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _voiceUploadStatus.isEmpty
                        ? t('voiceUploadInProgress')
                        : _voiceUploadStatus,
                    style: const TextStyle(color: kText, fontSize: 12),
                  ),
                ),
                if (hasProgress)
                  Text(
                    '${(_voiceUploadProgress * 100).toStringAsFixed(0)} %',
                    style: const TextStyle(color: kTextDim, fontSize: 11),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: hasProgress ? _voiceUploadProgress : null,
                minHeight: 4,
                color: kViolet,
                backgroundColor: kViolet.withOpacity(0.12),
              ),
            ),
          ],
        ),
      );
    }
  }
}

// ── BULLE DE MESSAGE ──────────────────────────────────────────────────────────

class _MessageBubble extends StatefulWidget {
  final Map<String, dynamic> data;

  final bool isMe;

  final int? ephemeralAt;

  final AudioPlayer audioPlayer;

  const _MessageBubble(
      {required this.data,
      required this.isMe,
      this.ephemeralAt,
      required this.audioPlayer});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  Timer? _timer;

  int _secondsLeft = 0;

  String t(String key, [Map<String, String>? params]) =>
      AppLocalizations.of(context)?.translate(key, params) ?? key;

  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();

    if (widget.ephemeralAt != null) {
      _updateTimer();

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) _updateTimer();
      });
    }
  }

  void _updateTimer() {
    final remaining =
        widget.ephemeralAt! - DateTime.now().millisecondsSinceEpoch;

    setState(() => _secondsLeft = (remaining / 1000).ceil().clamp(0, 9999));
  }

  @override
  void dispose() {
    _timer?.cancel();

    super.dispose();
  }

  String _fmt(dynamic ts) {
    if (ts == null) return '';

    try {
      final t = DateTime.fromMillisecondsSinceEpoch(
          (ts as dynamic).millisecondsSinceEpoch);

      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  String _fmtMs(int ms) {
    final t = DateTime.fromMillisecondsSinceEpoch(ms);

    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return '';

    if (bytes < 1024) return '$bytes B';

    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';

    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  Widget _buildMediaContent(Map<String, dynamic> data) {
    final type = data['type'] ?? 'text';

    final url = data['url'] as String?;

    final fileName = data['fileName'] as String? ?? 'Fichier';

    final fileSize = data['fileSize'] as int?;

    switch (type) {
      case 'image':
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(url ?? '',
              width: 200,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image_outlined, color: kTextDim)),
        );

      case 'video':
        return Container(
          width: 200,
          height: 120,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12), color: Colors.black),
          child: Stack(alignment: Alignment.center, children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: const Icon(Icons.movie, color: kTextDim, size: 40)),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: kViolet.withOpacity(0.8)),
              child:
                  const Icon(Icons.play_arrow, color: Colors.white, size: 28),
            ),
          ]),
        );

      case 'audio':
        return GestureDetector(
          onTap: () async {
            if (_isPlayingAudio) {
              await widget.audioPlayer.stop();

              setState(() => _isPlayingAudio = false);
            } else {
              await widget.audioPlayer.play(UrlSource(url ?? ''));

              setState(() => _isPlayingAudio = true);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: kViolet.withOpacity(0.15),
              border: Border.all(color: kViolet.withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_isPlayingAudio ? Icons.stop : Icons.play_arrow,
                  color: kViolet, size: 24),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('voiceMessage'),
                    style: const TextStyle(color: kText, fontSize: 12)),
                Text(_isPlayingAudio ? t('playing') : t('tapToListen'),
                    style: const TextStyle(color: kTextDim, fontSize: 10)),
              ]),
            ]),
          ),
        );

      case 'file':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: kGold.withOpacity(0.1),
            border: Border.all(color: kGold.withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.insert_drive_file, color: kGold, size: 28),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fileName,
                  style: const TextStyle(
                      color: kText, fontSize: 12, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (fileSize != null)
                Text(_formatSize(fileSize),
                    style: const TextStyle(color: kTextDim, fontSize: 10)),
            ]),
          ]),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    final isMe = widget.isMe;

    final deleted = data['deleted'] == true;

    final edited = data['edited'] == true;

    final forwarded = data['forwarded'] == true;

    final replyTo = data['replyTo'] as Map<String, dynamic>?;

    final reactions = data['reactions'] as Map<String, dynamic>?;

    final seenAt = data['seenAt'] as int?;

    final type = data['type'] ?? 'text';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              gradient: isMe
                  ? LinearGradient(colors: [
                      kViolet.withOpacity(0.2),
                      kPink.withOpacity(0.2)
                    ])
                  : null,
              color: isMe ? null : kCard,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
              border: Border.all(
                color: isMe ? kViolet.withOpacity(0.3) : kPink.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (forwarded)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.forward,
                            size: 11, color: kTextDim.withOpacity(0.7)),
                        const SizedBox(width: 4),
                        Text(t('forwarded'),
                            style: TextStyle(
                                color: kTextDim.withOpacity(0.7),
                                fontSize: 10,
                                fontStyle: FontStyle.italic)),
                      ]),
                    ),
                  if (replyTo != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kViolet.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border(left: BorderSide(color: kViolet, width: 3)),
                      ),
                      child: Text(replyTo['text'] ?? '',
                          style: const TextStyle(color: kTextDim, fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                  if (deleted)
                    Text(t('messageDeleted'),
                        style: TextStyle(
                            color: kTextDim, fontStyle: FontStyle.italic))
                  else if (type == 'text')
                    Text(data['text'] ?? '',
                        style: const TextStyle(color: kText))
                  else
                    _buildMediaContent(data),
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    if (widget.ephemeralAt != null) ...[
                      Icon(Icons.timer, size: 10, color: kGold),
                      const SizedBox(width: 2),
                      Text('${_secondsLeft}s',
                          style: TextStyle(color: kGold, fontSize: 9)),
                      const SizedBox(width: 6),
                    ],
                    Text(_fmt(data['time']),
                        style: const TextStyle(color: kTextDim, fontSize: 9)),
                    if (edited)
                      Text(t('edited'),
                          style: const TextStyle(color: kTextDim, fontSize: 9)),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      if (seenAt != null)
                        Tooltip(
                            message: t('seenAt', {'time': _fmtMs(seenAt)}),
                            child: const Icon(Icons.done_all,
                                size: 12, color: kCyan))
                      else
                        const Icon(Icons.done, size: 12, color: kTextDim),
                    ],
                  ]),
                ],
              ),
            ),
          ),
          if (reactions != null && reactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kViolet.withOpacity(0.2), width: 1),
                ),
                child: Text(reactions.values.toSet().join(' '),
                    style: const TextStyle(fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }
}

// ── WIDGETS UTILITAIRES ───────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;

  final String label;

  final Color color;

  final VoidCallback onTap;

  const _ActionTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(label, style: TextStyle(color: color, fontSize: 14)),
      onTap: onTap,
    );
  }
}

class _ReplyBanner extends StatelessWidget {
  final String text, sender;

  final bool isMe;

  final VoidCallback onCancel;

  const _ReplyBanner(
      {required this.text,
      required this.sender,
      required this.isMe,
      required this.onCancel});

  String _t(BuildContext context, String key, [Map<String, String>? params]) =>
      AppLocalizations.of(context)?.translate(key, params) ?? key;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: kViolet.withOpacity(0.1),
      child: Row(children: [
        Container(width: 3, height: 36, color: kViolet),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isMe ? _t(context, 'you') : sender,
              style: const TextStyle(
                  color: kViolet, fontSize: 11, fontWeight: FontWeight.bold)),
          Text(text,
              style: const TextStyle(color: kTextDim, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ])),
        GestureDetector(
            onTap: onCancel,
            child: const Icon(Icons.close, color: kTextDim, size: 16)),
      ]),
    );
  }
}

class _PinnedMessageBanner extends StatelessWidget {
  final String text;

  final VoidCallback onDismiss;

  const _PinnedMessageBanner({required this.text, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: kGold.withOpacity(0.1),
      child: Row(children: [
        const Icon(Icons.push_pin, color: kGold, size: 14),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(color: kGold, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis)),
        GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close, color: kGold, size: 14)),
      ]),
    );
  }
}
