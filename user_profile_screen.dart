import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../app_localizations.dart';
import '../main.dart'
    show globalProfileService, globalThemeProvider, globalLocaleProvider;
import '../services/locale_service.dart';
import '../widgets/user_avatar_widget.dart';
import '../presence_service.dart';
import 'auth_screen.dart';
import '../theme.dart';

class UserProfileScreen extends StatefulWidget {
  final String userPhone;

  const UserProfileScreen({super.key, required this.userPhone});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Future<void> _signOut() async {
    await PresenceService.setOffline(widget.userPhone).catchError((e) {
      debugPrint('Presence setOffline failed (non-critical): $e');
    });
    await globalProfileService.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  Future<void> _toggleBlockContact() async {
    final phoneController = TextEditingController();

    final targetPhone = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: kSurface,
          title: const Text('Bloquer / débloquer'),
          content: TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Numéro à bloquer',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                phoneController.text.trim(),
              ),
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );

    if (targetPhone == null || targetPhone.isEmpty) return;
    if (targetPhone == widget.userPhone) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tu ne peux pas te bloquer toi-même.')),
        );
      }
      return;
    }

    final ref =
        FirebaseFirestore.instance.collection('users').doc(widget.userPhone);
    final snap = await ref.get();
    final blocked = List<String>.from(snap.data()?['blocked'] ?? const []);
    final alreadyBlocked = blocked.contains(targetPhone);

    await ref.set(
      {
        'blocked': alreadyBlocked
            ? FieldValue.arrayRemove([targetPhone])
            : FieldValue.arrayUnion([targetPhone]),
      },
      SetOptions(merge: true),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            alreadyBlocked
                ? 'Contact débloqué: $targetPhone'
                : 'Contact bloqué: $targetPhone',
          ),
        ),
      );
    }
  }

  Future<void> _deletePost(String postId) async {
    await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publication supprimée')),
      );
    }
  }

  Future<void> _showMyPostsManager() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: kCyan.withOpacity(0.18)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.grid_view_rounded, color: kGold),
                    const SizedBox(width: 10),
                    Text(
                      'Mes publications',
                      style:
                          kTextHeadline.copyWith(fontSize: 18, color: kWhite),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Supprime tes posts publiés, sans maquette ni simulation.',
                  style: const TextStyle(color: kTextDim, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .where('owner', isEqualTo: widget.userPhone)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: kGold),
                        );
                      }

                      final posts = snapshot.data!.docs.toList();
                      posts.sort((a, b) {
                        final aTime = a.data()['createdAt'];
                        final bTime = b.data()['createdAt'];
                        final aDate = aTime is Timestamp
                            ? aTime.toDate()
                            : DateTime.fromMillisecondsSinceEpoch(0);
                        final bDate = bTime is Timestamp
                            ? bTime.toDate()
                            : DateTime.fromMillisecondsSinceEpoch(0);
                        return bDate.compareTo(aDate);
                      });

                      if (posts.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: Text(
                              'Aucune publication à gérer',
                              style: TextStyle(color: kTextDim),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: posts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          final data = post.data();
                          final caption = (data['caption'] as String?)?.trim();
                          final type = (data['type'] as String?) ?? 'photo';
                          final likes =
                              List<dynamic>.from(data['likes'] ?? const []);

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: kCard.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(18),
                              border:
                                  Border.all(color: kTextDim.withOpacity(0.12)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: kViolet.withOpacity(0.15),
                                  ),
                                  child: Icon(
                                    type == 'video'
                                        ? Icons.videocam_outlined
                                        : Icons.photo_outlined,
                                    color: kCyan,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        caption?.isNotEmpty == true
                                            ? caption!
                                            : 'Sans légende',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: kWhite,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${likes.length} likes • ${type == 'video' ? 'Vidéo' : 'Photo'}',
                                        style: const TextStyle(
                                          color: kTextDim,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                TextButton.icon(
                                  onPressed: () async {
                                    await _deletePost(post.id);
                                  },
                                  icon: const Icon(Icons.delete_outline,
                                      color: kPink),
                                  label: const Text(
                                    'Supprimer',
                                    style: TextStyle(color: kPink),
                                  ),
                                ),
                              ],
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
      },
    );
  }

  Future<_ProfileStats> _loadProfileStats() async {
    final postsSnap = await FirebaseFirestore.instance
        .collection('posts')
        .where('owner', isEqualTo: widget.userPhone)
        .get();

    final usersSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userPhone)
        .get();

    int likes = 0;
    int views = 0;
    int comments = 0;
    int reposts = 0;

    for (final doc in postsSnap.docs) {
      final data = doc.data();
      likes += List<dynamic>.from(data['likes'] ?? const []).length;
      views += List<dynamic>.from(data['views'] ?? const []).length;
      comments += List<dynamic>.from(data['comments'] ?? const []).length;
      reposts += List<dynamic>.from(data['reposts'] ?? const []).length;
    }

    final userData = usersSnap.data() ?? const <String, dynamic>{};
    final followers = List<dynamic>.from(userData['followers'] ?? const []);
    final following = List<dynamic>.from(userData['following'] ?? const []);

    return _ProfileStats(
      publications: postsSnap.docs.length,
      likes: likes,
      views: views,
      comments: comments,
      reposts: reposts,
      followers: followers.length,
      following: following.length,
    );
  }

  Future<void> _selectTheme(String themeKey) async {
    await globalThemeProvider.setTheme(themeKey);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Thème appliqué: ${globalThemeProvider.current.name}')),
      );
    }
  }

  Future<String?> _uploadAvatar(Uint8List bytes) async {
    final ref = FirebaseStorage.instance.ref(
      'avatars/${widget.userPhone}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  Future<void> _editProfile({required String name, String? avatar}) async {
    final nameController = TextEditingController(text: name);

    final updated = await showModalBottomSheet<_ProfileEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ProfileEditSheet(
          nameController: nameController,
          currentAvatar: avatar,
        );
      },
    );

    if (updated == null || !mounted) return;

    String? avatarUrl = avatar;
    if (updated.avatarBytes != null) {
      avatarUrl = await _uploadAvatar(updated.avatarBytes!);
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userPhone)
        .set(
      {
        'phone': widget.userPhone,
        'name': updated.name.trim(),
        if (avatarUrl != null) 'photoUrl': avatarUrl,
      },
      SetOptions(merge: true),
    );

    await globalProfileService.save(
      phone: widget.userPhone,
      name: updated.name.trim(),
      avatar: avatarUrl,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil mis à jour')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userPhone)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final name = (data['name'] as String?)?.trim().isNotEmpty == true
            ? data['name'] as String
            : (globalProfileService.name ?? widget.userPhone);
        final avatar =
            data['photoUrl'] as String? ?? globalProfileService.avatar;
        final themeName = globalThemeProvider.current.name;
        final accountReady = globalProfileService.isReady;

        return FutureBuilder<_ProfileStats>(
          future: _loadProfileStats(),
          builder: (context, statsSnapshot) {
            final stats = statsSnapshot.data ?? const _ProfileStats();

            return Scaffold(
              backgroundColor: kBg,
              appBar: AppBar(
                titleSpacing: 0,
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: false,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListenableBuilder(
                    listenable: globalProfileService,
                    builder: (context, _) => UserAvatarWidget(
                      avatarUrl: avatar,
                      identifier: widget.userPhone,
                      size: 36,
                      borderColor: kCyan,
                      borderWidth: 1.5,
                    ),
                  ),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context)?.translate('profile') ??
                        'Profil'),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context)
                              ?.translate('profileSubtitle') ??
                          'Paramètres personnels et identité',
                      style: const TextStyle(fontSize: 12, color: kTextDim),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    onPressed: () => _editProfile(name: name, avatar: avatar),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Modifier le profil',
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              body: Container(
                decoration: const BoxDecoration(gradient: kGradientBg),
                child: SafeArea(
                  child: Stack(
                    children: [
                      const _BackgroundOrbs(),
                      ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                        children: [
                          _ProfileHero(
                            name: name,
                            phone: widget.userPhone,
                            avatarUrl: avatar,
                            themeName: themeName,
                            onEdit: () =>
                                _editProfile(name: name, avatar: avatar),
                          ),
                          const SizedBox(height: 18),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.25,
                            children: [
                              _MiniStatCard(
                                title: 'Publications',
                                value: stats.publications.toString(),
                                icon: Icons.grid_view_rounded,
                              ),
                              _MiniStatCard(
                                title: 'Likes',
                                value: stats.likes.toString(),
                                icon: Icons.favorite_outline,
                              ),
                              _MiniStatCard(
                                title: 'Followers',
                                value: stats.followers.toString(),
                                icon: Icons.people_outline,
                              ),
                              _MiniStatCard(
                                title: 'Abonnements',
                                value: stats.following.toString(),
                                icon: Icons.person_add_alt_1_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _TotalOverviewBar(stats: stats),
                          const SizedBox(height: 18),
                          _SectionCard(
                            title: 'Informations',
                            subtitle: 'Vos données principales',
                            children: [
                              _DetailRow(label: 'Nom', value: name),
                              _DetailRow(
                                  label: 'Téléphone', value: widget.userPhone),
                              _DetailRow(
                                  label: 'Thème actif', value: themeName),
                              _DetailRow(
                                label: 'Avatar',
                                value: (avatar != null && avatar.isNotEmpty)
                                    ? 'Défini'
                                    : 'Vide',
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _SectionCard(
                            title: 'Actions rapides',
                            subtitle: 'Gestion simple du compte',
                            children: [
                              _QuickAction(
                                icon: Icons.edit_note_outlined,
                                title: AppLocalizations.of(context)
                                        ?.translate('editName') ??
                                    'Modifier le nom',
                                subtitle: AppLocalizations.of(context)
                                        ?.translate('editNameHint') ??
                                    'Mettre à jour votre identité affichée',
                                onTap: () =>
                                    _editProfile(name: name, avatar: avatar),
                              ),
                              const SizedBox(height: 10),
                              _QuickAction(
                                icon: Icons.palette_outlined,
                                title: AppLocalizations.of(context)
                                        ?.translate('accountTheme') ??
                                    'Thème du compte',
                                subtitle: AppLocalizations.of(context)
                                        ?.translate('chooseTheme') ??
                                    'Choisir le style visuel de l’app',
                                onTap: () => _openThemeChooser(),
                              ),
                              const SizedBox(height: 10),
                              _QuickAction(
                                icon: Icons.language,
                                title: AppLocalizations.of(context)
                                        ?.translate('language') ??
                                    'Langue',
                                subtitle: AppLocalizations.of(context)
                                        ?.translate('chooseLanguage') ??
                                    'Choisir la langue de l\'app',
                                onTap: _openLanguageChooser,
                              ),
                              const SizedBox(height: 10),
                              _QuickAction(
                                icon: Icons.security_outlined,
                                title: AppLocalizations.of(context)
                                        ?.translate('security') ??
                                    'Sécurité',
                                subtitle: AppLocalizations.of(context)
                                        ?.translate('securityHint') ??
                                    'Paramètres protégés et synchronisés',
                                onTap: () {},
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _SectionCard(
                            title: 'Sécurité et contenu',
                            subtitle: 'Vraies actions de compte',
                            children: [
                              _QuickAction(
                                icon: Icons.logout,
                                title: 'Déconnexion',
                                subtitle: 'Quitter proprement le compte',
                                accent: Colors.redAccent,
                                borderColor: Colors.redAccent,
                                onTap: _signOut,
                              ),
                              const SizedBox(height: 10),
                              _QuickAction(
                                icon: Icons.block,
                                title: 'Bloquer / débloquer',
                                subtitle: 'Gérer un contact par numéro',
                                accent: Colors.orangeAccent,
                                borderColor: Colors.orangeAccent,
                                onTap: _toggleBlockContact,
                              ),
                              const SizedBox(height: 10),
                              _QuickAction(
                                icon: Icons.delete_outline,
                                title: 'Mes publications',
                                subtitle: 'Supprimer un post publié',
                                accent: kPink,
                                borderColor: kPink,
                                onTap: _showMyPostsManager,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _SectionCard(
                            title: 'Synchronisation',
                            subtitle: 'État local et cloud',
                            children: [
                              _DetailRow(
                                label: 'Profil local',
                                value: globalProfileService.isReady
                                    ? 'Synchronisé'
                                    : 'À compléter',
                              ),
                              _DetailRow(
                                label: 'Thème sauvegardé',
                                value: globalThemeProvider.current.name,
                              ),
                            ],
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
    );
  }

  Future<void> _openThemeChooser() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _ThemeChooserSheet(
          currentThemeName: globalThemeProvider.current.name,
          onThemeSelected: _selectTheme,
        );
      },
    );
  }

  Future<void> _openLanguageChooser() async {
    final currentLanguageCode = globalLocaleProvider.locale.languageCode;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _LanguageChooserSheet(
          currentLanguageCode: currentLanguageCode,
          onLanguageSelected: (languageCode) {
            Navigator.of(context).pop();
            _selectLanguage(languageCode);
          },
        );
      },
    );
  }

  Future<void> _selectLanguage(String languageCode) async {
    await globalLocaleProvider.setLocale(languageCode);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${AppLocalizations.of(context)?.translate('languageSetOn') ?? 'Langue définie sur'} ${LocaleProvider.languageLabel(languageCode)}',
        ),
      ),
    );
  }
}

class _ProfileStats {
  final int publications;
  final int likes;
  final int views;
  final int comments;
  final int reposts;
  final int followers;
  final int following;

  const _ProfileStats({
    this.publications = 0,
    this.likes = 0,
    this.views = 0,
    this.comments = 0,
    this.reposts = 0,
    this.followers = 0,
    this.following = 0,
  });
}

class _TotalOverviewBar extends StatelessWidget {
  final _ProfileStats stats;

  const _TotalOverviewBar({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kSurface.withOpacity(0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kCyan.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Statistiques globales',
              style: kTextHeadline.copyWith(fontSize: 16, color: kGold)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(children: [
              _StatBadge(label: 'Followers', value: stats.followers.toString()),
              const SizedBox(width: 10),
              _StatBadge(label: 'Suivis', value: stats.following.toString()),
              const SizedBox(width: 10),
              _StatBadge(label: 'Likes', value: stats.likes.toString()),
              const SizedBox(width: 10),
              _StatBadge(label: 'Vues', value: stats.views.toString()),
              const SizedBox(width: 10),
              _StatBadge(label: 'Partages', value: stats.reposts.toString()),
            ]),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;

  const _StatBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kBg.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kViolet.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: kTextDim, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: kWhite, fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final String name;
  final String phone;
  final String? avatarUrl;
  final String themeName;
  final VoidCallback onEdit;

  const _ProfileHero({
    required this.name,
    required this.phone,
    required this.avatarUrl,
    required this.themeName,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [kSurface.withOpacity(0.92), kCard.withOpacity(0.92)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: kCyan.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _Avatar(name: name, avatarUrl: avatarUrl),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          kTextHeadline.copyWith(fontSize: 22, color: kWhite),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: const TextStyle(color: kTextDim, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ChipLabel(icon: Icons.bolt_outlined, label: themeName),
                        const _ChipLabel(
                            icon: Icons.lock_outline, label: 'Compte sécurisé'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: kGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Modifier le profil'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _Avatar({required this.name, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [kViolet, kCyan],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: kCyan.withOpacity(0.28),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ClipOval(
          child: avatarUrl != null && avatarUrl!.isNotEmpty
              ? Image.network(
                  avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallback(),
                )
              : _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: kCard,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: kGold,
          fontSize: 36,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MiniStatCard(
      {required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface.withOpacity(0.86),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kTextDim.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kCyan, size: 20),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: kTextDim, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: kWhite,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SectionCard(
      {required this.title, required this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kSurface.withOpacity(0.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kCyan.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: kTextHeadline.copyWith(fontSize: 16, color: kGold)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: kTextDim, fontSize: 12)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _PostStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _PostStatChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(color: kText, fontSize: 11, height: 1.2)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: kTextDim, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: kWhite,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Color borderColor;
  final VoidCallback onTap;

  const _QuickAction(
      {required this.icon,
      required this.title,
      required this.subtitle,
      this.accent = kViolet,
      this.borderColor = kTextDim,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kCard.withOpacity(0.9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor.withOpacity(0.22)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent.withOpacity(0.95), accent.withOpacity(0.55)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: kWhite, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: kWhite,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(color: kTextDim, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: kTextDim),
          ],
        ),
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ChipLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kBg.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kTextDim.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: kCyan, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: kWhite, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _BackgroundOrbs extends StatelessWidget {
  const _BackgroundOrbs();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -20,
            child: _Orb(color: kCyan.withOpacity(0.12), size: 140),
          ),
          Positioned(
            bottom: 90,
            left: -30,
            child: _Orb(color: kPink.withOpacity(0.10), size: 120),
          ),
        ],
      ),
    );
  }
}

class _ThemeChoice {
  final String key;
  final String label;
  final Color accent;

  const _ThemeChoice({
    required this.key,
    required this.label,
    required this.accent,
  });
}

class _ThemeChooserSheet extends StatelessWidget {
  final String currentThemeName;
  final Future<void> Function(String themeKey) onThemeSelected;

  const _ThemeChooserSheet({
    required this.currentThemeName,
    required this.onThemeSelected,
  });

  static const _themes = [
    _ThemeChoice(key: 'dark_violet', label: 'Violet Nuit', accent: kViolet),
    _ThemeChoice(key: 'dark_cyan', label: 'Cyan Nuit', accent: kCyan),
    _ThemeChoice(key: 'dark_green', label: 'Vert Matrix', accent: kPink),
    _ThemeChoice(key: 'dark_blue', label: 'Bleu Océan', accent: kGold),
    _ThemeChoice(key: 'dark_pink', label: 'Rose Neon', accent: kPink),
    _ThemeChoice(
        key: 'dark_orange', label: 'Orange Feu', accent: Colors.orange),
    _ThemeChoice(key: 'light_white', label: 'Blanc Pur', accent: Colors.white),
    _ThemeChoice(key: 'light_soft', label: 'Beige Doux', accent: kViolet),
    _ThemeChoice(key: 'midnight', label: 'Minuit', accent: kGold),
    _ThemeChoice(key: 'neon', label: 'Neon', accent: kCyan),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: kCyan.withOpacity(0.18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.palette_outlined, color: kGold),
                const SizedBox(width: 10),
                Text(
                  'Choisir un thème',
                  style: kTextHeadline.copyWith(fontSize: 18, color: kWhite),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Thème actuel: $currentThemeName',
              style: const TextStyle(color: kTextDim, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _themes.map((theme) {
                final isActive = theme.label == currentThemeName;
                return GestureDetector(
                  onTap: () => onThemeSelected(theme.key),
                  child: Container(
                    width: 152,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: [
                          theme.accent.withOpacity(0.18),
                          kCard.withOpacity(0.92),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: isActive
                            ? theme.accent
                            : kTextDim.withOpacity(0.15),
                        width: isActive ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.accent,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          theme.label,
                          style: const TextStyle(
                            color: kWhite,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isActive ? 'Actif' : 'Appliquer',
                          style: TextStyle(
                            color: isActive ? theme.accent : kTextDim,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageChoice {
  final String code;
  final String label;

  const _LanguageChoice({required this.code, required this.label});
}

class _LanguageChooserSheet extends StatelessWidget {
  final String currentLanguageCode;
  final void Function(String languageCode) onLanguageSelected;

  const _LanguageChooserSheet({
    required this.currentLanguageCode,
    required this.onLanguageSelected,
  });

  static const _languages = [
    _LanguageChoice(code: 'fr', label: 'Français'),
    _LanguageChoice(code: 'en', label: 'English'),
    _LanguageChoice(code: 'es', label: 'Español'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: kCyan.withOpacity(0.18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.language, color: kGold),
                const SizedBox(width: 10),
                Text(
                  'Choisir une langue',
                  style: kTextHeadline.copyWith(fontSize: 18, color: kWhite),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Langue actuelle: ${_languageLabel(currentLanguageCode)}',
              style: const TextStyle(color: kTextDim, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Column(
              children: _languages.map((language) {
                final isActive = language.code == currentLanguageCode;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: isActive ? kGold : kTextDim.withOpacity(0.14),
                        width: isActive ? 1.5 : 1,
                      ),
                    ),
                    tileColor: isActive ? kGold.withOpacity(0.08) : kCard,
                    title: Text(
                      language.label,
                      style: const TextStyle(color: kWhite),
                    ),
                    trailing:
                        isActive ? const Icon(Icons.check, color: kGold) : null,
                    onTap: () => onLanguageSelected(language.code),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  static String _languageLabel(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'fr':
      default:
        return 'Français';
    }
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;

  const _Orb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 90,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }
}

class _ProfileEditSheet extends StatefulWidget {
  final TextEditingController nameController;
  final String? currentAvatar;

  const _ProfileEditSheet(
      {required this.nameController, required this.currentAvatar});

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  Uint8List? _pickedAvatarBytes;
  String? _pickedFileName;

  bool get _isCurrentAvatarAvailable =>
      widget.currentAvatar != null && widget.currentAvatar!.isNotEmpty;

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _pickedAvatarBytes = file.bytes;
      _pickedFileName = file.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: kCyan.withOpacity(0.18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_outlined, color: kGold),
                const SizedBox(width: 10),
                Text('Modifier le profil',
                    style: kTextHeadline.copyWith(fontSize: 18, color: kWhite)),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [kViolet, kCyan],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: ClipOval(
                        child: _pickedAvatarBytes != null
                            ? Image.memory(_pickedAvatarBytes!,
                                fit: BoxFit.cover)
                            : (_isCurrentAvatarAvailable
                                ? Image.network(widget.currentAvatar!,
                                    fit: BoxFit.cover)
                                : Container(
                                    color: kCard,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.person,
                                        color: kGold, size: 48),
                                  )),
                      ),
                    ),
                  ),
                  FloatingActionButton.small(
                    backgroundColor: kGold,
                    foregroundColor: Colors.black,
                    onPressed: _pickAvatar,
                    child: const Icon(Icons.photo_camera_outlined),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                _pickedFileName != null
                    ? 'Nouvel avatar sélectionné'
                    : 'Avatar du profil',
                style: const TextStyle(color: kTextDim, fontSize: 12),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: widget.nameController,
              style: const TextStyle(color: kWhite),
              decoration: InputDecoration(
                labelText: 'Nom affiché',
                labelStyle: const TextStyle(color: kTextDim),
                filled: true,
                fillColor: kCard,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kCard.withOpacity(0.8),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(Icons.image_outlined, color: kCyan),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.currentAvatar != null &&
                              widget.currentAvatar!.isNotEmpty
                          ? 'Avatar actuel défini'
                          : 'Aucun avatar défini',
                      style: const TextStyle(color: kWhite, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      Navigator.pop(
                        context,
                        _ProfileEditResult(
                          name: widget.nameController.text,
                          avatarBytes: _pickedAvatarBytes,
                        ),
                      );
                    },
                    child: const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileEditResult {
  final String name;
  final Uint8List? avatarBytes;

  const _ProfileEditResult({required this.name, required this.avatarBytes});
}
