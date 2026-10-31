import 'package:flutter/material.dart';
import '../theme.dart';
import '../presence_service.dart';
import '../services/chat_alert_service.dart';
import '../main.dart' show globalProfileService;
import '../widgets/user_avatar_widget.dart';

import 'feed_screen.dart';
import 'private_screen.dart';
import 'business_screen.dart';
import 'neural_screen.dart';
import 'user_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userPhone;
  const HomeScreen({super.key, required this.userPhone});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  int _index = 0;
  bool _isNavBarVisible = true;
  bool _shouldIgnoreScrollNotifications = false;

  late final AnimationController _pulseCtrl;
  late final AnimationController _scanCtrl;
  late final AnimationController _tabCtrl;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _scanAnim;
  late final Animation<double> _tabAnim;

  static const _tabs = [
    _TabData(Icons.forum_outlined, Icons.forum, 'Feed', kCyan),
    _TabData(Icons.lock_outline, Icons.lock, 'Privé', kViolet),
    _TabData(Icons.bar_chart_outlined, Icons.bar_chart, 'Business', kGold),
    _TabData(Icons.psychology_outlined, Icons.psychology, 'Neural', kPink),
    _TabData(Icons.person_outline, Icons.person, 'Profil', kCyan),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PresenceService.setOnline(widget.userPhone).catchError((e) {
      debugPrint('Presence setOnline failed (non-critical): $e');
    });
    ChatAlertService().startForUser(widget.userPhone);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _tabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _scanAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanCtrl, curve: Curves.linear),
    );
    _tabAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _tabCtrl, curve: Curves.elasticOut),
    );

    _tabCtrl.forward();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        PresenceService.setOnline(widget.userPhone).catchError((e) {
          debugPrint('Presence setOnline failed (non-critical): $e');
        });
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        PresenceService.setOffline(widget.userPhone).catchError((e) {
          debugPrint('Presence setOffline failed (non-critical): $e');
        });
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PresenceService.setOffline(widget.userPhone).catchError((e) {
      debugPrint('dispose Presence setOffline failed (non-critical): $e');
    });
    ChatAlertService().stop();
    _pulseCtrl.dispose();
    _scanCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onTabTap(int i) {
    if (i == _index) return;
    setState(() {
      _index = i;
      _isNavBarVisible = true; // Reset visibility when changing tabs
      _shouldIgnoreScrollNotifications =
          true; // Ignore scroll events during tab switch
    });
    _tabCtrl
      ..reset()
      ..forward();

    // Re-enable scroll notifications after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _shouldIgnoreScrollNotifications = false);
      }
    });
  }

  Widget _buildCurrentScreen() {
    switch (_index) {
      case 0:
        return FeedScreen(userPhone: widget.userPhone);
      case 1:
        return PrivateScreen(
          userPhone: widget.userPhone,
          onReturnToFeed: () => _onTabTap(0),
        );
      case 2:
        return BusinessScreen(userPhone: widget.userPhone);
      case 3:
        return NeuralScreen(
          userPhone: widget.userPhone,
          onNavigateToFeed: () => _onTabTap(0),
        );
      case 4:
        return UserProfileScreen(userPhone: widget.userPhone);
      default:
        return FeedScreen(userPhone: widget.userPhone);
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    // Ignore scroll notifications during tab transitions
    if (_shouldIgnoreScrollNotifications) {
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0.0;
      if (delta > 2 && _isNavBarVisible) {
        setState(() => _isNavBarVisible = false);
      } else if (delta < -2 && !_isNavBarVisible) {
        setState(() => _isNavBarVisible = true);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: kBg,
      extendBody: true,
      body: Stack(
        children: [
          const _GridBackground(),
          if (_index == 0)
            AnimatedBuilder(
              animation: _scanAnim,
              builder: (_, __) => Positioned(
                top: MediaQuery.of(context).size.height * _scanAnim.value,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        kCyan.withOpacity(0.15),
                        kCyan.withOpacity(0.4),
                        kCyan.withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: _index == 0
                ? NotificationListener<ScrollNotification>(
                    onNotification: _handleScrollNotification,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: KeyedSubtree(
                        key: ValueKey(_index),
                        child: _buildCurrentScreen(),
                      ),
                    ),
                  )
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: KeyedSubtree(
                      key: ValueKey(_index),
                      child: _buildCurrentScreen(),
                    ),
                  ),
          ),
          if (_index == 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _FloatingHeader(
                userPhone: widget.userPhone,
                pulseAnim: _pulseAnim,
                activeColor: _tabs[0].color,
              ),
            ),
        ],
      ),
      bottomNavigationBar: (_index == 1 || _index == 3)
          ? null
          : AnimatedSlide(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              offset: _isNavBarVisible ? Offset.zero : const Offset(0, 1),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isNavBarVisible ? 1 : 0,
                child: _buildNavBar(bottomPadding),
              ),
            ),
    );
  }

  Widget _buildNavBar(double bottomPadding) {
    return Container(
      padding: EdgeInsets.fromLTRB(8, 10, 8, 10 + bottomPadding),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      decoration: BoxDecoration(
        color: kSurface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kCyan.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: _tabs[_index].color.withOpacity(0.2),
            blurRadius: 24,
            spreadRadius: 2,
          ),
          BoxShadow(color: kBg.withOpacity(0.8), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(
          _tabs.length,
          (i) => _NavItem(
            data: _tabs[i],
            isActive: _index == i,
            tabAnim: _tabAnim,
            onTap: () => _onTabTap(i),
          ),
        ),
      ),
    );
  }
}

