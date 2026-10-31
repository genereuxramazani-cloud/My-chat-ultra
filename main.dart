import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_localizations.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'services/theme_service.dart';
import 'services/locale_service.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/profile_service.dart';
import 'services/chat_alert_service.dart';

// Global ThemeProvider instance
final globalThemeProvider = ThemeProvider();
// Global ProfileService instance
final globalProfileService = ProfileService();
// Global LocaleProvider instance
final globalLocaleProvider = LocaleProvider();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await globalThemeProvider.load();
  await globalProfileService.load();
  await globalLocaleProvider.load();
  await ChatAlertService().init();
  if (kIsWeb) {
    // Skip WebRTC initialization on web
  }
  runApp(const MyChatUltra());
}

class MyChatUltra extends StatefulWidget {
  const MyChatUltra({super.key});

  @override
  State<MyChatUltra> createState() => _MyChatUltraState();
}

class _MyChatUltraState extends State<MyChatUltra> {
  late Future<Widget> _homeScreen;

  @override
  void initState() {
    super.initState();
    globalThemeProvider.addListener(_onThemeChanged);
    globalLocaleProvider.addListener(_onThemeChanged);
    _homeScreen = _checkUserSession();
  }

  Future<Widget> _checkUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userPhone = prefs.getString('user_phone');

      if (userPhone != null && userPhone.isNotEmpty) {
        return HomeScreen(userPhone: userPhone);
      }
    } catch (e) {
      debugPrint('Error checking user session: $e');
    }
    return const AuthScreen();
  }

  @override
  void dispose() {
    globalThemeProvider.removeListener(_onThemeChanged);
    globalLocaleProvider.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MY CHAT ULTRA',
      theme: buildAppTheme(
        primary: globalThemeProvider.current.primary,
        surface: globalThemeProvider.current.surface,
      ),
      locale: globalLocaleProvider.locale,
      supportedLocales: LocaleProvider.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routes: {
        '/auth': (_) => const AuthScreen(),
      },
      home: FutureBuilder<Widget>(
        future: _homeScreen,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: kBg,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: kCyan, width: 2),
                      ),
                      child: const Icon(Icons.bolt, size: 40, color: kCyan),
                    ),
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(color: kCyan),
                  ],
                ),
              ),
            );
          }
          return snapshot.data ?? const AuthScreen();
        },
      ),
    );
  }
}
