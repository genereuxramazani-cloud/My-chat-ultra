import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';

typedef GetUserDataFn = Future<Map<String, dynamic>> Function(String phone);
typedef ToggleLikeFn = Future<void> Function(String statusId, List likers);

class StatusViewerDialog extends StatefulWidget {
  final DocumentSnapshot doc;
  final String statusAuthor;
  final String statusId;
  final List viewers;
  final List likers;
  final String currentUserPhone;
  final ToggleLikeFn onToggleLike;
  final GetUserDataFn getUserData;

  const StatusViewerDialog({
    required this.doc,
    required this.statusAuthor,
    required this.statusId,
    required this.viewers,
    required this.likers,
    required this.currentUserPhone,
    required this.onToggleLike,
    required this.getUserData,
  });

  @override
  State<StatusViewerDialog> createState() => _StatusViewerDialogState();
}

class _StatusViewerDialogState extends State<StatusViewerDialog>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _fadeController;
  Timer? _autoCloseTimer;
  late Map<String, dynamic> _authorData;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.likers.contains(widget.currentUserPhone);
    _progressController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..forward();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..forward();

    _autoCloseTimer = Timer(const Duration(seconds: 21), () {
      if (mounted) Navigator.pop(context);
    });

    _loadAuthorData();
  }

  void _loadAuthorData() async {
    final data = await widget.getUserData(widget.statusAuthor);
    if (mounted) setState(() => _authorData = data);
  }

  @override
  void dispose() {
    _progressController.dispose();
    _fadeController.dispose();
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final imageUrl = data['url'] as String? ?? '';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: FadeTransition(
        opacity: _fadeController,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Stack(
            children: [
              // Image de fond full-screen
              Container(
                color: Colors.black,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => Container(
                    color: kCard,
                    child: const Icon(Icons.image, size: 80, color: kTextDim),
                  ),
                ),
              ),
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black54,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // Haut: Barre de progression + infos utilisateur
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Column(
                    children: [
                      // Progress bar
                      AnimatedBuilder(
                        animation: _progressController,
                        builder: (_, __) => ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            minHeight: 2,
                            value: _progressController.value,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(kCyan),
                            backgroundColor: Colors.white24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // User info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            // Avatar
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: kCyan, width: 2),
                              ),
                              child: ClipOval(
                                child: _authorData != null &&
                                        _authorData['avatar'] != null
                                    ? Image.network(
                                        _authorData['avatar'],
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.person),
                                      )
                                    : Container(
                                        color: kCard,
                                        child: const Icon(Icons.person,
                                            color: kTextDim),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Nom + phone
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _authorData != null
                                        ? (_authorData['name'] ??
                                            widget.statusAuthor)
                                        : widget.statusAuthor,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Disponible pendant 20s',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Bouton fermer
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black54,
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Bas: Actions (Like, Views, Message)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black87,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Action buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            // Like Button
                            GestureDetector(
                              onTap: () async {
                                setState(() => _isLiked = !_isLiked);
                                await widget.onToggleLike(
                                    widget.statusId, widget.likers);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _isLiked
                                      ? kPink.withOpacity(0.2)
                                      : Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _isLiked
                                        ? kPink
                                        : Colors.white.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isLiked
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: _isLiked
                                          ? kPink
                                          : Colors.white70,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${widget.likers.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Views Button
                            GestureDetector(
                              onTap: () =>
                                  _showViewsLikesModal(
                                      widget.viewers, widget.likers),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.visibility,
                                        color: Colors.white70, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${widget.viewers.length}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Share Button
                            GestureDetector(
                              onTap: () {},
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(Icons.share,
                                    color: Colors.white70, size: 18),
                              ),
                            ),
                          ],
                        ),
                        // Message input (si ce n'est pas l'auteur)
                        if (widget.statusAuthor != widget.currentUserPhone) ...[
                          const SizedBox(height: 12),
                          _buildMessageInput(),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    final msgController = TextEditingController();
    return TextField(
      controller: msgController,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Message à ${_authorData?['name'] ?? widget.statusAuthor}...',
        hintStyle: const TextStyle(color: Colors.white38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: kCyan.withOpacity(0.5), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: kCyan, width: 2),
        ),
        filled: true,
        fillColor: Colors.black26,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        suffixIcon: GestureDetector(
          onTap: () async {
            if (msgController.text.trim().isEmpty) return;
            final msg = msgController.text.trim();

            await FirebaseFirestore.instance.collection('messages').add({
              'sender': widget.currentUserPhone,
              'recipient': widget.statusAuthor,
              'text': msg,
              'time': FieldValue.serverTimestamp(),
              'read': false,
              'type': 'status_reply',
              'statusId': widget.statusId,
            });

            msgController.clear();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Message envoyé !'),
                  backgroundColor: kCyan,
                  duration: const Duration(milliseconds: 1500),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(Icons.send_rounded, color: kCyan, size: 20),
          ),
        ),
      ),
    );
  }

  void _showViewsLikesModal(List viewers, List likers) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kViolet,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'QUI A VU & AIMÉ',
              style: TextStyle(
                color: kCyan,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            if (likers.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '❤️ A AIMÉ (${likers.length})',
                  style: const TextStyle(
                    color: kPink,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 150,
                child: ListView.builder(
                  itemCount: likers.length,
                  itemBuilder: (_, i) =>
                      _buildUserListItem(likers[i] as String),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: kCard),
              const SizedBox(height: 16),
            ],
            if (viewers.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '👁️ A VU (${viewers.length})',
                  style: const TextStyle(
                    color: kViolet,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 150,
                child: ListView.builder(
                  itemCount: viewers.length,
                  itemBuilder: (_, i) =>
                      _buildUserListItem(viewers[i] as String),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildUserListItem(String phone) {
    return FutureBuilder<Map<String, dynamic>>(
      future: widget.getUserData(phone),
      builder: (ctx, snap) {
        final name = snap.data?['name'] ?? phone;
        final avatar = snap.data?['avatar'] as String?;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kCyan.withOpacity(0.5), width: 1),
                ),
                child: ClipOval(
                  child: avatar != null
                      ? Image.network(avatar, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.person, size: 18, color: kTextDim))
                      : Container(
                          color: kCard,
                          child: const Icon(Icons.person, size: 18, color: kTextDim),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: kText,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      phone,
                      style: const TextStyle(
                        color: kTextDim,
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
