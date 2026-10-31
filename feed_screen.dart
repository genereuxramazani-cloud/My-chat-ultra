import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../theme.dart';
import '../cloudinary_service.dart';
import '../widgets/glass_add_button.dart';
import '../widgets/music_selection_dialog.dart';
import 'private_screen.dart';

// Minimal video player used by feed posts (provides play/pause control)
class PostVideoPlayer extends StatefulWidget {
  final String url;
  final String postId;
  final String userPhone;
  final bool enableTapToPlayPause;
  final bool startMuted;
  final VoidCallback? onDoubleTap;
  const PostVideoPlayer({
    super.key,
    required this.url,
    required this.postId,
    required this.userPhone,
    this.enableTapToPlayPause = true,
    this.startMuted = false,
    this.onDoubleTap,
  });

  @override
  PostVideoPlayerState createState() => PostVideoPlayerState();
}

class PostVideoPlayerState extends State<PostVideoPlayer> {
  late VideoPlayerController _controller;
  bool _inited = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller.initialize().then((_) {
      if (mounted) setState(() => _inited = true);
      if (widget.startMuted) _controller.setVolume(0);
    });
  }

  void playVideo() {
    if (_inited) _controller.play();
  }

  void pauseVideo() {
    if (_inited) _controller.pause();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_inited) return const Center(child: CircularProgressIndicator());
    return GestureDetector(
      onDoubleTap: widget.onDoubleTap,
      onTap: widget.enableTapToPlayPause
          ? () {
              if (!_inited) return;
              if (_controller.value.isPlaying) {
                pauseVideo();
              } else {
                playVideo();
              }
            }
          : null,
      child: Center(
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }
}

