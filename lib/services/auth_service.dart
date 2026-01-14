import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'database_helper.dart';

class AuthService {
  static const String _currentUserIdKey = 'current_user_id';
  static const String _isLoggedInKey = 'is_logged_in';

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }
  String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password cannot be empty';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null; // Password is valid
  }
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      if (name.trim().isEmpty) {
        return {'success': false, 'message': 'Name cannot be empty'};
      }

      if (!isValidEmail(email)) {
        return {'success': false, 'message': 'Invalid email format'};
      }

      final passwordError = validatePassword(password);
      if (passwordError != null) {
        return {'success': false, 'message': passwordError};
      }
      final existingUser = await _dbHelper.getUserByEmail(email.trim());
      if (existingUser != null) {
        return {'success': false, 'message': 'Email already registered'};
      }
      final user = User(
        name: name.trim(),
        email: email.trim().toLowerCase(),
        passwordHash: _hashPassword(password),
        createdAt: DateTime.now(),
      );

      final userId = await _dbHelper.createUser(user);

      return {
        'success': true,
        'message': 'Registration successful',
        'userId': userId,
      };
    } catch (e) {
      return {'success': false, 'message': 'Registration failed: $e'};
    }
  }
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      if (!isValidEmail(email)) {
        return {'success': false, 'message': 'Invalid email format'};
      }

      if (password.isEmpty) {
        return {'success': false, 'message': 'Password cannot be empty'};
      }
      final user = await _dbHelper.getUserByEmail(email.trim().toLowerCase());
      if (user == null) {
        return {'success': false, 'message': 'Invalid email or password'};
      }
      final hashedPassword = _hashPassword(password);
      if (user.passwordHash != hashedPassword) {
        return {'success': false, 'message': 'Invalid email or password'};
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_currentUserIdKey, user.id!);
      await prefs.setBool(_isLoggedInKey, true);

      return {
        'success': true,
        'message': 'Login successful',
        'user': user,
      };
    } catch (e) {
      return {'success': false, 'message': 'Login failed: $e'};
    }
  }
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserIdKey);
    await prefs.setBool(_isLoggedInKey, false);
  }
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }
  Future<int?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_currentUserIdKey);
  }
  Future<User?> getCurrentUser() async {
    final userId = await getCurrentUserId();
    if (userId == null) return null;

    return await _dbHelper.getUserById(userId);
  }
}
