import 'dart:async';
import 'dart:js' as js;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ChatAlertService {
  static final ChatAlertService _instance = ChatAlertService._internal();
  factory ChatAlertService() => _instance;
  ChatAlertService._internal();

  static const String _baseTitle = 'MY CHAT ULTRA';
  StreamSubscription<QuerySnapshot>? _threadsSub;
  StreamSubscription<QuerySnapshot>? _callsSub;
  String? _activeUserPhone;
  bool _initialized = false;
  bool _ignoreFirstThreadsSnapshot = true;
  bool _ignoreFirstCallsSnapshot = true;
  final Map<String, String> _lastThreadSignatureByChatId = {};

  String _resolveThreadPeer(Map<String, dynamic> data, String userPhone) {
    final members = List<String>.from(data['members'] ?? const []);
    for (final phone in members) {
      if (phone.isNotEmpty && phone != userPhone) return phone;
    }
    final peer = data['peer'] as String?;
    if (peer != null && peer.isNotEmpty && peer != userPhone) return peer;
    final lastSender = data['lastSender'] as String?;
    if (lastSender != null && lastSender.isNotEmpty && lastSender != userPhone)
      return lastSender;
    return 'Nouveau contact';
  }

  Future<void> init() async {
    if (_initialized) return;
    await _ensurePermission();
    _setTabTitle(0);
    _initialized = true;
  }

  Future<void> startForUser(String userPhone) async {
    await init();
    if (_activeUserPhone == userPhone &&
        _threadsSub != null &&
        _callsSub != null) return;
    await stop();
    _activeUserPhone = userPhone;
    _ignoreFirstThreadsSnapshot = true;
    _ignoreFirstCallsSnapshot = true;
    _lastThreadSignatureByChatId.clear();

    _threadsSub = FirebaseFirestore.instance
        .collection('private_threads')
        .where('members', arrayContains: userPhone)
        .snapshots()
        .listen(_handleThreadSnapshot);

    _callsSub = FirebaseFirestore.instance
        .collection('calls')
        .where('receiver', isEqualTo: userPhone)
        .where('status', isEqualTo: 'calling')
        .snapshots()
        .listen(_handleCallSnapshot);
  }

  Future<void> stop() async {
    await _threadsSub?.cancel();
    await _callsSub?.cancel();
    _threadsSub = null;
    _callsSub = null;
    _activeUserPhone = null;
    _ignoreFirstThreadsSnapshot = true;
    _ignoreFirstCallsSnapshot = true;
    _lastThreadSignatureByChatId.clear();
  }

  void _handleThreadSnapshot(QuerySnapshot snapshot) {
    if (_ignoreFirstThreadsSnapshot) {
      _ignoreFirstThreadsSnapshot = false;
      unawaited(_syncTabBadge(snapshot.docs));
      return;
    }
    for (final change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.removed) continue;
      final data = change.doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      final userPhone = _activeUserPhone;
      if (userPhone == null) continue;
      final lastSender = data['lastSender'] as String?;
      if (lastSender == null || lastSender == userPhone) continue;
      final chatId = data['chatId'] as String? ?? change.doc.id;
      final signature =
          '${data['lastMessage'] ?? ''}|${data['lastMessageType'] ?? ''}|$lastSender';
      if (_lastThreadSignatureByChatId[chatId] == signature) continue;
      _lastThreadSignatureByChatId[chatId] = signature;
      final peer = _resolveThreadPeer(data, userPhone);
      final lastMessageType = data['lastMessageType'] as String? ?? 'text';
      final lastMessage = data['lastMessage'] as String? ?? '';
      final body = lastMessageType == 'audio' ? 'Message vocal' : lastMessage;
      _showBrowserNotification(
        title: 'Nouveau message de $peer',
        body: body.isEmpty ? 'Nouveau message' : body,
      );
    }
    unawaited(_syncTabBadge(snapshot.docs));
  }

  void _handleCallSnapshot(QuerySnapshot snapshot) {
    if (_ignoreFirstCallsSnapshot) {
      _ignoreFirstCallsSnapshot = false;
      return;
    }
    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final data = change.doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      final caller = data['caller'] as String? ?? 'Numéro inconnu';
      final callType = data['type'] as String? ?? 'voice';
      final title =
          callType == 'video' ? 'Appel vidéo entrant' : 'Appel vocal entrant';
      _showBrowserNotification(title: title, body: 'Appel de $caller');
    }
  }

  Future<void> _ensurePermission() async {
    try {
      final permission = js.context['Notification']?['permission'] as String?;
      if (permission == 'granted' || permission == 'denied') return;
      js.context.callMethod('eval', ['Notification.requestPermission()']);
    } catch (_) {}
  }

  void _showBrowserNotification({required String title, required String body}) {
    try {
      final permission = js.context['Notification']?['permission'] as String?;
      if (permission != 'granted') return;
      js.context.callMethod('eval', [
        'new Notification(${_jsString(title)}, {body: ${_jsString(body)}, icon: "/icons/Icon-192.png"})'
      ]);
    } catch (error) {
      debugPrint('Notification web error: $error');
    }
  }

  String _jsString(String s) => '"${s.replaceAll('"', '\\"')}"';

  Future<void> _syncTabBadge(Iterable<QueryDocumentSnapshot> threads) async {
    final userPhone = _activeUserPhone;
    if (userPhone == null) {
      _setTabTitle(0);
      return;
    }
    var unreadCount = 0;
    for (final thread in threads) {
      final data = thread.data() as Map<String, dynamic>?;
      if (data == null) continue;
      final unreadCountByUser = data['unreadCountByUser'];
      if (unreadCountByUser is Map) {
        final countValue = unreadCountByUser[userPhone];
        if (countValue is int) {
          unreadCount += countValue;
          continue;
        }
        if (countValue is num) {
          unreadCount += countValue.toInt();
          continue;
        }
      }
      final lastSender = data['lastSender'] as String?;
      if (lastSender == null || lastSender == userPhone) continue;
      unreadCount += 1;
    }
    _setTabTitle(unreadCount);
  }

  void _setTabTitle(int unreadCount) {
    try {
      final title = unreadCount > 0 ? '($unreadCount) $_baseTitle' : _baseTitle;
      js.context.callMethod('eval', ['document.title = ${_jsString(title)}']);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    _setTabTitle(0);
  }
}
