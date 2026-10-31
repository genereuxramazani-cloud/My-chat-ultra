import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../cloudinary_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  // AUTH
  final _auth = LocalAuthentication();
  final _phoneC = TextEditingController();
  final _nameC = TextEditingController();

  // ÉTATS
  String _step = 'phone';
  bool _isScanning = false;
  bool _accessDenied = false;
  int _attempts = 0;
  int _countdown = 0;
  bool _dataReady = false;
  String _userPhone = '';
  String _pinInput = '';
  String _pinConfirm = '';
  bool _isConfirming = false;
  String _savedPin = '';

  // ANIMATIONS
  late AnimationController _scanController;
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _splashController;
  late AnimationController _rotateController;
  late AnimationController _shakeController;

  late Animation<double> _scanAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _splashScaleAnim;
  late Animation<double> _splashOpacityAnim;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _checkFirstTime();
  }

  void _initAnimations() {
    _scanController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _glowController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _splashController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _rotateController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));

    _scanAnim = Tween<double>(begin: -1, end: 1).animate(
        CurvedAnimation(parent: _scanController, curve: Curves.easeInOut));
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _glowAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _glowController, curve: Curves.easeOut));
    _splashScaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _splashController, curve: Curves.elasticOut));
    _splashOpacityAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _splashController, curve: Curves.easeIn));
    _shakeAnim = Tween<double>(begin: -10, end: 10).animate(
        CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn));
  }

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('user_phone');
    final pin = prefs.getString('user_pin');
    final name = prefs.getString('user_name');

    if (phone != null && phone.isNotEmpty) {
      setState(() {
        _userPhone = phone;
        _savedPin = pin ?? '';
        if (kIsWeb) {
          _step = pin != null ? 'pin_enter' : 'pin_create';
        } else {
          _step = 'fingerprint';
        }
      });
      await _createUserProfileIfNeeded(phone, name ?? phone);
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    _splashController.dispose();
    _rotateController.dispose();
    _shakeController.dispose();
    _phoneC.dispose();
    _nameC.dispose();
    super.dispose();
  }

  // ── PRÉCHARGEMENT ─────────────────────────────────

  Future<void> _preloadData() async {
    try {
      await Future.wait([
        FirebaseFirestore.instance
            .collection('global_messages')
            .orderBy('time', descending: true)
            .limit(20)
            .get(),
        FirebaseFirestore.instance
            .collection('contacts')
            .where('owner', isEqualTo: _userPhone)
            .get(),
        FirebaseFirestore.instance
            .collection('business')
            .where('owner', isEqualTo: _userPhone)
            .limit(30)
            .get(),
      ]);
    } catch (_) {}
    if (mounted) setState(() => _dataReady = true);
  }

  // ── SUCCÈS → SPLASH ───────────────────────────────

  Future<void> _goToSplash() async {
    setState(() => _step = 'splash');
    _splashController.forward();
    _preloadData();
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (c, a, b) => HomeScreen(userPhone: _userPhone),
          transitionsBuilder: (c, anim, b, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  // ── EMPREINTE (Android) ───────────────────────────

  Future<void> _authenticate() async {
    if (_accessDenied) return;
    setState(() => _isScanning = true);
    _scanController.repeat();
    try {
      final bool canAuth = await _auth.canCheckBiometrics;
      if (!canAuth) {
        _showError("Empreinte non disponible.");
        setState(() => _isScanning = false);
        _scanController.stop();
        return;
      }
      final bool result = await _auth.authenticate(
        localizedReason: 'Scannez votre empreinte pour accéder à MY CHAT ULTRA',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (result) {
        _scanController.stop();
        _glowController.forward();
        await Future.delayed(const Duration(milliseconds: 600));
        _goToSplash();
      } else {
        _attempts++;
        _scanController.stop();
        setState(() => _isScanning = false);
        if (_attempts >= 3) {
          setState(() => _accessDenied = true);
          _startCountdown();
        } else {
          _showError(
              "Empreinte incorrecte. ${3 - _attempts} essai(s) restant(s).");
        }
      }
    } on PlatformException catch (e) {
      _scanController.stop();
      setState(() => _isScanning = false);
      _showError("Erreur: ${e.message}");
    }
  }

  // ── PIN (Web/iPhone) ──────────────────────────────

  void _onPinTap(String digit) {
    if (_pinInput.length >= 4) return;
    setState(() => _pinInput += digit);
    if (_pinInput.length == 4) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_step == 'pin_create') {
          if (!_isConfirming) {
            setState(() {
              _pinConfirm = _pinInput;
              _pinInput = '';
              _isConfirming = true;
            });
          } else {
            if (_pinInput == _pinConfirm) {
              _savePin(_pinInput);
            } else {
              _shakeController.forward(from: 0);
              _showError("Les PIN ne correspondent pas. Recommencez.");
              setState(() {
                _pinInput = '';
                _isConfirming = false;
                _pinConfirm = '';
              });
            }
          }
        } else {
          if (_pinInput == _savedPin) {
            _glowController.forward();
            Future.delayed(const Duration(milliseconds: 400), _goToSplash);
          } else {
            _attempts++;
            _shakeController.forward(from: 0);
            setState(() => _pinInput = '');
            if (_attempts >= 3) {
              setState(() => _accessDenied = true);
              _startCountdown();
            } else {
              _showError(
                  "PIN incorrect. ${3 - _attempts} essai(s) restant(s).");
            }
          }
        }
      });
    }
  }

  void _onPinDelete() {
    if (_pinInput.isEmpty) return;
    setState(() => _pinInput = _pinInput.substring(0, _pinInput.length - 1));
  }

  Future<void> _savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_pin', pin);
    setState(() {
      _savedPin = pin;
      _pinInput = '';
    });
    _goToSplash();
  }

  void _startCountdown() async {
    for (int i = 30; i >= 0; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (mounted) {
      setState(() {
        _accessDenied = false;
        _attempts = 0;
        _countdown = 0;
        _pinInput = '';
      });
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: kPink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── VALIDATION ET SAUVEGARDE ──────────────────────

  Future<void> _saveAndContinue() async {
    final name = _nameC.text.trim();
    final phone = _phoneC.text.trim();

    // Nom obligatoire
    if (name.isEmpty) {
      _showError('Veuillez entrer votre nom.');
      return;
    }

    // Numéro : au moins un chiffre
    if (phone.isEmpty || !phone.contains(RegExp(r'\d'))) {
      _showError('Veuillez entrer un numéro valide.');
      return;
    }

    // 🆕 Vérifier si le numéro est déjà utilisé
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(phone).get();

      if (doc.exists) {
        _showError('Ce numéro est déjà utilisé par un autre compte.');
        return;
      }
    } catch (_) {
      // Si erreur réseau → on laisse continuer
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_phone', phone);
    await prefs.setString('user_name', name);

    setState(() {
      _userPhone = phone;
      _step = kIsWeb ? 'pin_create' : 'fingerprint';
    });

    await _createUserProfileIfNeeded(phone, name);

    if (!kIsWeb) {
      await Future.delayed(const Duration(milliseconds: 400));
      _authenticate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kGradientBg),
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: _step == 'phone'
                ? _buildPhone()
                : _step == 'pin_create' || _step == 'pin_enter'
                    ? _buildPin()
                    : _step == 'fingerprint'
                        ? _buildFingerprint()
                        : _buildSplash(),
          ),
        ),
      ),
    );
  }

  // ── ÉTAPE 1 : NOM + NUMÉRO ────────────────────────

  Widget _buildPhone() {
    return Center(
      key: const ValueKey('phone'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: kCyan, width: 2),
                boxShadow: [
                  BoxShadow(color: kCyan.withOpacity(0.3), blurRadius: 30)
                ],
              ),
              child: const Icon(Icons.bolt, size: 50, color: kCyan),
            ),
            const SizedBox(height: 30),
            const Text("MY CHAT ULTRA",
                style: TextStyle(
                    color: kCyan,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4)),
            const SizedBox(height: 6),
            const Text("Inscription",
                style:
                    TextStyle(color: kTextDim, letterSpacing: 2, fontSize: 12)),
            const SizedBox(height: 40),
            GlassCard(
              borderColor: kCyan,
              child: Column(
                children: [
                  TextField(
                    controller: _nameC,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(color: kText),
                    decoration: const InputDecoration(
                      labelText: "Votre nom",
                      labelStyle: TextStyle(color: kTextDim),
                      prefixIcon: Icon(Icons.person_outline, color: kCyan),
                      hintText: "Ex : Genereux Mr",
                      hintStyle: TextStyle(color: kTextDim),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _phoneC,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: kText),
                    decoration: const InputDecoration(
                      labelText: "Numéro de téléphone",
                      labelStyle: TextStyle(color: kTextDim),
                      prefixIcon: Icon(Icons.phone, color: kCyan),
                      hintText: "Ex : 0612345678",
                      hintStyle: TextStyle(color: kTextDim),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: NeonButton(
                      label: "CONTINUER",
                      icon: kIsWeb ? Icons.pin : Icons.fingerprint,
                      onTap: _saveAndContinue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Déjà un compte ? ",
                    style: TextStyle(color: kTextDim, fontSize: 13)),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                  ),
                  child: const Text("Se connecter",
                      style: TextStyle(
                          color: kCyan,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              "Une seule fois - Vos informations sont sécurisées",
              style: TextStyle(color: kTextDim, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── ÉTAPE 2 WEB : PIN ─────────────────────────────

  Widget _buildPin() {
    final isCreate = _step == 'pin_create';
    return Center(
      key: const ValueKey('pin'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final keypadWidth = availableWidth.isFinite ? availableWidth : 360.0;
          final buttonSize = (keypadWidth - 64) / 3;
          final safeButtonSize = buttonSize.clamp(54.0, 74.0);
          final topSpacing = keypadWidth < 360 ? 28.0 : 50.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.vertical -
                    48,
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("MY CHAT ULTRA",
                        style: TextStyle(
                            color: kCyan,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4)),
                    const SizedBox(height: 6),
                    Text(
                      isCreate
                          ? (_isConfirming
                              ? "CONFIRMEZ VOTRE PIN"
                              : "CRÉEZ VOTRE PIN")
                          : "ENTREZ VOTRE PIN",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: kTextDim, fontSize: 11, letterSpacing: 3),
                    ),
                    SizedBox(height: topSpacing),
                    AnimatedBuilder(
                      animation: _shakeAnim,
                      builder: (c, child) {
                        final dotSize = keypadWidth < 360 ? 16.0 : 20.0;
                        final dotGap = keypadWidth < 360 ? 8.0 : 12.0;
                        return Transform.translate(
                          offset: Offset(_shakeAnim.value, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (i) {
                              final filled = i < _pinInput.length;
                              return Container(
                                margin:
                                    EdgeInsets.symmetric(horizontal: dotGap),
                                width: dotSize,
                                height: dotSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: filled ? kCyan : Colors.transparent,
                                  border: Border.all(
                                    color: filled ? kCyan : kTextDim,
                                    width: 2,
                                  ),
                                  boxShadow: filled
                                      ? [
                                          BoxShadow(
                                              color: kCyan.withOpacity(0.5),
                                              blurRadius: 10)
                                        ]
                                      : null,
                                ),
                              );
                            }),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: keypadWidth < 360 ? 28 : 40),
                    if (!_accessDenied)
                      _buildKeypad(buttonSize: safeButtonSize)
                    else
                      _deniedWidget(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKeypad({required double buttonSize}) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      children: keys.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: row.map((k) {
            if (k.isEmpty) {
              return SizedBox(width: buttonSize, height: buttonSize);
            }
            return GestureDetector(
              onTap: () => k == '⌫' ? _onPinDelete() : _onPinTap(k),
              child: Container(
                width: buttonSize,
                height: buttonSize,
                margin: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kCard,
                  border: Border.all(color: kCyan.withOpacity(0.3), width: 1),
                  boxShadow: [
                    BoxShadow(color: kCyan.withOpacity(0.05), blurRadius: 10)
                  ],
                ),
                child: Center(
                  child: Text(
                    k,
                    style: TextStyle(
                      color: k == '⌫' ? kPink : kText,
                      fontSize: k == '⌫' ? 20 : 24,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  // ── ÉTAPE 2 ANDROID : EMPREINTE ───────────────────

  Widget _buildFingerprint() {
    return Center(
      key: const ValueKey('fingerprint'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("MY CHAT ULTRA",
              style: TextStyle(
                  color: kCyan,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4)),
          const SizedBox(height: 4),
          const Text("ACCÈS SÉCURISÉ",
              style:
                  TextStyle(color: kTextDim, fontSize: 11, letterSpacing: 3)),
          const SizedBox(height: 60),
          GestureDetector(
            onTap: _accessDenied ? null : _authenticate,
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulseAnim, _scanAnim, _glowAnim]),
              builder: (c, child) {
                return Transform.scale(
                  scale: _pulseAnim.value,
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _ring(220, _accessDenied ? kPink : kCyan, 0.2),
                        _ring(185, _accessDenied ? kPink : kCyan, 0.15),
                        _ring(150, _accessDenied ? kPink : kCyan, 1.0,
                            width: 2.0, filled: true),
                        Icon(Icons.fingerprint,
                            size: 90,
                            color: _accessDenied
                                ? kPink
                                : kCyan
                                    .withOpacity(0.7 + _glowAnim.value * 0.3)),
                        if (_isScanning)
                          ClipOval(
                            child: SizedBox(
                              width: 150,
                              height: 150,
                              child: Stack(children: [
                                Positioned(
                                  top: 75 + _scanAnim.value * 72,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 2,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: [
                                        Colors.transparent,
                                        kCyan,
                                        kCyan,
                                        Colors.transparent,
                                      ]),
                                      boxShadow: [
                                        BoxShadow(
                                            color: kCyan.withOpacity(0.9),
                                            blurRadius: 10)
                                      ],
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 50),
          if (_accessDenied)
            _deniedWidget()
          else
            Column(
              children: [
                Text(
                  _isScanning ? "SCAN EN COURS..." : "APPUYEZ POUR SCANNER",
                  style: TextStyle(
                    color: _isScanning ? kCyan : kTextDim,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
                if (_attempts > 0) ...[
                  const SizedBox(height: 8),
                  Text("${3 - _attempts} essai(s) restant(s)",
                      style: const TextStyle(color: kPink, fontSize: 11)),
                ],
              ],
            ),
        ],
      ),
    );
  }

  // ── ÉTAPE 3 : SPLASH ──────────────────────────────

  Widget _buildSplash() {
    return Center(
      key: const ValueKey('splash'),
      child: AnimatedBuilder(
        animation: Listenable.merge([_splashScaleAnim, _rotateController]),
        builder: (c, child) {
          return FadeTransition(
            opacity: _splashOpacityAnim,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(
                      angle: _rotateController.value * 2 * 3.14159,
                      child: const SizedBox(
                        width: 180,
                        height: 180,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(kCyan),
                        ),
                      ),
                    ),
                    Transform.rotate(
                      angle: -_rotateController.value * 2 * 3.14159,
                      child: SizedBox(
                        width: 155,
                        height: 155,
                        child: CircularProgressIndicator(
                          strokeWidth: 1,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              kViolet.withOpacity(0.5)),
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: _splashScaleAnim.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kCard,
                          border: Border.all(color: kCyan, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: kCyan.withOpacity(0.4),
                              blurRadius: 30,
                              spreadRadius: 5,
                            )
                          ],
                        ),
                        child: const Center(
                          child: Text("Mr",
                              style: TextStyle(
                                  color: kCyan,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Text(
                  _dataReady ? "PRÊT !" : "CHARGEMENT...",
                  style: TextStyle(
                    color: _dataReady ? Colors.greenAccent : kTextDim,
                    fontSize: 12,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _dataReady
                      ? "Bienvenue $_userPhone"
                      : "Préparation de votre espace...",
                  style: const TextStyle(color: kTextDim, fontSize: 11),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────

  Widget _ring(double size, Color color, double opacity,
      {double width = 1.5, bool filled = false}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? kCard.withOpacity(0.8) : Colors.transparent,
        border: Border.all(color: color.withOpacity(opacity), width: width),
        boxShadow: filled
            ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 20)]
            : null,
      ),
    );
  }

  Widget _deniedWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPink.withOpacity(0.5)),
        color: kPink.withOpacity(0.08),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock, color: kPink, size: 22),
          const SizedBox(height: 6),
          const Text("ACCÈS REFUSÉ",
              style: TextStyle(
                  color: kPink, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 4),
          Text("Réessayez dans $_countdown sec",
              style: const TextStyle(color: kTextDim, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _createUserProfileIfNeeded(String phone, String name) async {
    try {
      final doc = FirebaseFirestore.instance.collection('users').doc(phone);
      final snap = await doc.get();
      if (!snap.exists) {
        await doc.set({
          'phone': phone,
          'name': name,
          'displayName': name,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  Future<void> _ensureUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final storedName = prefs.getString('user_name') ?? _userPhone;
    await prefs.setString('user_name', storedName);
    await _createUserProfileIfNeeded(_userPhone, storedName);
  }
}
