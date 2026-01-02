import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportService {
  static const String _hiddenConfessionsKey = 'hidden_confessions';

  /// Reports a confession via secure Cloud Function
  Future<void> reportConfession({
    required String confessionId,
    required String userId,
    required String reason,
  }) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'submitReport',
      );

      final result = await callable.call({
        'confessionId': confessionId,
        'reason': reason,
      });

      if (result.data['success'] != true) {
        throw Exception('Server-side report failed');
      }

      debugPrint('Report submitted successfully via Cloud Function');
    } catch (e) {
      debugPrint('Error reporting confession: $e');
      rethrow;
    }

    // 3. Hide locally
    await hideLocally(confessionId);
  }

  /// Saves a confession ID to local storage to hide it from the feed.
  Future<void> hideLocally(String confessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> hidden =
        prefs.getStringList(_hiddenConfessionsKey) ?? [];
    if (!hidden.contains(confessionId)) {
      hidden.add(confessionId);
      await prefs.setStringList(_hiddenConfessionsKey, hidden);
    }
  }

  /// Retrieves the list of locally hidden confession IDs.
  Future<List<String>> getHiddenConfessions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_hiddenConfessionsKey) ?? [];
  }
}
