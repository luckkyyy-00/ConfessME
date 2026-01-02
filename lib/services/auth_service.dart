import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _userIdKey = 'cached_user_id';

  /// Stream of user changes
  Stream<User?> get user => _auth.authStateChanges();

  /// Get current user ID (cached or from Firebase)
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? cachedId = prefs.getString(_userIdKey);

    if (cachedId != null) return cachedId;

    final user = _auth.currentUser;
    if (user != null) {
      await prefs.setString(_userIdKey, user.uid);
      return user.uid;
    }

    return null;
  }

  /// Sign in anonymously
  Future<UserCredential?> signInAnonymously() async {
    try {
      // If already signed in, return current user
      if (_auth.currentUser != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userIdKey, _auth.currentUser!.uid);
        return null; // Or return a mock credential if needed, but null is fine for our init
      }

      final credential = await _auth.signInAnonymously();
      if (credential.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userIdKey, credential.user!.uid);
      }
      return credential;
    } catch (e) {
      debugPrint('Error signing in anonymously: $e');
      return null;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
  }
}
