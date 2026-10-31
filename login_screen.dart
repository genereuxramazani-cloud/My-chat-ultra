import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'auth_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameC = TextEditingController();
  final _phoneC = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameC.dispose();
    _phoneC.dispose();
    super.dispose();
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

  Future<void> _loginUser() async {
    final name = _nameC.text.trim();
    final phone = _phoneC.text.trim();

    if (name.isEmpty) {
      _showError('Veuillez entrer votre nom.');
      return;
    }

    if (phone.isEmpty || !phone.contains(RegExp(r'\d'))) {
      _showError('Veuillez entrer un numéro valide.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Rechercher l'utilisateur par nom ET numéro
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isEqualTo: name)
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        _showError('Aucun compte trouvé avec ces informations.');
        setState(() => _isLoading = false);
        return;
      }

      // Récupérer tous les champs de l'utilisateur
      final userDoc = query.docs.first;
      final userData = userDoc.data() as Map<String, dynamic>;

      // Sauvegarder les données en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_phone', phone);
      await prefs.setString('user_name', userData['name'] as String? ?? name);
      await prefs.setString('user_id', userDoc.id); // userId = phone

      if (userData['displayName'] != null) {
        await prefs.setString('user_display_name', userData['displayName']);
      }
      if (userData['photoUrl'] != null) {
        await prefs.setString('user_avatar', userData['photoUrl']);
      }
      if (userData['bio'] != null) {
        await prefs.setString('user_bio', userData['bio']);
      }

      if (!mounted) return;

      // Aller vers HomeScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(userPhone: phone),
        ),
      );
    } catch (e) {
      _showError('Erreur: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kGradientBg),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
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
                const Text("Connexion",
                    style: TextStyle(
                        color: kTextDim, letterSpacing: 2, fontSize: 12)),
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
                        enabled: !_isLoading,
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
                        enabled: !_isLoading,
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
                        child: _isLoading
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: kCyan, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                        color: kCyan.withOpacity(0.3),
                                        blurRadius: 15,
                                        spreadRadius: 1),
                                  ],
                                  gradient: LinearGradient(
                                    colors: [
                                      kCyan.withOpacity(0.15),
                                      kCyan.withOpacity(0.05)
                                    ],
                                  ),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(kCyan),
                                    ),
                                  ),
                                ),
                              )
                            : NeonButton(
                                label: "SE CONNECTER",
                                icon: Icons.login,
                                onTap: _loginUser,
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Vos informations sont sécurisées",
                  style: TextStyle(color: kTextDim, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Pas encore de compte ? ",
                        style: TextStyle(color: kTextDim, fontSize: 13)),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const AuthScreen()),
                      ),
                      child: const Text("S'inscrire",
                          style: TextStyle(
                              color: kCyan,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
