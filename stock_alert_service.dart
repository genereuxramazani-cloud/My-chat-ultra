// lib/services/stock_alert_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class StockAlertService {
  static final StockAlertService _instance = StockAlertService._internal();
  factory StockAlertService() => _instance;
  StockAlertService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

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

    _initialized = true;
  }

  Future<void> checkAndNotify(String userPhone) async {
    final snap = await FirebaseFirestore.instance
        .collection('business')
        .where('owner', isEqualTo: userPhone)
        .where('type', isEqualTo: 'inventaire')
        .get();

    final lowItems = snap.docs.where((doc) {
      final data = doc.data();
      final qty = (data['qty'] ?? 0) as num;
      final qtyMin = (data['qtyMin'] ?? 5) as num;
      return qty <= qtyMin;
    }).toList();

    if (lowItems.isEmpty) return;

    if (lowItems.length > 1) {
      await _sendGroupSummary(lowItems.length);
    }

    for (var i = 0; i < lowItems.length; i++) {
      final data = lowItems[i].data();
      await _sendItemNotification(
        id: i + 1,
        name: data['description'] ?? 'Article inconnu',
        qty: (data['qty'] ?? 0) as num,
        qtyMin: (data['qtyMin'] ?? 5) as num,
        prixAchat: (data['prixAchat'] ?? 0).toDouble(),
      );
    }
  }

  Future<void> _sendItemNotification({
    required int id,
    required String name,
    required num qty,
    required num qtyMin,
    required double prixAchat,
  }) async {
    final android = AndroidNotificationDetails(
      'stock_alerts',
      'Alertes Stock',
      channelDescription: 'Notifications pour les articles en rupture de stock',
      importance: Importance.high,
      priority: Priority.high,
      groupKey: 'stock_low',
      styleInformation: BigTextStyleInformation(
        'Quantité actuelle : $qty (seuil : $qtyMin)\n'
        'Prix achat unitaire : \$${prixAchat.toStringAsFixed(2)}\n'
        'Pensez à réapprovisionner !',
        contentTitle: 'Stock bas — $name',
        summaryText: 'Business Hub',
      ),
    );

    const ios = DarwinNotificationDetails(
      threadIdentifier: 'stock_alerts',
      subtitle: 'Stock insuffisant',
    );

    await _plugin.show(
      id,
      'Stock bas — $name',
      'Qté : $qty / Min : $qtyMin  •  \$${prixAchat.toStringAsFixed(2)}/unité',
      NotificationDetails(android: android, iOS: ios),
    );
  }

  Future<void> _sendGroupSummary(int count) async {
    final android = AndroidNotificationDetails(
      'stock_alerts',
      'Alertes Stock',
      channelDescription: 'Notifications pour les articles en rupture de stock',
      importance: Importance.high,
      priority: Priority.high,
      groupKey: 'stock_low',
      setAsGroupSummary: true,
      styleInformation: InboxStyleInformation(
        [],
        contentTitle: '$count articles en stock insuffisant',
        summaryText: 'Business Hub',
      ),
    );

    await _plugin.show(
      0,
      'Business Hub — Alertes Stock',
      '$count articles nécessitent un réapprovisionnement',
      NotificationDetails(android: android),
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
