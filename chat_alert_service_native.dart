import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;

class ChatAlertService {
  static final ChatAlertService _instance = ChatAlertService._internal();
  factory ChatAlertService() => _instance;
  ChatAlertService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<QuerySnapshot>? _threadsSub;
  StreamSubscription<QuerySnapshot>? _callsSub;
  String? _activeUserPhone;
  bool _initialized = false;
  bool _badgeSupported = false;
  bool _ignoreFirstThreadsSnapshot = true;
  bool _ignoreFirstCallsSnapshot = true;
  final Map<String, String> _lastThreadSignatureByChatId = {};

  String _resolveThreadPeer(Map<String, dynamic> data, String userPhone) {
    final members = List<String>.from(data['members'] ?? const []);

    for (final phone in members) {
      if (phone.isNotEmpty && phone != userPhone) {
        return phone;
      }
    }

    final peer = data['peer'] as String?;
    if (peer != null && peer.isNotEmpty && peer != userPhone) {
      return peer;
    }

    final lastSender = data['lastSender'] as String?;
    if (lastSender != null && lastSender.isNotEmpty && lastSender != userPhone) {
      return lastSender;
    }

    return 'Nouveau contact';
  }

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    try {
      _badgeSupported = await AppBadgePlus.isSupported();
    } catch (_) {
      _badgeSupported = false;
    }

    _initialized = true;
  }

  Future<void> startForUser(String userPhone) async {
    await init();

    if (_activeUserPhone == userPhone &&
        _threadsSub != null &&
        _callsSub != null) {
      return;
    }

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
      unawaited(_syncAppBadge(snapshot.docs));
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

      _showNotification(
        id: chatId.hashCode & 0x7fffffff,
        title: 'Nouveau message de $peer',
        body: body.isEmpty ? 'Nouveau message' : body,
      );
    }

    unawaited(_syncAppBadge(snapshot.docs));
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
      final title = callType == 'video'
          ? 'Appel vidéo entrant'
          : 'Appel vocal entrant';

      _showNotification(
        id: change.doc.id.hashCode & 0x7fffffff,
        title: title,
        body: 'Appel de $caller',
      );
    }
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const android = AndroidNotificationDetails(
      'chat_alerts',
      'Messages et appels',
      channelDescription: 'Notifications de nouveaux messages et appels',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.message,
    );

    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: android, iOS: ios),
    );
  }

  Future<void> _syncAppBadge(Iterable<QueryDocumentSnapshot> threads) async {
    if (!_badgeSupported) return;

    final userPhone = _activeUserPhone;
    if (userPhone == null) return;

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

      final updatedAt = data['updatedAt'];
      DateTime? updatedTime;
      if (updatedAt is Timestamp) {
        updatedTime = updatedAt.toDate();
      } else if (updatedAt is int) {
        updatedTime = DateTime.fromMillisecondsSinceEpoch(updatedAt);
      } else if (updatedAt is DateTime) {
        updatedTime = updatedAt;
      }

      if (updatedTime == null) {
        unreadCount += 1;
        continue;
      }

      final readAtByUser = data['readAtByUser'];
      dynamic lastReadAt;
      if (readAtByUser is Map) {
        lastReadAt = readAtByUser[userPhone];
      }

      DateTime? readTime;
      if (lastReadAt is Timestamp) {
        readTime = lastReadAt.toDate();
      } else if (lastReadAt is int) {
        readTime = DateTime.fromMillisecondsSinceEpoch(lastReadAt);
      } else if (lastReadAt is String) {
        readTime = DateTime.tryParse(lastReadAt);
      }

      if (readTime == null || updatedTime.isAfter(readTime)) {
        unreadCount += 1;
      }
    }

    try {
      await AppBadgePlus.updateBadge(unreadCount);
    } catch (_) {}
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
