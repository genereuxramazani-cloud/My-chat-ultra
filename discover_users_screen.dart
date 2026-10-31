import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../main.dart' show globalProfileService;
import '../widgets/user_avatar_widget.dart';
import 'private_screen.dart';

class DiscoverUsersScreen extends StatefulWidget {
  final String userPhone;
  final VoidCallback? onReturnToFeed;

  const DiscoverUsersScreen({
    super.key,
    required this.userPhone,
    this.onReturnToFeed,
  });

  @override
  State<DiscoverUsersScreen> createState() => _DiscoverUsersScreenState();
}

class _DiscoverUsersScreenState extends State<DiscoverUsersScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  Set<String> _followingSet = {};
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _loadFollowing();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowing() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userPhone)
          .get();
      if (doc.exists) {
        final following = List<String>.from(doc['following'] ?? const []);
        setState(() => _followingSet = following.toSet());
      }
    } catch (_) {}
  }

  Future<void> _toggleFollow(String targetPhone) async {
    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(widget.userPhone);
      final isFollowing = _followingSet.contains(targetPhone);

      if (isFollowing) {
        _followingSet.remove(targetPhone);
        await userRef.update({
          'following': FieldValue.arrayRemove([targetPhone]),
        });
        await FirebaseFirestore.instance
            .collection('users')
            .doc(targetPhone)
            .update({
          'followers': FieldValue.arrayRemove([widget.userPhone]),
        });
        _showSnack('Suivi supprimé', Colors.orange);
      } else {
        _followingSet.add(targetPhone);
        await userRef.update({
          'following': FieldValue.arrayUnion([targetPhone]),
        });
        await FirebaseFirestore.instance
            .collection('users')
            .doc(targetPhone)
            .update({
          'followers': FieldValue.arrayUnion([widget.userPhone]),
        });
        _showSnack('Utilisateur suivi !', kCyan);
      }
      setState(() {});
    } catch (e) {
      _showSnack('Erreur: ${e.toString()}', Colors.red);
    }
  }

  void _startConversation(String targetPhone, String targetName) {
    Navigator.pop(context);
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

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Container(
        decoration: const BoxDecoration(gradient: kGradientBg),
        child: Column(
          children: [
            // ============ PREMIUM HEADER ============
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  children: [
                    // Bouton retour + titre
                    Row(
                      children: [
                        ListenableBuilder(
                          listenable: globalProfileService,
                          builder: (context, _) => UserAvatarWidget(
                            avatarUrl: globalProfileService.avatar,
                            identifier: widget.userPhone,
                            size: 44,
                            borderColor: kCyan,
                            borderWidth: 1.5,
                            onTap: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'DÉCOUVRIR',
                                style: TextStyle(
                                  color: kCyan,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                'Explorez les profils',
                                style: TextStyle(
                                  color: kTextDim,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withOpacity(0.2),
                            border:
                                Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.person_search,
                              color: Colors.red, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // ============ PREMIUM SEARCH BAR ============
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: kCyan.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        style: const TextStyle(
                          color: kText,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Nom ou numéro...',
                          hintStyle: TextStyle(
                            color: kTextDim.withOpacity(0.7),
                            fontSize: 13,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 16, right: 12),
                            child: Icon(Icons.search_rounded,
                                color: kCyan.withOpacity(0.8), size: 20),
                          ),
                          suffixIcon: _searchQuery.isEmpty
                              ? null
                              : Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _searchQuery = ''),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: kTextDim.withOpacity(0.1),
                                      ),
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: kTextDim.withOpacity(0.6),
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                          filled: true,
                          fillColor: kCard.withOpacity(0.8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: kCyan.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: kCyan.withOpacity(0.15),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(
                              color: kCyan,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ============ USERS LIST ============
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 56, color: Colors.red.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          const Text('Erreur de chargement',
                              style: TextStyle(color: kTextDim)),
                        ],
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 50,
                            height: 50,
                            child: CircularProgressIndicator(
                              color: kCyan.withOpacity(0.7),
                              strokeWidth: 3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('Chargement des profils...',
                              style: TextStyle(color: kTextDim)),
                        ],
                      ),
                    );
                  }

                  final users = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final phone = (doc.id as String).trim().isNotEmpty
                        ? doc.id
                        : (data['phone'] as String? ?? '');
                    if (phone.isEmpty) return false;
                    if (phone == widget.userPhone) return false;
                    if (_searchQuery.isEmpty) return true;
                    final name = (data['name'] as String?) ??
                        (data['displayName'] as String?) ??
                        phone;
                    return phone.contains(_searchQuery) ||
                        name.toLowerCase().contains(_searchQuery.toLowerCase());
                  }).toList();

                  if (users.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kViolet.withOpacity(0.1),
                            ),
                            child: Icon(
                              _searchQuery.isEmpty
                                  ? Icons.person_off_rounded
                                  : Icons.search_off_rounded,
                              size: 40,
                              color: kViolet.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _searchQuery.isEmpty
                                ? 'Aucun utilisateur disponible'
                                : 'Aucun résultat trouvé',
                            style: const TextStyle(
                              color: kTextDim,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isEmpty
                                ? 'Revenez plus tard'
                                : 'Essayez une autre recherche',
                            style: TextStyle(
                              color: kTextDim.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final animation = Tween<double>(begin: 0, end: 1).animate(
                        CurvedAnimation(
                          parent: _animController,
                          curve: Interval(
                            index * 0.05,
                            0.5 + index * 0.05,
                            curve: Curves.easeOut,
                          ),
                        ),
                      );

                      final doc = users[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final phone = (doc.id as String).trim().isNotEmpty
                          ? doc.id
                          : (data['phone'] as String? ?? '');
                      final name = (data['name'] as String?) ??
                          (data['displayName'] as String?) ??
                          phone;
                      final photoUrl = (data['profilePhotoUrl'] as String?) ??
                          (data['photoUrl'] as String?);
                      final followers =
                          (data['followers'] as List?)?.length ?? 0;
                      final isFollowing = _followingSet.contains(phone);

                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, 50 * (1 - animation.value)),
                            child: Opacity(
                              opacity: animation.value,
                              child: child,
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: kViolet.withOpacity(0.1),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: kCard.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: kViolet.withOpacity(0.15),
                                  width: 1,
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    kCard.withOpacity(0.95),
                                    kCard.withOpacity(0.8),
                                  ],
                                ),
                              ),
                              child: Row(
                                children: [
                                  // ============ AVATAR ============
                                  Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: kViolet.withOpacity(0.3),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ClipOval(
                                          child: photoUrl != null &&
                                                  photoUrl.isNotEmpty
                                              ? Image.network(
                                                  photoUrl,
                                                  width: 56,
                                                  height: 56,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      _buildInitialsAvatar(
                                                          name, 56),
                                                )
                                              : _buildInitialsAvatar(name, 56),
                                        ),
                                      ),
                                      // Online indicator
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: kCyan,
                                            border: Border.all(
                                                color: kCard, width: 2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: kCyan.withOpacity(0.5),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 14),
                                  // ============ INFO ============
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            color: kText,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            letterSpacing: 0.2,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              phone,
                                              style: TextStyle(
                                                color: kTextDim,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: kCyan.withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: kCyan.withOpacity(0.3),
                                                ),
                                              ),
                                              child: Text(
                                                '$followers abonnés',
                                                style: TextStyle(
                                                  color: kCyan,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // ============ ACTION BUTTONS ============
                                  Column(
                                    children: [
                                      // Bouton Follow
                                      GestureDetector(
                                        onTap: () => _toggleFollow(phone),
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: kCyan.withOpacity(
                                              isFollowing ? 0.25 : 0.12,
                                            ),
                                            border: Border.all(
                                              color: isFollowing
                                                  ? kCyan
                                                  : kCyan.withOpacity(0.3),
                                              width: isFollowing ? 2 : 1.5,
                                            ),
                                            boxShadow: isFollowing
                                                ? [
                                                    BoxShadow(
                                                      color: kCyan
                                                          .withOpacity(0.3),
                                                      blurRadius: 8,
                                                    ),
                                                  ]
                                                : [],
                                          ),
                                          child: Icon(
                                            isFollowing
                                                ? Icons.check_rounded
                                                : Icons.add_rounded,
                                            color: kCyan,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Bouton Message
                                      GestureDetector(
                                        onTap: () =>
                                            _startConversation(phone, name),
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: kViolet.withOpacity(0.15),
                                            border: Border.all(
                                              color: kViolet.withOpacity(0.4),
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: kViolet.withOpacity(0.2),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.message_rounded,
                                            color: kViolet,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
    );
  }

  Widget _buildInitialsAvatar(String name, double size) {
    final initials = name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kViolet.withOpacity(0.5),
            kViolet.withOpacity(0.2),
          ],
        ),
        border: Border.all(color: kViolet, width: 1.5),
      ),
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: TextStyle(
            color: kViolet,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.35,
          ),
        ),
      ),
    );
  }
}
