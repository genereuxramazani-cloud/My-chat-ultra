import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../main.dart' show globalProfileService;
import '../widgets/user_avatar_widget.dart';
import 'private_screen.dart';

class ExploreUsersScreen extends StatefulWidget {
  final String userPhone;
  final VoidCallback? onReturnToFeed;

  const ExploreUsersScreen({
    super.key,
    required this.userPhone,
    this.onReturnToFeed,
  });

  @override
  State<ExploreUsersScreen> createState() => _ExploreUsersScreenState();
}

class _ExploreUsersScreenState extends State<ExploreUsersScreen> {
  String _searchQuery = '';
  Set<String> _followedPhones = <String>{};

  @override
  void initState() {
    super.initState();
    _loadFollowState();
  }

  Future<void> _loadFollowState() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('follows')
          .where('followerPhone', isEqualTo: widget.userPhone)
          .get();

      final followed = snapshot.docs
          .map((doc) => doc.data()['targetPhone'] as String?)
          .whereType<String>()
          .where((phone) => phone.isNotEmpty)
          .toSet();

      if (!mounted) return;
      setState(() => _followedPhones = followed);
    } catch (_) {}
  }

  Future<void> _toggleFollow(String targetPhone) async {
    final docId = '${widget.userPhone}_$targetPhone';
    final isFollowing = _followedPhones.contains(targetPhone);

    try {
      if (isFollowing) {
        await FirebaseFirestore.instance
            .collection('follows')
            .doc(docId)
            .delete();
        if (!mounted) return;
        setState(() => _followedPhones.remove(targetPhone));
        _showSnack('Suivi supprimé', Colors.orange);
      } else {
        await FirebaseFirestore.instance.collection('follows').doc(docId).set({
          'followerPhone': widget.userPhone,
          'targetPhone': targetPhone,
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return;
        setState(() => _followedPhones.add(targetPhone));
        _showSnack('Utilisateur suivi', kCyan);
      }
    } catch (e) {
      _showSnack('Erreur: ${e.toString()}', Colors.red);
    }
  }

  void _openConversation(String targetPhone, String targetName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrivateScreen(
          userPhone: widget.userPhone,
          onReturnToFeed: widget.onReturnToFeed,
          initialContact: targetPhone,
          initialContactData: {'contact': targetPhone, 'name': targetName},
        ),
      ),
    );
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: ListenableBuilder(
          listenable: globalProfileService,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: UserAvatarWidget(
              avatarUrl: globalProfileService.avatar,
              identifier: widget.userPhone,
              size: 32,
              borderColor: kCyan,
              borderWidth: 1.5,
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.travel_explore, color: kCyan),
            SizedBox(width: 8),
            Text(
              'Explorer',
              style: TextStyle(
                color: kCyan,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: kGradientBg),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                            color: kCyan.withOpacity(0.35), width: 1),
                      ),
                      child: TextField(
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        style: const TextStyle(color: kWhite, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Rechercher un nom...',
                          hintStyle:
                              TextStyle(color: kTextDim.withOpacity(0.8)),
                          prefixIcon:
                              const Icon(Icons.search_rounded, color: kCyan),
                          suffixIcon: _searchQuery.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () =>
                                      setState(() => _searchQuery = ''),
                                  icon: const Icon(Icons.close_rounded,
                                      color: kTextDim),
                                ),
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Impossible de charger les profils',
                          style: TextStyle(color: kTextDim),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: kCyan),
                      );
                    }

                    final docs = snapshot.data!.docs.where((doc) {
                      final data = doc.data();
                      final phone = (doc.id).trim();
                      if (phone.isEmpty || phone == widget.userPhone)
                        return false;
                      final name = (data['displayName'] as String?) ??
                          (data['name'] as String?) ??
                          phone;
                      if (_searchQuery.isEmpty) return true;
                      return name
                              .toLowerCase()
                              .contains(_searchQuery.toLowerCase()) ||
                          phone
                              .toLowerCase()
                              .contains(_searchQuery.toLowerCase());
                    }).toList();

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off_outlined,
                                color: kGold.withOpacity(0.8), size: 44),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'Aucun utilisateur à explorer pour l’instant'
                                  : 'Aucun résultat pour cette recherche',
                              style: const TextStyle(color: kTextDim),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        final phone = (doc.id).trim().isNotEmpty
                            ? doc.id
                            : (data['phone'] as String? ?? '');
                        final name = (data['displayName'] as String?) ??
                            (data['name'] as String?) ??
                            phone;
                        final photoUrl = (data['photoUrl'] as String?) ??
                            (data['profilePhotoUrl'] as String?);
                        final isFollowing = _followedPhones.contains(phone);

                        return ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                    color: kCyan.withOpacity(0.28), width: 1),
                              ),
                              child: Row(
                                children: [
                                  ClipOval(
                                    child: photoUrl != null &&
                                            photoUrl.isNotEmpty
                                        ? Image.network(
                                            photoUrl,
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                _buildInitialsAvatar(name, 48),
                                          )
                                        : _buildInitialsAvatar(name, 48),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            color: kWhite,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          phone,
                                          style: TextStyle(
                                              color: kTextDim, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () => _toggleFollow(phone),
                                        child: Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: isFollowing
                                                ? Colors.green.withOpacity(0.18)
                                                : kCyan.withOpacity(0.16),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                              color: isFollowing
                                                  ? Colors.green
                                                  : kCyan.withOpacity(0.45),
                                              width: 1.2,
                                            ),
                                          ),
                                          child: Icon(
                                            isFollowing
                                                ? Icons.check_rounded
                                                : Icons.add_rounded,
                                            color: isFollowing
                                                ? Colors.green
                                                : kCyan,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () =>
                                            _openConversation(phone, name),
                                        child: Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: kViolet.withOpacity(0.18),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                                color:
                                                    kViolet.withOpacity(0.45),
                                                width: 1.2),
                                          ),
                                          child: const Icon(
                                              Icons.message_rounded,
                                              color: kViolet,
                                              size: 20),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar(String name, double size) {
    final initials = name
        .split(' ')
        .take(2)
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() : '')
        .join();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [kViolet.withOpacity(0.55), kGold.withOpacity(0.35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
