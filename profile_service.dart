import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileService extends ChangeNotifier {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  String? _phone;
  String? _name;
  String? _avatar;
  bool _onboarded = false;

  String? get phone => _phone;
  String? get name => _name;
  String? get avatar => _avatar;

  bool get isReady {
    return (_phone != null && _phone!.isNotEmpty) &&
        (_name != null && _name!.isNotEmpty);
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('SharedPreferences timeout'),
      );
      _phone = prefs.getString('user_phone') ?? '';
      _name = prefs.getString('user_name') ?? '';
      _avatar = prefs.getString('user_avatar');
      _onboarded = prefs.getBool('user_onboarded') ?? false;
    } catch (e) {
      debugPrint('ProfileService.load() error: $e');
      // Set safe defaults - app can continue
      _phone = '';
      _name = '';
      _avatar = null;
      _onboarded = false;
    }
    notifyListeners();
  }

  Future<void> save(
      {required String phone, required String name, String? avatar}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_phone', phone);
    await prefs.setString('user_name', name);
    await prefs.setBool('user_onboarded', true);
    if (avatar != null) await prefs.setString('user_avatar', avatar);
    _phone = phone;
    _name = name;
    _onboarded = true;
    if (avatar != null) _avatar = avatar;
    notifyListeners();
  }

  Future<void> savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_pin', pin);
    notifyListeners();
  }

  Future<void> saveAvatar(String avatarUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_avatar', avatarUrl);
    _avatar = avatarUrl;
    notifyListeners();
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_phone');
    await prefs.remove('user_name');
    await prefs.remove('user_pin');
    await prefs.remove('user_avatar');
    await prefs.remove('user_onboarded');
    _phone = null;
    _name = null;
    _avatar = null;
    notifyListeners();
  }

  bool get onboarded => _onboarded;
}
