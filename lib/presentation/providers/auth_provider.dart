import 'package:flutter/material.dart';

enum UserType { student, company, admin }

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  UserType? _userType;
  String? _userId;
  String? _userName;

  bool get isAuthenticated => _isAuthenticated;
  UserType? get userType => _userType;
  String? get userId => _userId;
  String? get userName => _userName;

  // Mock login
  Future<bool> login(String email, String password, UserType type) async {
    // Simulamos un delay de red
    await Future.delayed(const Duration(seconds: 1));

    _isAuthenticated = true;
    _userType = type;
    _userId = '123456';
    _userName = type == UserType.student ? 'Alex Johnson' : 'TechCorp Inc.';

    notifyListeners();
    return true;
  }

  // Mock register
  Future<bool> register(Map<String, dynamic> userData, UserType type) async {
    await Future.delayed(const Duration(seconds: 1));

    _isAuthenticated = true;
    _userType = type;
    _userId = DateTime.now().millisecondsSinceEpoch.toString();
    _userName = userData['name'] ?? 'User';

    notifyListeners();
    return true;
  }

  void logout() {
    _isAuthenticated = false;
    _userType = null;
    _userId = null;
    _userName = null;
    notifyListeners();
  }
}