// Simple hexagon painter/clipper used for avatar style in the feed
class HexagonPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  HexagonPainter({required this.color, this.strokeWidth = 0});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = strokeWidth > 0 ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = strokeWidth;
    final path = Path();
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r = w / 2;
    for (int i = 0; i < 6; i++) {
      final angle = (pi / 3) * i - pi / 2;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r = w / 2;
    for (int i = 0; i < 6; i++) {
      final angle = (pi / 3) * i - pi / 2;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class PostCardWidget extends StatefulWidget {
  final DocumentSnapshot doc;
  final String userPhone;
  final Function(String postId, List likes) toggleLike;
  final Function(String postId, List views) countPhotoView;
  final Function(String postId) showComments;
  final Function(String postId, String owner) showPostOptions;
  final Future<Map<String, dynamic>> Function(String userPhone) getUserData;
  final Future<bool> Function(String userPhone) isFollowing;
  final Function(String userPhone) toggleFollowUser;
  final Future<String?> Function(String userPhone) getAvatar;
  final VoidCallback showPostSearch;
  final Map<String, String?> avatarCache;

  // FIX #8 post : caches fournis depuis FeedScreen pour éviter les re-reads
  final Map<String, Map<String, dynamic>> userDataCache;
  final Map<String, bool> followingCache;

  const PostCardWidget({
    super.key,
    required this.doc,
    required this.userPhone,
    required this.toggleLike,
    required this.countPhotoView,
    required this.showComments,
    required this.showPostOptions,
    required this.getUserData,
    required this.isFollowing,
    required this.toggleFollowUser,
    required this.getAvatar,
    required this.showPostSearch,
    required this.avatarCache,
    required this.userDataCache,
    required this.followingCache,
  });

  @override
  State<PostCardWidget> createState() => _PostCardWidgetState();
}

class _PostCardWidgetState extends State<PostCardWidget>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late ScrollController _scrollController;
  bool _headerVisible = true;

  // FIX #1 post : animation like pour la vidéo
  late AnimationController _likeAnimController;
  late Animation<double> _likeScaleAnim;
  bool _showLikeAnim = false;

  // FIX #7 post : référence au player vidéo courant
  final GlobalKey<PostVideoPlayerState> _videoKey = GlobalKey();
  final GlobalKey _engagementBarKey = GlobalKey();

  // Music player
  late AudioPlayer _musicPlayer;
  bool _isMusicPlaying = false;

  // Engagement bar draggable state
  double? _engagementBarX;
  double? _engagementBarY;
  static const _kEngagementBarPrefX = 'engagement_bar_x';
  static const _kEngagementBarPrefY = 'engagement_bar_y';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_syncHeaderVisibility);

    _musicPlayer = AudioPlayer();
    _musicPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isMusicPlaying = state == PlayerState.playing);
      }
    });

    _loadEngagementBarPosition();

    _likeAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _likeScaleAnim = TweenSequence([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.3)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 60),
      TweenSequenceItem(
          tween: Tween(begin: 1.3, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 40),
    ]).animate(_likeAnimController);
  }

  // Play or pause media (called by FeedScreen when page changes)
  void playMedia() async {
    final data = widget.doc.data() as Map<String, dynamic>;
    final isPhoto = data['type'] == 'photo';
    final audioUrl =
        (data['music'] as Map<String, dynamic>?)?['audioUrl'] as String?;
    if (isPhoto) {
      if (audioUrl != null && audioUrl.isNotEmpty) {
        try {
          await _musicPlayer.stop();
          await _musicPlayer.play(UrlSource(audioUrl));
        } catch (e) {
          debugPrint('playMedia error: $e');
        }
      }
    } else {
      _videoKey.currentState?.playVideo();
      if (audioUrl != null && audioUrl.isNotEmpty) {
        try {
          await _musicPlayer.stop();
          await _musicPlayer.play(UrlSource(audioUrl));
        } catch (e) {
          debugPrint('playMedia video music error: $e');
        }
      }
    }
  }

  void pauseMedia() async {
    final data = widget.doc.data() as Map<String, dynamic>;
    final isPhoto = data['type'] == 'photo';
    if (isPhoto) {
      try {
        await _musicPlayer.stop();
      } catch (e) {
        debugPrint('pauseMedia error: $e');
      }
    } else {
      _videoKey.currentState?.pauseVideo();
      try {
        await _musicPlayer.stop();
      } catch (e) {
        debugPrint('pauseMedia video music error: $e');
      }
    }
  }

  Future<void> _loadEngagementBarPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble(_kEngagementBarPrefX);
    final y = prefs.getDouble(_kEngagementBarPrefY);
    if (mounted) {
      setState(() {
        _engagementBarX = x;
        _engagementBarY = y;
      });
    }
  }

  Future<void> _saveEngagementBarPosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kEngagementBarPrefX, _engagementBarX ?? 16.0);
    await prefs.setDouble(_kEngagementBarPrefY, _engagementBarY ?? 0.0);
  }

  void _updateEngagementBarPosition(DragUpdateDetails details) {
    final renderBox =
        _engagementBarKey.currentContext?.findRenderObject() as RenderBox?;
    final barSize = renderBox?.size ?? const Size(280, 64);
    final media = MediaQuery.of(context);
    final maxX = media.size.width - barSize.width - 16;
    final maxY = media.size.height -
        barSize.height -
        media.padding.top -
        media.padding.bottom;

    final currentX = _engagementBarX ?? 16.0;
    final defaultTop =
        media.size.height - barSize.height - 12 - media.padding.bottom;
    final currentY = _engagementBarY ?? defaultTop;

    setState(() {
      _engagementBarX = (currentX + details.delta.dx).clamp(0.0, maxX);
      _engagementBarY = (currentY + details.delta.dy).clamp(0.0, maxY);
    });
  }

  void _endEngagementBarDrag(DragEndDetails details) {
    _saveEngagementBarPosition();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_syncHeaderVisibility);
    _scrollController.dispose();
    _likeAnimController.dispose();
    _musicPlayer.dispose();
    super.dispose();
  }

  void _syncHeaderVisibility() {
    if (!mounted || !_scrollController.hasClients) return;
    final offset = _scrollController.position.pixels;
    final visible = offset <= 40;
    if (_headerVisible != visible) {
      setState(() => _headerVisible = visible);
    }
  }

  void _triggerLikeAnim() {
    setState(() => _showLikeAnim = true);
    _likeAnimController.forward(from: 0).then((_) {
      if (mounted) setState(() => _showLikeAnim = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _buildPostCardContent();
  }

  @override
  bool get wantKeepAlive => true;

  Widget _buildPostCardContent() {
    final data = widget.doc.data() as Map<String, dynamic>;
    final deleted = data['deleted'] == true;
    if (deleted) {
      final owner = data['owner'] ?? '';
      return Container(
        color: kCard,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.delete_outline, size: 56, color: kTextDim),
              const SizedBox(height: 12),
              Text('Publication supprimée',
                  style: TextStyle(color: kTextDim, fontSize: 16)),
              const SizedBox(height: 8),
              Text('Par: ' + (owner as String),
                  style: TextStyle(color: kText, fontSize: 12)),
            ]),
          ),
        ),
      );
    }
    final likes = List<String>.from(data['likes'] ?? []);
    final comments = List.from(data['comments'] ?? []);
    final views = List.from(data['views'] ?? []);
    final owner = data['owner'] ?? '';
    final isLiked = likes.contains(widget.userPhone);
    final isPhoto = data['type'] == 'photo';

    if (isPhoto) widget.countPhotoView(widget.doc.id, views);

    // FIX #2 post : swipe horizontal pour aller au profil
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          // swipe droite → profil de l'auteur
          Navigator.pushNamed(context, '/profile', arguments: owner);
        }
      },
      onDoubleTap: () {
        widget.toggleLike(widget.doc.id, likes);
        _triggerLikeAnim();
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          // ── Header SliverAppBar ──────────────────────────────────
          SliverAppBar(
            floating: true,
            snap: true,
            expandedHeight: 100,
            backgroundColor: Colors.black.v(0.96),
            actions: [
              // FIX #9 post : bouton options visible pour tous
              GestureDetector(
                onTap: () => widget.showPostOptions(widget.doc.id, owner),
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: const Icon(Icons.more_vert,
                      color: Colors.white70, size: 24),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.v(0.96),
                      Colors.black.v(0.62),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: AnimatedOpacity(
                      opacity: _headerVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // FIX #8 post : getUserData avec cache (simplified)
                          FutureBuilder<Map<String, dynamic>>(
                            future: widget.getUserData(owner),
                            builder: (ctx, snap) {
                              final userName = snap.data?['name'] ?? owner;
                              return GestureDetector(
                                onTap: owner == widget.userPhone
                                    ? null
                                    : () => _showAuthorSheet(owner),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildHexAvatar(
                                      phone: owner,
                                      size: 36,
                                      borderColor: kViolet,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(userName, style: kTextHeadline),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    (data['music'] as Map<String, dynamic>?)?[
                                            'label'] ??
                                        'Musique',
                                    style: kTextMeta.copyWith(
                                      color: kCyan,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _isMusicPlaying
                                          ? kPink.withOpacity(0.18)
                                          : kCyan.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: (_isMusicPlaying ? kPink : kCyan)
                                            .withOpacity(0.35),
                                      ),
                                    ),
                                    child: Text(
                                      _isMusicPlaying
                                          ? 'Musique active'
                                          : 'Appuie pour écouter',
                                      style: TextStyle(
                                        color: _isMusicPlaying ? kPink : kCyan,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tap pour lancer ou mettre en pause',
                                style: kTextMeta.copyWith(
                                  color: kTextDim,
                                  fontSize: 10,
                                ),
                              ),
                              if ((data['caption'] as String?)?.isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: 6),
                                Text(
                                  data['caption'],
                                  style: kTextCaption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      kViolet.v(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Media + overlays ────────────────────────────────────
          SliverFillRemaining(
            child: Stack(
              children: [
                // Media fullscreen
                Positioned.fill(
                  child: isPhoto
                      ? GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            final music = (data['music']
                                    as Map<String, dynamic>?)?['audioUrl']
                                as String?;
                            if (music == null || music.isEmpty) return;
                            try {
                              if (_isMusicPlaying) {
                                await _musicPlayer.stop();
                              } else {
                                await _musicPlayer.play(UrlSource(music));
                              }
                            } catch (e) {
                              debugPrint('Error toggling music: $e');
                            }
                          },
                          child: Image.network(
                            data['url'] ?? '',
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                    ? child
                                    : Container(
                                        color: kCard,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: kViolet,
                                          ),
                                        ),
                                      ),
                          ),
                        )
                      : PostVideoPlayer(
                          key: _videoKey,
                          url: data['url'] ?? '',
                          postId: widget.doc.id,
                          userPhone: widget.userPhone,
                          onDoubleTap: () {
                            // FIX #1 post : double-tap sur vidéo
                            widget.toggleLike(widget.doc.id, likes);
                            _triggerLikeAnim();
                          },
                        ),
                ),

                // FIX #1 post : animation cœur au centre
                if (_showLikeAnim)
                  Center(
                    child: ScaleTransition(
                      scale: _likeScaleAnim,
                      child:
                          const Icon(Icons.favorite, color: kPink, size: 100),
                    ),
                  ),

                Positioned(
                  right: 14,
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.v(0.45),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: FutureBuilder<String?>(
                            future: widget.getAvatar(owner),
                            builder: (context, snap) => _buildHexAvatar(
                              phone: owner,
                              size: 52,
                              borderColor: kViolet,
                              avatarUrl: snap.hasData ? snap.data : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (owner != widget.userPhone)
                          // FIX #8 post : isFollowing avec cache
                          FutureBuilder<bool>(
                            future: widget.isFollowing(owner),
                            builder: (ctx, snap) {
                              final following = snap.data ?? false;
                              return GestureDetector(
                                onTap: () => widget.toggleFollowUser(owner),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: following
                                        ? null
                                        : const LinearGradient(
                                            colors: [kViolet, kPink]),
                                    color:
                                        following ? Colors.black.v(0.5) : null,
                                    border: Border.all(
                                        color: following ? kPink : Colors.white,
                                        width: 1.5),
                                  ),
                                  child: Icon(
                                      following ? Icons.remove : Icons.add,
                                      color: Colors.white,
                                      size: 16),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                // Bottom actions always visible
                Positioned(
                  left: _engagementBarX ?? 16,
                  top: _engagementBarY,
                  right: _engagementBarX == null ? 16 : null,
                  bottom: _engagementBarY == null ? 16 : null,
                  child: GestureDetector(
                    key: _engagementBarKey,
                    onPanUpdate: _updateEngagementBarPosition,
                    onPanEnd: _endEngagementBarDrag,
                    child: SafeArea(
                      top: false,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 0, vertical: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.v(0.45),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.v(0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _actionButton(
                              icon: isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              label: '${likes.length}',
                              color: isLiked ? kPink : Colors.white,
                              onTap: () {
                                widget.toggleLike(widget.doc.id, likes);
                                if (isLiked == false) _triggerLikeAnim();
                              },
                            ),
                            const SizedBox(width: 18),
                            _actionButton(
                              icon: Icons.chat_bubble_outline,
                              label: '${comments.length}',
                              color: Colors.white,
                              onTap: () => widget.showComments(widget.doc.id),
                            ),
                            const SizedBox(width: 18),
                            _actionButton(
                              icon: Icons.remove_red_eye_outlined,
                              label: '${views.length}',
                              color: Colors.white70,
                              onTap: () {},
                            ),
                            const Spacer(),
                            _actionButton(
                              icon: Icons.bookmark_border,
                              label: '',
                              color: Colors.white70,
                              onTap: () async {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(widget.userPhone)
                                    .update({
                                  'saved':
                                      FieldValue.arrayUnion([widget.doc.id])
                                });
                                if (!mounted) return;
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(
                                  content: Text('Publication sauvegardée'),
                                  backgroundColor: kViolet,
                                  behavior: SnackBarBehavior.floating,
                                ));
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHexAvatar({
    required String phone,
    double size = 40,
    Color borderColor = kViolet,
    String? avatarUrl,
  }) {
    final hexH = size * 1.15;
    final innerW = size * 0.85;
    final innerH = hexH * 0.85;
    return SizedBox(
      width: size,
      height: hexH,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
              size: Size(size, hexH),
              painter: HexagonPainter(color: borderColor)),
          ClipPath(
            clipper: HexagonClipper(),
            child: SizedBox(
              width: innerW,
              height: innerH,
              child: avatarUrl != null
                  ? Image.network(avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _avatarFallback(phone, borderColor, innerW))
                  : _avatarFallback(phone, borderColor, innerW),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String phone, Color color, double size) => Container(
        color: color.v(0.15),
        child: Center(
          child: Icon(Icons.person_outline, color: color, size: size * 0.42),
        ),
      );

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 6)
                        ])),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAuthorSheet(String owner) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FutureBuilder<Map<String, dynamic>>(
        future: widget.getUserData(owner),
        builder: (context, snap) {
          final userData = snap.data ?? {'name': owner};
          final userName = userData['name'] as String? ?? owner;
          return SafeArea(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    kSurface.v(0.98),
                    kCard.v(0.98),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: kViolet.withOpacity(0.22)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 34,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 46,
                    height: 4,
                    decoration: BoxDecoration(
                      color: kTextDim.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FutureBuilder<String?>(
                    future: widget.getAvatar(owner),
                    builder: (context, avatarSnap) {
                      return _buildHexAvatar(
                        phone: owner,
                        size: 72,
                        borderColor: kCyan,
                        avatarUrl: avatarSnap.data,
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Text(userName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: kText,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      )),
                  const SizedBox(height: 4),
                  Text(owner,
                      style: const TextStyle(color: kTextDim, fontSize: 12)),
                  const SizedBox(height: 10),
                  Text(
                    'Ouvre une conversation privée avec ce posteur.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: kTextDim.withOpacity(0.9),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sheetActionButton(
                    icon: Icons.message_outlined,
                    label: 'Envoyer un message',
                    subtitle: 'Conversation privée immédiate',
                    color: kCyan,
                    expand: true,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PrivateScreen(
                            userPhone: widget.userPhone,
                            initialContact: owner,
                            initialContactData: {
                              'contact': owner,
                              'name': userName,
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sheetActionButton({
    required IconData icon,
    required String label,
    String? subtitle,
    required Color color,
    bool expand = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.18), color.withOpacity(0.08)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.24)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.16),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: kTextDim.withOpacity(0.9),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }

  String _timeAgo(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final time = DateTime.fromMillisecondsSinceEpoch(
          (timestamp as dynamic).millisecondsSinceEpoch);
      final diff = DateTime.now().difference(time);
      if (diff.inSeconds < 60) return 'À l\'instant';
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
      return 'Il y a ${diff.inDays}j';
    } catch (_) {
      return '';
    }
  }
}

// ─────────────────────────────────────────────
// FeedScreen
// ─────────────────────────────────────────────

class FeedScreen extends StatefulWidget {
  final String userPhone;

  const FeedScreen({super.key, required this.userPhone});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with TickerProviderStateMixin {
  late AnimationController _hexPulseController;
  final _captionController = TextEditingController();
  bool _isPosting = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = 'Téléversement en cours...';

  // FIX #8 post : caches globaux pour éviter les re-reads Firestore
  final Map<String, String?> _avatarCache = {};
  final Map<String, Map<String, dynamic>> _userDataCache = {};
  final Map<String, bool> _followingCache = {};

  // FIX #7 post : PageController pour savoir quelle page est visible
  final PageController _pageController = PageController();
  final Map<int, GlobalKey<PostVideoPlayerState>> _videoKeys = {};
  // clés pour accéder aux State des PostCard afin de contrôler audio/video
  final Map<int, GlobalKey<_PostCardWidgetState>> _postWidgetKeys = {};

  // FIX #10 post : clés pour préserver l'état des posts même si le stream se met à jour
  final Map<String, ValueKey<String>> _postKeys = {};

  // top bar visibility when scrolling
  bool _topVisible = true;

  // Active post order utilisée pour ouvrir une publication depuis la recherche
  final List<String> _currentActivePostIds = [];

  @override
  void initState() {
    super.initState();
    _hexPulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);

    // FIX #7 post : pause la vidéo précédente quand on scroll
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      // contrôler les media (vidéo + musique) via les PostCard states
      _postWidgetKeys.forEach((index, key) {
        if (index != page)
          key.currentState?.pauseMedia();
        else
          key.currentState?.playMedia();
      });
    });
  }

  @override
  void dispose() {
    _hexPulseController.dispose();
    _captionController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── Avatar ──────────────────────────────────────────────────────

  Future<String?> _getAvatar(String phone) async {
    if (_avatarCache.containsKey(phone)) return _avatarCache[phone];
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(phone).get();
      final url = doc.data()?['avatar'] as String?;
      _avatarCache[phone] = url;
      return url;
    } catch (_) {
      return null;
    }
  }

  Widget _buildHexAvatar(
      {required String phone, double size = 40, Color borderColor = kViolet}) {
    final hexH = size * 1.15;
    final innerW = size * 0.85;
    final innerH = hexH * 0.85;
    return FutureBuilder<String?>(
      future: _getAvatar(phone),
      builder: (context, snap) => SizedBox(
        width: size,
        height: hexH,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(
              size: Size(size, hexH),
              painter: HexagonPainter(color: borderColor)),
          ClipPath(
            clipper: HexagonClipper(),
            child: SizedBox(
                width: innerW,
                height: innerH,
                child: snap.hasData && snap.data != null
                    ? Image.network(snap.data!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _avatarFallback(phone, borderColor, innerW))
                    : _avatarFallback(phone, borderColor, innerW)),
          ),
        ]),
      ),
    );
  }

  Widget _avatarFallback(String phone, Color color, double size) => Container(
        color: color.v(0.15),
        child: Center(
            child: Text(phone.isNotEmpty ? phone[0].toUpperCase() : '?',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: size * 0.4))),
      );

  bool _isAgoraConfigured() {
    return (dotenv.env['AGORA_APP_ID'] ?? '').isNotEmpty &&
        (dotenv.env['AGORA_TEMP_TOKEN'] ?? '').isNotEmpty;
  }

  Future<void> _showPostSearchDialog() async {
    final queryController = TextEditingController();
    List<QueryDocumentSnapshot>? results;
    bool searching = false;
    Timer? debounce;

    String rangeEnd(String s) => '$s\uf8ff';

    Future<List<QueryDocumentSnapshot>> serverSearch(String q) async {
      final postsRef = FirebaseFirestore.instance.collection('posts');
      final qStart = q;
      final qEnd = rangeEnd(q);

      final resultsSet = <String, QueryDocumentSnapshot>{};

      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: qStart)
          .where('name', isLessThanOrEqualTo: qEnd)
          .get();
      final ownerPhones = userSnapshot.docs.map((d) => d.id).toList();

      if (ownerPhones.isNotEmpty) {
        const batchSize = 10;
        for (var i = 0; i < ownerPhones.length; i += batchSize) {
          final batch = ownerPhones.sublist(
              i, (i + batchSize).clamp(0, ownerPhones.length));
          final snap = await postsRef
              .where('owner', whereIn: batch)
              .orderBy('createdAt', descending: true)
              .get();
          for (final d in snap.docs) resultsSet[d.id] = d;
        }
      }

      final captionSnap = await postsRef
          .where('caption', isGreaterThanOrEqualTo: qStart)
          .where('caption', isLessThanOrEqualTo: qEnd)
          .orderBy('createdAt', descending: true)
          .get();
      for (final d in captionSnap.docs) resultsSet[d.id] = d;

      final urlSnap = await postsRef
          .where('url', isGreaterThanOrEqualTo: qStart)
          .where('url', isLessThanOrEqualTo: qEnd)
          .orderBy('createdAt', descending: true)
          .get();
      for (final d in urlSnap.docs) resultsSet[d.id] = d;

      return resultsSet.values.where((d) {
        final data = d.data() as Map<String, dynamic>;
        return data['deleted'] != true;
      }).toList()
        ..sort((a, b) {
          final at = (a.data() as Map)['createdAt'] as Timestamp?;
          final bt = (b.data() as Map)['createdAt'] as Timestamp?;
          final ad = at?.millisecondsSinceEpoch ?? 0;
          final bd = bt?.millisecondsSinceEpoch ?? 0;
          return bd.compareTo(ad);
        });
    }

    Future<void> doSearch(
        String query, void Function(void Function()) setState) async {
      final q = query.trim().toLowerCase();
      if (q.isEmpty) {
        setState(() {
          results = null;
          searching = false;
        });
        return;
      }

      setState(() {
        searching = true;
        results = null;
      });

      try {
        final serverResults = await serverSearch(q);
        if (serverResults.isNotEmpty) {
          setState(() {
            results = serverResults;
            searching = false;
          });
          return;
        }
      } catch (e) {}

      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(500)
          .get();
      final filtered = <QueryDocumentSnapshot>[];
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['deleted'] == true) continue;
        final caption = (data['caption'] as String? ?? '').toLowerCase();
        final url = (data['url'] as String? ?? '').toLowerCase();
        final ownerPhone = (data['owner'] as String? ?? '');
        var ownerName = ownerPhone.toLowerCase();
        try {
          final ownerData =
              _userDataCache[ownerPhone] ?? await _getUserData(ownerPhone);
          ownerName =
              (ownerData['name'] as String? ?? ownerPhone).toLowerCase();
        } catch (_) {}
        if (caption.contains(q) || ownerName.contains(q) || url.contains(q))
          filtered.add(doc);
      }

      setState(() {
        results = filtered;
        searching = false;
      });
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          backgroundColor: kSurface,
          title: const Text('Rechercher une publication',
              style: TextStyle(color: kText)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: queryController,
                style: const TextStyle(color: kText),
                decoration: InputDecoration(
                  hintText: 'Recherche par texte, auteur ou URL',
                  hintStyle: const TextStyle(color: kTextDim),
                  filled: true,
                  fillColor: kBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: kTextDim.v(0.3)),
                  ),
                ),
                onChanged: (value) {
                  debounce?.cancel();
                  debounce = Timer(const Duration(milliseconds: 400), () {
                    doSearch(value, setState);
                  });
                },
                onSubmitted: (_) async {
                  debounce?.cancel();
                  await doSearch(queryController.text, setState);
                },
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: kViolet,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: () async {
                      debounce?.cancel();
                      await doSearch(queryController.text, setState);
                    },
                    child: const Text('Rechercher'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              if (searching) const LinearProgressIndicator(color: kViolet),
              if (results != null) ...[
                if (results!.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('Aucun résultat',
                        style: TextStyle(color: kTextDim)),
                  )
                else
                  SizedBox(
                    height: 360,
                    child: ListView.builder(
                      itemCount: results!.length,
                      itemBuilder: (context, index) {
                        final data =
                            results![index].data() as Map<String, dynamic>;
                        final ownerPhone = (data['owner'] as String?) ?? '';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            data['caption'] as String? ??
                                'Publication sans texte',
                            style: const TextStyle(color: kText),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: FutureBuilder<Map<String, dynamic>>(
                            future: _getUserData(ownerPhone),
                            builder: (context, snap) {
                              final name =
                                  snap.data?['name'] as String? ?? ownerPhone;
                              return Text(name,
                                  style: const TextStyle(color: kTextDim));
                            },
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            final selectedPostId = results![index].id;
                            Future.microtask(() => _jumpToPost(selectedPostId));
                          },
                        );
                      },
                    ),
                  ),
              ],
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fermer', style: TextStyle(color: kTextDim))),
          ],
        );
      }),
    );
  }

  // ── Upload ───────────────────────────────────────────────────────

  Future<void> _publishPost(String type) async {
    Uint8List? bytes;
    String? fileName;
    XFile? file;

    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(
        type: type == 'photo' ? FileType.image : FileType.video,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      if (picked.bytes == null) return;
      bytes = picked.bytes;
      fileName =
          '${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.name)}';
    } else {
      final picker = ImagePicker();
      XFile? file;
      if (type == 'photo') {
        file = await picker.pickImage(
            source: ImageSource.gallery, imageQuality: 85);
      } else {
        file = await picker.pickVideo(source: ImageSource.gallery);
      }
      if (file == null) return;
      bytes = await file.readAsBytes();
      fileName =
          '${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}';
    }

    if (bytes == null && file == null) return;

    const maxUploadSize = 80 * 1024 * 1024;
    final int sizeInBytes =
        await (file?.length() ?? Future.value(bytes?.lengthInBytes ?? 0));
    if (sizeInBytes > maxUploadSize) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Fichier trop volumineux. Max 80 Mo.'),
            backgroundColor: kPink));
      return;
    }

    setState(() {
      _isPosting = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Téléversement en cours...';
    });

    try {
      setState(() {
        _uploadProgress = 0.2;
        _uploadStatus = 'Envoi vers Cloudinary...';
      });

      final url = file != null
          ? await CloudinaryService.uploadXFile(file)
          : await CloudinaryService.uploadBytes(bytes!, fileName!);
      if (url == null) throw Exception('URL manquante');

      setState(() {
        _uploadProgress = 0.8;
        _uploadStatus = 'Publication...';
      });

      final isVideo = type == 'video' ||
          fileName!.toLowerCase().contains('.mp4') ||
          fileName!.toLowerCase().contains('.mov');

      final publishMeta =
          await showMusicSelectionDialog(context, _captionController);
      if (!mounted) return;
      final caption = publishMeta?['caption'] as String? ?? '';
      final selectedMusic = publishMeta?['music'] as Map<String, dynamic>?;

      final postRef = FirebaseFirestore.instance.collection('posts').doc();
      await postRef.set({
        'id': postRef.id,
        'owner': widget.userPhone,
        'url': url,
        'type': isVideo ? 'video' : 'photo',
        'caption': caption,
        if (selectedMusic != null) 'music': selectedMusic,
        'likes': [],
        'comments': [],
        'views': [],
        // use server timestamp for reliable ordering across all clients
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() => _uploadProgress = 1.0);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Publication réussie !'),
          backgroundColor: kViolet,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
    } catch (e) {
      debugPrint('Erreur publish post: $e');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur: ${e.toString()}'), backgroundColor: kPink));
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // FIX #1 statut : multi-statuts (stocke dans une sous-collection)
  // FIX #6 statut : expiresAt via FieldValue.serverTimestamp()
  // ─────────────────────────────────────────────────────────────────

  Future<void> _addStatus() async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;

    try {
      final fileSize = await file.length();
      const maxUploadSize = 80 * 1024 * 1024;
      if (fileSize > maxUploadSize) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Fichier trop volumineux. Max 80 Mo.'),
              backgroundColor: kPink));
        return;
      }

      final url = await CloudinaryService.uploadXFile(file);
      if (url == null) throw Exception('Upload échoué');

      final statusDocRef = FirebaseFirestore.instance
          .collection('statuses')
          .doc(widget.userPhone);

      await statusDocRef
          .set({'owner': widget.userPhone}, SetOptions(merge: true));

      // FIX #1 statut : sous-collection pour supporter plusieurs statuts
      // FIX #6 statut : expiresAt calculé côté serveur
      await statusDocRef.collection('items').add({
        'owner': widget.userPhone,
        'url': url,
        'createdAt': FieldValue.serverTimestamp(),
        // expiresAt = serverTimestamp + 24h via Cloud Function ou
        // approche simple : on stocke une durée fixe et on filtre côté client
        'expiresAt': Timestamp.fromDate(
          DateTime.now().toUtc().add(const Duration(hours: 24)),
        ),
        'viewers': [],
      });

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Statut publié !'),
          backgroundColor: kViolet,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
    } catch (e) {
      debugPrint('Erreur statut: $e');
    }
  }

  // ── Publish options ─────────────────────────────────────────────

  void _showPublishOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: kSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: kViolet.v(0.3))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: kViolet, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          const Text('NOUVELLE PUBLICATION',
              style: TextStyle(
                  color: kCyan, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
                child: _buildPublishOption(
                    icon: Icons.photo_camera_rounded,
                    label: 'PHOTO',
                    color: kCyan,
                    onTap: () {
                      Navigator.pop(context);
                      _publishPost('photo');
                    })),
            const SizedBox(width: 16),
            Expanded(
                child: _buildPublishOption(
                    icon: Icons.videocam_rounded,
                    label: 'VIDÉO',
                    color: kPink,
                    onTap: () {
                      Navigator.pop(context);
                      _publishPost('video');
                    })),
          ]),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _buildPublishOption(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.v(0.5)),
            color: color.v(0.08),
            boxShadow: [BoxShadow(color: color.v(0.15), blurRadius: 20)]),
        child: Column(children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontSize: 12)),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // FIX #2 statut : barre de progression + SafeArea + swipe pour fermer
  // FIX #7 statut : indicateur visuel "déjà vu"
  // FIX #3 statut : multi-statuts – viewer avec pagination
  // FIX #5 statut : Dialog remplacé par viewer plein écran
  // ─────────────────────────────────────────────────────────────────

  void _viewStatuses(String ownerPhone, List<DocumentSnapshot> statusDocs) {
    if (statusDocs.isEmpty) return;

    // Marquer le premier comme vu
    FirebaseFirestore.instance
        .collection('statuses')
        .doc(ownerPhone)
        .collection('items')
        .doc(statusDocs[0].id)
        .update({
      'viewers': FieldValue.arrayUnion([widget.userPhone])
    });

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => _StatusViewerScreen(
          statusDocs: statusDocs,
          currentUserPhone: widget.userPhone,
          getUserData: _getUserData,
        ),
      ),
    );
  }

  // ── Likes / comments / options ──────────────────────────────────

  Future<void> _toggleLike(String postId, List likes) async {
    final alreadyLiked = likes.contains(widget.userPhone);
    await FirebaseFirestore.instance.collection('posts').doc(postId).update({
      'likes': alreadyLiked
          ? FieldValue.arrayRemove([widget.userPhone])
          : FieldValue.arrayUnion([widget.userPhone]),
    });
  }

  Future<void> _toggleRepost(String postId, List reposts) async {
    final alreadyReposted = reposts.contains(widget.userPhone);
    await FirebaseFirestore.instance.collection('posts').doc(postId).update({
      'reposts': alreadyReposted
          ? FieldValue.arrayRemove([widget.userPhone])
          : FieldValue.arrayUnion([widget.userPhone]),
    });
  }

  Future<void> _countPhotoView(String postId, List views) async {
    if (!views.contains(widget.userPhone)) {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'views': FieldValue.arrayUnion([widget.userPhone])
      });
    }
  }

  void _jumpToPost(String postId) {
    final index = _currentActivePostIds.indexOf(postId);
    if (index < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Publication introuvable dans le flux actuel.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    _pageController.animateToPage(index,
        duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  void _showComments(String postId) {
    final commentController = TextEditingController();
    final commentFocusNode = FocusNode();
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bottomSheetContext) {
        return StatefulBuilder(builder: (context, setState) {
          Future<void> _submitComment() async {
            final text = commentController.text.trim();
            if (text.isEmpty || isSending) return;
            setState(() => isSending = true);

            final commentData = {
              'user': widget.userPhone,
              'text': text,
              'createdAt': FieldValue.serverTimestamp(),
            };

            try {
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(postId)
                  .update({
                'comments': FieldValue.arrayUnion([commentData])
              });
              commentController.clear();
              commentFocusNode.requestFocus();
            } catch (e) {
              debugPrint('submitComment error: $e');
            } finally {
              if (mounted) setState(() => isSending = false);
            }
          }

          return Container(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(color: kViolet.v(0.3)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, color: kViolet),
              const SizedBox(height: 8),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(postId)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final data = snap.data!.data() as Map<String, dynamic>? ?? {};
                  final comments =
                      List<Map<String, dynamic>>.from(data['comments'] ?? []);
                  return SizedBox(
                    height: 300,
                    child: ListView.builder(
                      itemCount: comments.length,
                      itemBuilder: (_, i) {
                        final c = comments[i];
                        final user = c['user'] as String? ?? '';
                        final text = c['text'] as String? ?? '';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: FutureBuilder<Map<String, dynamic>>(
                            future: _getUserData(user),
                            builder: (ctx, s) {
                              final name = s.data?['name'] as String? ?? user;
                              return Text(name,
                                  style: const TextStyle(
                                      color: kCyan,
                                      fontWeight: FontWeight.bold));
                            },
                          ),
                          subtitle:
                              Text(text, style: const TextStyle(color: kText)),
                        );
                      },
                    ),
                  );
                },
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SafeArea(
                  top: false,
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        focusNode: commentFocusNode,
                        autofocus: true,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submitComment(),
                        style: const TextStyle(color: kText),
                        decoration: InputDecoration(
                          hintText: 'Commentaires...',
                          hintStyle: const TextStyle(color: kTextDim),
                          filled: true,
                          fillColor: kBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient:
                            const LinearGradient(colors: [kViolet, kPink]),
                        boxShadow: [
                          BoxShadow(color: kViolet.v(0.4), blurRadius: 12)
                        ],
                      ),
                      child: IconButton(
                        onPressed: _submitComment,
                        icon: const Icon(Icons.send, size: 20),
                        color: Colors.white,
                        splashRadius: 24,
                        tooltip: 'Envoyer',
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          );
        });
      },
    ).whenComplete(() {
      commentController.dispose();
      commentFocusNode.dispose();
    });
  }

  Future<void> _showPostOptions(String postId, String owner) async {
    final isOwner = owner == widget.userPhone;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(color: kViolet.v(0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isOwner)
                  _optionTile(
                    icon: Icons.delete_outline,
                    label: 'Supprimer',
                    color: kPink,
                    onTap: () async {
                      Navigator.pop(ctx);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          backgroundColor: kSurface,
                          title: const Text('Supprimer la publication',
                              style: TextStyle(color: kText)),
                          content: const Text(
                            'Voulez-vous vraiment supprimer cette publication ?',
                            style: TextStyle(color: kTextDim),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Annuler',
                                  style: TextStyle(color: kTextDim)),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('Supprimer',
                                  style: TextStyle(color: kPink)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await FirebaseFirestore.instance
                            .collection('posts')
                            .doc(postId)
                            .update({
                          'deleted': true,
                          'deletedBy': widget.userPhone,
                          'deletedAt': FieldValue.serverTimestamp(),
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Text('Publication supprimée'),
                            backgroundColor: kPink,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ));
                        }
                      }
                    },
                  ),
                _optionTile(
                  icon: Icons.share_outlined,
                  label: 'Partager',
                  color: kCyan,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final doc = await FirebaseFirestore.instance
                        .collection('posts')
                        .doc(postId)
                        .get();
                    final url = (doc.data()?['url'] as String?) ?? '';
                    if (url.isNotEmpty) {
                      Share.share('Regarde cette publication : $url');
                    }
                  },
                ),
                _optionTile(
                  icon: Icons.flag_outlined,
                  label: 'Signaler',
                  color: kGold,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await FirebaseFirestore.instance.collection('reports').add({
                      'postId': postId,
                      'reportedBy': widget.userPhone,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Signalement envoyé'),
                        backgroundColor: Colors.orange,
                      ));
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _optionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: color.v(0.08),
            border: Border.all(color: color.v(0.3))),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 14),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, letterSpacing: 1)),
        ]),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(children: [
        // FIX #7 post : PageView avec PageController géré
        // FIX #10 post : PageStorageKey pour conserver la position et éviter reset
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .orderBy('createdAt', descending: true)
              .limit(100)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return const Center(
                  child: Text('Erreur', style: TextStyle(color: kPink)));
            if (!snapshot.hasData)
              return const Center(
                  child: CircularProgressIndicator(color: kViolet));
            final docs = snapshot.data!.docs;
            // Filter out deleted posts to avoid index shifting
            final activeDocs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['deleted'] != true;
            }).toList();
            _currentActivePostIds
              ..clear()
              ..addAll(activeDocs.map((doc) => doc.id));

            if (activeDocs.isEmpty)
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.photo_library_outlined,
                        size: 60, color: kTextDim),
                    SizedBox(height: 16),
                    Text('Aucune publication',
                        style: TextStyle(color: kTextDim)),
                    SizedBox(height: 8),
                    Text('Sois le premier à publier !',
                        style: TextStyle(color: kTextDim, fontSize: 12)),
                  ],
                ),
              );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final page = _pageController.hasClients
                  ? (_pageController.page?.round() ?? 0)
                  : 0;
              _postWidgetKeys[page]?.currentState?.playMedia();
            });
            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification) {
                  final delta = notification.scrollDelta ?? 0.0;
                  // si delta > 0 => l'utilisateur scrolle vers le bas du contenu (swipe up)
                  if (delta > 0 && _topVisible) {
                    setState(() => _topVisible = false);
                  } else if (delta < 0 && !_topVisible) {
                    setState(() => _topVisible = true);
                  }
                }
                return false;
              },
              child: GridView.builder(
                key: const PageStorageKey('feedPostsGrid'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemCount: activeDocs.length,
                itemBuilder: (ctx, i) => _buildPostGridCard(activeDocs, i),
              ),
            );
          },
        ),

        // Statuts et Recherche en haut
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedSlide(
            offset: _topVisible ? Offset.zero : const Offset(0, -1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: _topVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 220),
              child: SafeArea(
                child: Material(
                  color: Colors.black.v(0.45),
                  elevation: 6,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(18)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 68,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.v(0.08),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.search, color: kCyan),
                                onPressed: _showPostSearchDialog,
                                tooltip: 'Rechercher',
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusRow(),
                      Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 4),
                          decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                            Colors.transparent,
                            kViolet.v(0.5),
                            Colors.transparent
                          ]))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        if (_isPosting)
          Positioned.fill(
            child: Container(
              color: Colors.black.v(0.4),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: kBg.v(0.96),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: kViolet.v(0.3)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.v(0.15),
                            blurRadius: 24,
                            offset: const Offset(0, 8))
                      ]),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_uploadStatus,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: kViolet,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const SizedBox(height: 20),
                    Stack(children: [
                      Container(
                          height: 10,
                          decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(8))),
                      FractionallySizedBox(
                        widthFactor: _uploadProgress.clamp(0.0, 1.0),
                        child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [kViolet, kPink]),
                                borderRadius: BorderRadius.circular(8))),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Text('${(_uploadProgress * 100).toStringAsFixed(0)} %',
                        style: const TextStyle(color: kTextDim)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: GlassAddButton(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        size: 52,
        iconSize: 20,
        colors: [
          kViolet.withOpacity(0.95),
          kPink.withOpacity(0.92),
        ],
        onTap: _isPosting ? null : _showPublishOptions,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // FIX #1 statut + #2 statut : _buildStatusRow lit depuis sous-collection
  //   filtre les statuts expirés côté client (FIX #1 statut)
  //   indicateur déjà vu (FIX #7 statut)
  // ─────────────────────────────────────────────────────────────────

  Widget _buildStatusRow() {
    return SizedBox(
      height: 110,
      child: StreamBuilder<QuerySnapshot>(
        // FIX #1 statut : on lit le parent pour lister les owners
        stream: FirebaseFirestore.instance.collection('statuses').snapshots(),
        builder: (context, snapshot) {
          final ownerDocs = snapshot.data?.docs ?? [];

          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // Moi
              _buildMyStatusBubble(),
              // Autres
              ...ownerDocs
                  .where((d) => d.id != widget.userPhone)
                  .map((ownerDoc) => _buildOtherStatusBubble(ownerDoc.id)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMyStatusBubble() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('statuses')
          .doc(widget.userPhone)
          .collection('items')
          // FIX #1 statut : filtre Firestore sur expiresAt
          .where('expiresAt',
              isGreaterThan: Timestamp.fromDate(DateTime.now().toUtc()))
          .orderBy('expiresAt', descending: false)
          .snapshots(),
      builder: (context, snap) {
        final items = snap.data?.docs ?? [];
        final hasStatus = items.isNotEmpty;
        return _buildHexStatusBubble(
          phone: widget.userPhone,
          label: 'Mon statut',
          hasStatus: hasStatus,
          isMe: true,
          seen: false,
          onTap: hasStatus
              ? () => _viewStatuses(widget.userPhone, items)
              : _addStatus,
        );
      },
    );
  }

  Widget _buildOtherStatusBubble(String ownerPhone) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('statuses')
          .doc(ownerPhone)
          .collection('items')
          // FIX #1 statut : filtre côté Firestore
          .where('expiresAt',
              isGreaterThan: Timestamp.fromDate(DateTime.now().toUtc()))
          .orderBy('expiresAt', descending: false)
          .snapshots(),
      builder: (context, snap) {
        final items = snap.data?.docs ?? [];
        if (items.isEmpty) return const SizedBox.shrink();

        // FIX #7 statut : déjà vu si tous les items ont notre phone dans viewers
        final allSeen = items.every((doc) {
          final viewers =
              List<String>.from((doc.data() as Map)['viewers'] ?? []);
          return viewers.contains(widget.userPhone);
        });

        final short =
            ownerPhone.length >= 6 ? ownerPhone.substring(0, 6) : ownerPhone;

        return _buildHexStatusBubble(
          phone: ownerPhone,
          label: short,
          hasStatus: true,
          isMe: false,
          seen: allSeen,
          onTap: () => _viewStatuses(ownerPhone, items),
        );
      },
    );
  }

  Widget _buildHexStatusBubble({
    required String phone,
    required String label,
    required bool hasStatus,
    required bool isMe,
    required bool seen, // FIX #7 statut
    required VoidCallback onTap,
  }) {
    // FIX #7 statut : couleur grisée si déjà vu
    final color = isMe
        ? kCyan
        : seen
            ? kTextDim
            : (hasStatus ? kViolet : kTextDim);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _hexPulseController,
            builder: (_, __) => SizedBox(
                width: 64,
                height: 72,
                child: Stack(alignment: Alignment.center, children: [
                  if (hasStatus || isMe)
                    CustomPaint(
                        size: const Size(64, 72),
                        painter: HexagonPainter(
                            color: color.v(seen
                                ? 0.2
                                : 0.4 + 0.4 * _hexPulseController.value),
                            strokeWidth: 1)),
                  CustomPaint(
                      size: const Size(58, 66),
                      painter: HexagonPainter(color: color, strokeWidth: 2)),
                  ClipPath(
                    clipper: HexagonClipper(),
                    child: SizedBox(
                        width: 52,
                        height: 60,
                        child: FutureBuilder<String?>(
                          future: _getAvatar(phone),
                          builder: (ctx, snap) {
                            // FIX #7 statut : overlay gris si déjà vu
                            final child = snap.hasData && snap.data != null
                                ? Image.network(snap.data!, fit: BoxFit.cover)
                                : Container(
                                    color: color.v(0.15),
                                    child: isMe && !hasStatus
                                        ? Icon(Icons.add,
                                            color: color, size: 24)
                                        : Icon(Icons.person_outline,
                                            color: color, size: 22));
                            if (seen) {
                              return ColorFiltered(
                                colorFilter: const ColorFilter.matrix([
                                  0.2126,
                                  0.7152,
                                  0.0722,
                                  0,
                                  0,
                                  0.2126,
                                  0.7152,
                                  0.0722,
                                  0,
                                  0,
                                  0.2126,
                                  0.7152,
                                  0.0722,
                                  0,
                                  0,
                                  0,
                                  0,
                                  0,
                                  1,
                                  0,
                                ]),
                                child: child,
                              );
                            }
                            return child;
                          },
                        )),
                  ),
                ])),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5)),
        ]),
      ),
    );
  }

  // FIX #7 post + FIX #8 post : buildPostCard avec index pour le pageController
  // FIX #10 post : utilise une clé stable basée sur l'ID du post
  Widget _buildPostCard(DocumentSnapshot doc, int index) {
    final postId = doc.id;
    _postKeys.putIfAbsent(postId, () => ValueKey(postId));
    _videoKeys.putIfAbsent(index, () => GlobalKey<PostVideoPlayerState>());
    _postWidgetKeys.putIfAbsent(index, () => GlobalKey<_PostCardWidgetState>());
    return KeyedSubtree(
      key: _postKeys[postId],
      child: PostCardWidget(
        key: _postWidgetKeys[index],
        doc: doc,
        userPhone: widget.userPhone,
        toggleLike: _toggleLike,
        countPhotoView: _countPhotoView,
        showComments: _showComments,
        showPostOptions: _showPostOptions,
        getUserData: _getUserData,
        isFollowing: _isFollowing,
        toggleFollowUser: _toggleFollowUser,
        getAvatar: _getAvatar,
        showPostSearch: _showPostSearchDialog,
        avatarCache: _avatarCache,
        userDataCache: _userDataCache,
        followingCache: _followingCache,
      ),
    );
  }

  // Grid card used in the feed (compact Instagram-like card)
  Widget _buildPostGridCard(List<DocumentSnapshot> docs, int index) {
    final doc = docs[index];
    final data = doc.data() as Map<String, dynamic>;
    final url = (data['url'] as String?) ?? '';
    final caption = (data['caption'] as String?) ?? '';
    final owner = (data['owner'] as String?) ?? '';
    final type = (data['type'] as String?) ?? 'photo';
    final likes = List<String>.from(data['likes'] ?? []);
    final comments = List.from(data['comments'] ?? []);
    final reposts = List<String>.from(data['reposts'] ?? []);
    final isLiked = likes.contains(widget.userPhone);
    final isReposted = reposts.contains(widget.userPhone);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _openFullScreenViewer(docs, index),
            child: Container(
              decoration: BoxDecoration(
                  color: kCard, borderRadius: BorderRadius.circular(12)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: url.isNotEmpty
                    ? (type == 'video'
                        ? PostVideoPlayer(
                            url: url,
                            postId: doc.id,
                            userPhone: widget.userPhone,
                            enableTapToPlayPause: false,
                            startMuted: true,
                          )
                        : Image.network(url,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, __, ___) =>
                                Container(color: kBg)))
                    : Container(color: kBg),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                GestureDetector(
                  onTap: () => _toggleLike(doc.id, likes),
                  child: Row(children: [
                    Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? kPink : kText,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text('${likes.length}',
                        style: const TextStyle(color: kTextDim, fontSize: 12)),
                  ]),
                ),
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: () => _showComments(doc.id),
                  child: Row(children: [
                    const Icon(Icons.chat_bubble_outline,
                        color: kText, size: 18),
                    const SizedBox(width: 6),
                    Text('${comments.length}',
                        style: const TextStyle(color: kTextDim, fontSize: 12)),
                  ]),
                ),
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: () => _toggleRepost(doc.id, reposts),
                  child: Row(children: [
                    Icon(
                      Icons.repeat,
                      color: isReposted ? kPink : kText,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text('${reposts.length}',
                        style: const TextStyle(color: kTextDim, fontSize: 12)),
                  ]),
                ),
              ]),
              GestureDetector(
                onTap: () {
                  if (url.isNotEmpty)
                    Share.share('Regarde cette publication : $url');
                },
                child: const Icon(Icons.share, color: kText, size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 36,
                child: _buildHexAvatar(
                    phone: owner, size: 36, borderColor: kViolet)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(caption,
                    style: const TextStyle(color: kText, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ],
    );
  }

  void _openFullScreenViewer(List<DocumentSnapshot> docs, int initialIndex) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => FullScreenViewer(
                  docs: docs,
                  initialIndex: initialIndex,
                  userPhone: widget.userPhone,
                )));
  }

  // FIX #8 post : _getUserData avec cache
  Future<Map<String, dynamic>> _getUserData(String userPhone) async {
    if (_userDataCache.containsKey(userPhone)) {
      return _userDataCache[userPhone]!;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userPhone)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _userDataCache[userPhone] = data;
        return data;
      }
    } catch (_) {}
    final fallback = {'name': userPhone};
    _userDataCache[userPhone] = fallback;
    return fallback;
  }

  // FIX #8 post : _isFollowing avec cache
  Future<bool> _isFollowing(String userPhone) async {
    if (_followingCache.containsKey(userPhone)) {
      return _followingCache[userPhone]!;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userPhone)
          .get();
      if (doc.exists) {
        final following = List<String>.from(doc['following'] ?? []);
        final result = following.contains(userPhone);
        _followingCache[userPhone] = result;
        return result;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _toggleFollowUser(String userPhone) async {
    final isFollowingNow = await _isFollowing(userPhone);
    // invalide le cache pour cet utilisateur
    _followingCache.remove(userPhone);

    final batch = FirebaseFirestore.instance.batch();
    final profileRef =
        FirebaseFirestore.instance.collection('users').doc(userPhone);
    final currentRef =
        FirebaseFirestore.instance.collection('users').doc(widget.userPhone);

    if (isFollowingNow) {
      batch.update(profileRef, {
        'followers': FieldValue.arrayRemove([widget.userPhone])
      });
      batch.update(currentRef, {
        'following': FieldValue.arrayRemove([userPhone])
      });
    } else {
      batch.update(profileRef, {
        'followers': FieldValue.arrayUnion([widget.userPhone])
      });
      batch.update(currentRef, {
        'following': FieldValue.arrayUnion([userPhone])
      });
    }
    await batch.commit();
    setState(() {});
  }
}

// ─────────────────────────────────────────────
// FIX #2 statut + #3 statut + #5 statut :
//   Viewer plein écran avec barre de progression,
//   pagination multi-statuts, SafeArea, swipe pour fermer
// ─────────────────────────────────────────────

class FullScreenViewer extends StatefulWidget {
  final List<DocumentSnapshot> docs;
  final int initialIndex;
  final String userPhone;

  const FullScreenViewer(
      {super.key,
      required this.docs,
      required this.initialIndex,
      required this.userPhone});

  @override
  State<FullScreenViewer> createState() => _FullScreenViewerState();
}

class _FullScreenViewerState extends State<FullScreenViewer> {
  late PageController _controller;
  final Map<int, GlobalKey<PostVideoPlayerState>> _videoKeys = {};
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    // Clamp the requested initial index to the available range so the
    // PageController always starts on a valid page even if the caller
    // passed an out-of-range value.
    if (widget.docs.isEmpty) {
      _currentPage = 0;
    } else if (_currentPage < 0) {
      _currentPage = 0;
    } else if (_currentPage >= widget.docs.length) {
      _currentPage = widget.docs.length - 1;
    }
    _controller = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        PageView.builder(
          controller: _controller,
          scrollDirection: Axis.vertical,
          itemCount: widget.docs.length,
          onPageChanged: (i) {
            if (i == _currentPage) return;
            _videoKeys[_currentPage]?.currentState?.pauseVideo();
            _currentPage = i;
            _videoKeys[i]?.currentState?.playVideo();
          },
          itemBuilder: (ctx, i) {
            final doc = widget.docs[i];
            _videoKeys.putIfAbsent(i, () => GlobalKey<PostVideoPlayerState>());
            return FullScreenPost(
              key: ValueKey(doc.id),
              doc: doc,
              userPhone: widget.userPhone,
              videoKey: _videoKeys[i],
            );
          },
        ),

        // Back button top-right
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class FullScreenPost extends StatelessWidget {
  final DocumentSnapshot doc;
  final String userPhone;
  final GlobalKey<PostVideoPlayerState>? videoKey;

  const FullScreenPost(
      {super.key, required this.doc, required this.userPhone, this.videoKey});

  Future<void> _toggleLike(String postId, List likes) async {
    final alreadyLiked = likes.contains(userPhone);
    await FirebaseFirestore.instance.collection('posts').doc(postId).update({
      'likes': alreadyLiked
          ? FieldValue.arrayRemove([userPhone])
          : FieldValue.arrayUnion([userPhone])
    });
  }

  @override
  Widget build(BuildContext context) {
    final postId = doc.id;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final data = snap.data!.data() as Map<String, dynamic>;
        final type = (data['type'] as String?) ?? 'photo';
        final url = (data['url'] as String?) ?? '';
        final likes = List<String>.from(data['likes'] ?? []);

        Widget media;
        if (type == 'video') {
          media = PostVideoPlayer(
            key: videoKey,
            url: url,
            postId: postId,
            userPhone: userPhone,
            enableTapToPlayPause: true,
            startMuted: false,
          );
        } else {
          media = Container(
            color: Colors.black,
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(color: Colors.black),
              ),
            ),
          );
        }

        return Stack(children: [
          Positioned.fill(child: media),

          // Right-side reaction buttons
          Positioned(
            right: 12,
            top: MediaQuery.of(context).size.height * 0.25,
            bottom: MediaQuery.of(context).size.height * 0.25,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _toggleLike(postId, likes),
                  child: Column(children: [
                    Icon(
                        likes.contains(userPhone)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: likes.contains(userPhone)
                            ? Colors.red
                            : Colors.white,
                        size: 36),
                    const SizedBox(height: 6),
                    Text('${likes.length}',
                        style: const TextStyle(color: Colors.white))
                  ]),
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () => showModalBottomSheet(
                      context: context,
                      builder: (_) => Container(
                            height: 200,
                            color: kSurface,
                            child: Center(child: Text('Commentaires...')),
                          )),
                  child: Column(children: const [
                    Icon(Icons.chat_bubble_outline,
                        color: Colors.white, size: 32),
                    SizedBox(height: 6),
                  ]),
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () async {
                    final url = (data['url'] as String?) ?? '';
                    if (url.isNotEmpty)
                      Share.share('Regarde cette publication : $url');
                  },
                  child: Column(children: const [
                    Icon(Icons.share, color: Colors.white, size: 28),
                    SizedBox(height: 6),
                  ]),
                ),
              ],
            ),
          ),
          // Caption at bottom-left
          Positioned(
            left: 12,
            right: 88,
            bottom: 24,
            child: SafeArea(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(postId)
                    .snapshots(),
                builder: (ctx, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  final data = snap.data!.data() as Map<String, dynamic>;
                  final caption = (data['caption'] as String?) ?? '';
                  final owner = (data['owner'] as String?) ?? '';
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.black.withOpacity(0.25)
                      ]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(owner,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(caption,
                              style: const TextStyle(color: Colors.white)),
                        ]),
                  );
                },
              ),
            ),
          ),
        ]);
      },
    );
  }
}