class _FloatingHeader extends StatelessWidget {
  final String userPhone;
  final Animation<double> pulseAnim;
  final Color activeColor;

  const _FloatingHeader({
    required this.userPhone,
    required this.pulseAnim,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 20,
        right: 20,
        bottom: 10,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kBg, kBg.withOpacity(0.0)],
        ),
      ),
      child: Row(
        children: [
          ListenableBuilder(
            listenable: globalProfileService,
            builder: (context, _) => UserAvatarWidget(
              avatarUrl: globalProfileService.avatar,
              identifier: userPhone,
              size: 38,
              borderColor: activeColor,
              borderWidth: 1.5,
              pulseAnimation: pulseAnim,
            ),
          ),
          const SizedBox(width: 12),
          const Spacer(),
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, __) => Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kCard.withOpacity(0.6),
                border: Border.all(
                  color: activeColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.wifi_tethering,
                color: activeColor.withOpacity(0.6 + pulseAnim.value * 0.4),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _TabData data;
  final bool isActive;
  final Animation<double> tabAnim;
  final VoidCallback onTap;

  const _NavItem({
    required this.data,
    required this.isActive,
    required this.tabAnim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 16 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isActive ? data.color.withOpacity(0.12) : Colors.transparent,
          border: isActive
              ? Border.all(color: data.color.withOpacity(0.3), width: 1)
              : null,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: data.color.withOpacity(0.2),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? data.activeIcon : data.icon,
              color: isActive ? data.color : kTextDim,
              size: isActive ? 22 : 20,
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              AnimatedBuilder(
                animation: tabAnim,
                builder: (_, __) => Opacity(
                  opacity: tabAnim.value.clamp(0.0, 1.0),
                  child: Text(
                    data.label,
                    style: TextStyle(
                      color: data.color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GridBackground extends StatelessWidget {
  const _GridBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _GridPainter(),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kCyan.withOpacity(0.03)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const step = 40.0;

    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    final dotPaint = Paint()
      ..color = kCyan.withOpacity(0.07)
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.0, dotPaint);
      }
    }

    final circlePaint = Paint()
      ..color = kViolet.withOpacity(0.04)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.15),
      80,
      circlePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.7),
      60,
      circlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TabData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;

  const _TabData(this.icon, this.activeIcon, this.label, this.color);
}
