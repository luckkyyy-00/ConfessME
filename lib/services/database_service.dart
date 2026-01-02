import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/confession.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetch all confessions and handle filtering/sorting client-side for robustness
  Stream<List<Confession>> getConfessions({
    String? city,
    String? state,
    String? country,
  }) {
    return _db
        .collection('confessions')
        .orderBy('createdAt', descending: true)
        .limit(100) // Limit for performance
        .snapshots()
        .map((snapshot) {
          final all = snapshot.docs
              .map((doc) => Confession.fromFirestore(doc))
              .toList();

          final now = DateTime.now();

          // 1. Separate Highlights and Normal
          final highlights = all
              .where(
                (c) =>
                    c.isHighlighted &&
                    c.highlightEndTime != null &&
                    c.highlightEndTime!.isAfter(now) &&
                    c.reportCount <
                        15, // Rule: Remove from highlights if reports >= 15
              )
              .toList();

          // Rule: Normal feed includes everything else (even reported highlights)
          // We do NOT filter normal posts by report count here.
          // Local hiding for the reporter is handled in ConfessionProvider.
          final normal = all.where((c) => !highlights.contains(c)).toList();

          // 2. Sort Highlights (City -> State -> Country -> Global)
          highlights.sort((a, b) {
            if (city != null) {
              bool aCity = a.city == city;
              bool bCity = b.city == city;
              if (aCity && !bCity) return -1;
              if (!aCity && bCity) return 1;
            }
            if (state != null) {
              bool aState = a.state == state;
              bool bState = b.state == state;
              if (aState && !bState) return -1;
              if (!aState && bState) return 1;
            }
            if (country != null) {
              bool aCountry = a.country == country;
              bool bCountry = b.country == country;
              if (aCountry && !bCountry) return -1;
              if (!aCountry && bCountry) return 1;
            }
            return b.createdAt.compareTo(a.createdAt);
          });

          // 3. Combine (Highlights first, then normal)
          return [...highlights, ...normal];
        });
  }

  /// Call Cloud Function to verify purchase and highlight confession
  Future<void> verifyAndHighlight(
    String confessionId,
    String productId,
    String purchaseToken,
  ) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'verifyPurchase',
      );

      final result = await callable.call({
        'confessionId': confessionId,
        'productId': productId,
        'purchaseToken': purchaseToken,
      });

      if (result.data['success'] != true) {
        throw Exception('Server-side verification failed');
      }

      debugPrint('Confession highlighted successfully via Cloud Function');
    } catch (e) {
      debugPrint('Error highlighting confession: $e');
      throw Exception('Failed to highlight confession: $e');
    }
  }

  /// Add a new confession via secure Cloud Function (with Client-Side Fallback)
  Future<void> addConfession(
    String content,
    String category,
    String userId, {
    String? city,
    String? state,
    String? country,
    bool isPaid = false,
  }) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'submitConfession',
      );

      final result = await callable.call({
        'content': content,
        'category': category,
        'city': city,
        'state': state,
        'country': country,
        'isPaid': isPaid,
      });

      if (result.data['success'] != true) {
        throw Exception('Server-side submission failed');
      }
    } catch (e) {
      debugPrint('Cloud Function failed, falling back to direct write: $e');

      // FALLBACK: Direct Firestore Write
      // This allows the app to work even if Cloud Functions are not deployed.
      final batch = _db.batch();
      final confessionRef = _db.collection('confessions').doc();

      batch.set(confessionRef, {
        'content': content,
        'category': category,
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'reactionCounts': {'❤️': 0, '😢': 0, '😮': 0, '🔥': 0},
        'isTop': false,
        'isHighlighted': false,
        'highlightEndTime': null,
        'city': city,
        'state': state,
        'country': country,
        'reportCount': 0,
        'isPaid': isPaid,
      });

      // Update user stats (Simple client-side logic)
      if (isPaid) {
        batch.update(_db.collection('users').doc(userId), {
          'paidConfessionCredits': FieldValue.increment(-1),
        });
      } else {
        batch.set(_db.collection('users').doc(userId), {
          'lastPostTime': FieldValue.serverTimestamp(),
          'dailyPostCount': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }

      await batch.commit();
    }
  }

  /// Toggle reaction using hybrid model (Cloud Function -> Transaction Fallback)
  /// Ensures strict one-reaction-per-user consistency.
  Future<void> toggleReaction(
    String confessionId,
    String userId,
    String reactionType, {
    String? previousReaction,
  }) async {
    // 1. Direct Client-Side Update (No Cloud Function)
    // This ensures immediate UI consistency and avoids server-side race conditions.

    final reactionId = '${confessionId}_$userId';
    final reactionRef = _db.collection('reactions').doc(reactionId);
    final confessionRef = _db.collection('confessions').doc(confessionId);

    // Optimistic Check or Fetch
    String? oldType = previousReaction;
    bool exists = previousReaction != null;

    if (previousReaction == null) {
      // Only fetch if we didn't pass state
      try {
        final reactionSnap = await reactionRef.get();
        if (reactionSnap.exists) {
          oldType = reactionSnap.data()!['reactionType'];
          exists = true;
        }
      } catch (e) {
        debugPrint('Error fetching reaction state: $e');
        // Assume no reaction if fetch fails
      }
    }

    final batch = _db.batch();

    if (!exists) {
      // 1. ADD: User has no reaction yet
      // Use set(merge: true) to be safe against race conditions where doc might exist but be empty/broken
      batch.set(reactionRef, {
        'confessionId': confessionId,
        'userId': userId,
        'reactionType': reactionType,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.update(confessionRef, {
        'reactionCounts.$reactionType': FieldValue.increment(1),
      });
    } else {
      if (oldType == reactionType) {
        // 2. REMOVE: User tapped the same reaction again
        batch.delete(reactionRef);
        batch.update(confessionRef, {
          'reactionCounts.$reactionType': FieldValue.increment(-1),
        });
      } else {
        // 3. SWITCH: User changed reaction (e.g., Heart -> Fire)
        // Use set(merge: true) to handle cases where the document might be missing (server-client desync)
        batch.set(reactionRef, {
          'reactionType': reactionType,
        }, SetOptions(merge: true));
        batch.update(confessionRef, {
          'reactionCounts.$oldType': FieldValue.increment(-1),
          'reactionCounts.$reactionType': FieldValue.increment(1),
        });
      }
    }

    await batch.commit();
  }

  /// Get user data (lastPostTime, dailyPostCount)
  Future<DocumentSnapshot?> getUserData(String userId) async {
    try {
      return await _db.collection('users').doc(userId).get();
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }

  /// Reset daily post count (should be called via Cloud Function or logic)
  Future<void> resetDailyCount(String userId) async {
    try {
      await _db.collection('users').doc(userId).update({'dailyPostCount': 0});
    } catch (e) {
      debugPrint('Error resetting daily count: $e');
    }
  }

  /// Add paid confession credit to user (Verified via Cloud Function)
  Future<void> addPaidConfessionCredit(
    String userId,
    String productId,
    String purchaseToken,
  ) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'verifyPurchase',
      );

      await callable.call({
        'productId': productId,
        'purchaseToken': purchaseToken,
      });

      debugPrint('Paid confession credit added via Cloud Function for $userId');
    } catch (e) {
      debugPrint('Error adding paid confession credit: $e');
      rethrow;
    }
  }
}