class _StatusViewerScreen extends StatefulWidget {
  final List<DocumentSnapshot> statusDocs;
  final String currentUserPhone;
  final Future<Map<String, dynamic>> Function(String) getUserData;

  const _StatusViewerScreen({
    required this.statusDocs,
    required this.currentUserPhone,
    required this.getUserData,
  });

  @override
  State<_StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<_StatusViewerScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _progressController;

  static const Duration _statusDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _progressController =
        AnimationController(vsync: this, duration: _statusDuration);
    _startProgress();
  }

  void _startProgress() {
    _progressController.forward(from: 0).then((_) {
      if (mounted) _next();
    });
  }

  void _next() {
    if (_currentIndex < widget.statusDocs.length - 1) {
      setState(() => _currentIndex++);
      _markViewed();
      _startProgress();
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _startProgress();
    }
  }

  void _markViewed() {
    final doc = widget.statusDocs[_currentIndex];
    final data = doc.data() as Map<String, dynamic>;
    final owner = data['owner'] as String? ?? '';
    FirebaseFirestore.instance
        .collection('statuses')
        .doc(owner)
        .collection('items')
        .doc(doc.id)
        .update({
      'viewers': FieldValue.arrayUnion([widget.currentUserPhone])
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.statusDocs[_currentIndex];
    final data = doc.data() as Map<String, dynamic>;
    final owner = data['owner'] as String? ?? '';
    final url = data['url'] as String? ?? '';
    final viewers = List<String>.from(data['viewers'] ?? []);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          // FIX #5 statut : swipe vertical pour fermer
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! > 300) {
              Navigator.pop(context);
            }
          },
          onTapDown: (details) {
            final halfWidth = MediaQuery.of(context).size.width / 2;
            if (details.localPosition.dx < halfWidth) {
              _prev();
            } else {
              _next();
            }
          },
          child: Stack(children: [
            // Image
            Positioned.fill(
              child: url.isNotEmpty
                  ? Image.network(url, fit: BoxFit.contain)
                  : const SizedBox.shrink(),
            ),

            // FIX #2 statut : barres de progression
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: List.generate(
                  widget.statusDocs.length,
                  (i) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: i < _currentIndex
                            ? Container(height: 3, color: Colors.white)
                            : i == _currentIndex
                                ? AnimatedBuilder(
                                    animation: _progressController,
                                    builder: (_, __) => LinearProgressIndicator(
                                      value: _progressController.value,
                                      backgroundColor: Colors.white.v(0.3),
                                      valueColor: const AlwaysStoppedAnimation(
                                          Colors.white),
                                      minHeight: 3,
                                    ),
                                  )
                                : Container(
                                    height: 3, color: Colors.white.v(0.3)),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Header : nom + fermer
            Positioned(
              top: 20,
              left: 12,
              right: 12,
              child: Row(children: [
                FutureBuilder<Map<String, dynamic>>(
                  future: widget.getUserData(owner),
                  builder: (ctx, snap) {
                    final name = snap.data?['name'] ?? owner;
                    return Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 6)
                            ]));
                  },
                ),
                const Spacer(),
                // FIX #5 statut : info viewers
                if (owner == widget.currentUserPhone)
                  Row(children: [
                    const Icon(Icons.remove_red_eye_outlined,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 4),
                    Text('${viewers.length}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                    const SizedBox(width: 12),
                  ]),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _showAuthorSheet(String owner) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FutureBuilder<Map<String, dynamic>>(
        future: widget.getUserData(owner),
        builder: (context, snap) {
          final userData = snap.data ?? {'name': owner};
          final userName = userData['name'] as String? ?? owner;
          return SafeArea(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    kSurface.v(0.98),
                    kCard.v(0.98),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: kViolet.withOpacity(0.22)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 34,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 46,
                    height: 4,
                    decoration: BoxDecoration(
                      color: kTextDim.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildStatusAvatar(
                    phone: owner,
                    name: userName,
                    size: 72,
                    borderColor: kCyan,
                  ),
                  const SizedBox(height: 14),
                  Text(userName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: kText,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      )),
                  const SizedBox(height: 4),
                  Text(owner,
                      style: const TextStyle(color: kTextDim, fontSize: 12)),
                  const SizedBox(height: 10),
                  Text(
                    'Ouvre une conversation privée avec ce posteur.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: kTextDim.withOpacity(0.9),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sheetActionButton(
                    icon: Icons.message_outlined,
                    label: 'Envoyer un message',
                    subtitle: 'Conversation privée immédiate',
                    color: kCyan,
                    expand: true,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PrivateScreen(
                            userPhone: widget.currentUserPhone,
                            initialContact: owner,
                            initialContactData: {
                              'contact': owner,
                              'name': userName,
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sheetActionButton({
    required IconData icon,
    required String label,
    String? subtitle,
    required Color color,
    bool expand = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.18), color.withOpacity(0.08)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.24)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.16),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: kTextDim.withOpacity(0.9),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusAvatar({
    required String phone,
    required String name,
    required double size,
    required Color borderColor,
  }) {
    final hexH = size * 1.15;
    final innerW = size * 0.85;
    final innerH = hexH * 0.85;
    return SizedBox(
      width: size,
      height: hexH,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, hexH),
            painter: HexagonPainter(color: borderColor),
          ),
          ClipPath(
            clipper: HexagonClipper(),
            child: SizedBox(
              width: innerW,
              height: innerH,
              child: FutureBuilder<Map<String, dynamic>>(
                future: widget.getUserData(phone),
                builder: (context, snap) {
                  final avatarUrl = snap.data?['avatar'] as String?;
                  if (avatarUrl != null && avatarUrl.isNotEmpty) {
                    return Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _statusAvatarFallback(
                        name: name,
                        color: borderColor,
                        size: innerW,
                      ),
                    );
                  }
                  return _statusAvatarFallback(
                    name: name,
                    color: borderColor,
                    size: innerW,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusAvatarFallback({
    required String name,
    required Color color,
    required double size,
  }) =>
      Container(
        color: color.v(0.15),
        child: Center(
          child: Icon(Icons.person_outline, color: color, size: size * 0.4),
        ),
      );
}
