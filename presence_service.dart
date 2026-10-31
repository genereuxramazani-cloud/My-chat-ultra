import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'theme.dart';

class PresenceService {
  static final _db = FirebaseDatabase.instance;

  // ── METTRE À JOUR LE STATUT ───────────────────────
  static Future<void> setOnline(String userPhone) async {
    final ref = _db.ref('presence/$userPhone');
    try {
      await ref.set({
        'online': true,
        'lastSeen': ServerValue.timestamp,
      });
      // Quand l'app se ferme → automatiquement hors ligne
      try {
        await ref.onDisconnect().set({
          'online': false,
          'lastSeen': ServerValue.timestamp,
        });
      } catch (e) {
        debugPrint('Presence onDisconnect set failed (non-critical): $e');
      }
    } catch (e) {
      debugPrint('Presence write failed (non-critical): $e');
    }
  }

  static Future<void> setOffline(String userPhone) async {
    try {
      await _db.ref('presence/$userPhone').set({
        'online': false,
        'lastSeen': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('Presence offline write failed (non-critical): $e');
    }
  }

  // ── METTRE À JOUR "EN TRAIN D'ÉCRIRE" ────────────
  static Future<void> setTyping(
      String userPhone, String chatId, bool typing) async {
    try {
      await _db.ref('typing/$chatId/$userPhone').set(typing ? true : null);
    } catch (e) {
      debugPrint('Typing write failed (non-critical): $e');
    }
  }

  // ── MARQUER MESSAGE COMME VU ──────────────────────
  static Future<void> markSeen(
      String chatId, String messageId, String userPhone) async {
    await _db.ref('seen/$chatId/$messageId/$userPhone').set(
          ServerValue.timestamp,
        );
  }

  // ── STREAM STATUT D'UN UTILISATEUR ───────────────
  static Stream<Map<String, dynamic>> watchPresence(String userPhone) {
    return _db.ref('presence/$userPhone').onValue.map((event) {
      if (!event.snapshot.exists) {
        return {'online': false, 'lastSeen': null};
      }
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }

  // ── STREAM "EN TRAIN D'ÉCRIRE" ────────────────────
  static Stream<List<String>> watchTyping(String chatId, String myPhone) {
    return _db.ref('typing/$chatId').onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return data.entries
          .where((e) =>
              e.key != myPhone &&
              (e.value is bool
                  ? (e.value as bool)
                  : (e.value == 1 || e.value == true)))
          .map((e) => e.key)
          .toList();
    });
  }
}

// ── WIDGET STATUT ANIMÉ ───────────────────────────
class PresenceIndicator extends StatelessWidget {
  final String userPhone;
  final double size;

  const PresenceIndicator({
    super.key,
    required this.userPhone,
    this.size = 12,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: PresenceService.watchPresence(userPhone),
      builder: (context, snapshot) {
        final isOnline = snapshot.data?['online'] ?? false;
        final lastSeen = snapshot.data?['lastSeen'];
        final lastSeenTime = lastSeen != null
            ? DateTime.fromMillisecondsSinceEpoch(lastSeen as int)
            : null;
        final isRecent = lastSeenTime != null &&
            DateTime.now().difference(lastSeenTime).inHours < 1;

        Color color = isOnline
            ? kCyan
            : isRecent
                ? kViolet
                : kTextDim;

        return _PulsingDot(color: color, size: size, pulse: isOnline);
      },
    );
  }

  String _formatLastSeen(DateTime? time) {
    if (time == null) return 'Hors ligne';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return 'Il y a ${diff.inDays}j';
  }
}

// ── WIDGET POINT QUI PULSE ────────────────────────
class _PulsingDot extends StatefulWidget {
  final Color color;
  final double size;
  final bool pulse;

  const _PulsingDot({
    required this.color,
    required this.size,
    required this.pulse,
  });

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.pulse) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulsingDot old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.pulse && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (c, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Anneau externe qui pulse
            if (widget.pulse)
              Container(
                width: widget.size * _anim.value * 1.8,
                height: widget.size * _anim.value * 1.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color
                      .withOpacity(0.3 * (1 - (_anim.value - 0.8) / 0.6)),
                ),
              ),
            // Point central
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.6),
                    blurRadius: widget.size,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── WIDGET INDICATEUR D'ÉCRITURE ─────────────────
class TypingIndicator extends StatefulWidget {
  final String chatId;
  final String myPhone;

  const TypingIndicator({
    super.key,
    required this.chatId,
    required this.myPhone,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: PresenceService.watchTyping(widget.chatId, widget.myPhone),
      builder: (context, snapshot) {
        final typers = snapshot.data ?? [];
        if (typers.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(left: 15, bottom: 5),
          child: Row(
            children: [
              // 3 points animés
              AnimatedBuilder(
                animation: _ctrl,
                builder: (c, child) {
                  return Row(
                    children: List.generate(3, (i) {
                      final delay = i / 3;
                      final value = (_ctrl.value + delay) % 1.0;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 6,
                        height: 6 + value * 6,
                        decoration: BoxDecoration(
                          color: kCyan.withOpacity(0.5 + value * 0.5),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: kCyan.withOpacity(value * 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(width: 8),
              Text(
                '${typers.first} écrit...',
                style: const TextStyle(
                  color: kCyan,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
