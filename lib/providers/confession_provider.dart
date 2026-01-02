import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:profanity_filter/profanity_filter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../models/confession.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/report_service.dart';
import '../services/notification_service.dart';

// Helper to avoid circular dependency if needed, but NotificationService is a singleton
T importService<T>() {
  if (T == NotificationService) return NotificationService() as T;
  throw Exception('Service not found');
}

class ConfessionProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  final ReportService _reportService = ReportService();
  final _profanityFilter = ProfanityFilter();

  List<Confession> _confessions = [];
  List<String> _hiddenConfessions = [];
  Map<String, String> _userReactions = {}; // confessionId -> reactionType
  bool _isLoading = true;

  List<Confession> get confessions => _confessions;
  Map<String, String> get userReactions => _userReactions;
  bool get isLoading => _isLoading;

  String? _currentUserId;
  String? get currentUserId => _currentUserId;

  // Location State
  String? _city;
  String? _state;
  String? _country;

  String? get city => _city;
  String? get state => _state;
  String? get country => _country;

  ConfessionProvider() {
    _initAsync();
  }

  Future<void> _initAsync() async {
    // 1. Detect/Load Location (Unawaited - Background)
    _initLocation();

    // 2. Load hidden confessions (Unawaited - Background)
    _reportService.getHiddenConfessions().then((hidden) {
      _hiddenConfessions = hidden;
      notifyListeners();
    });

    // 3. Sign in and Start Data Stream
    try {
      // Use cached ID if available to start stream immediately?
      // Actually, better to wait for auth state once but without blocking the whole app.
      _currentUserId = await _authService.getUserId();

      if (_currentUserId == null) {
        // Not even cached, sign in anonymously in background
        _authService.signInAnonymously().then((credential) {
          if (credential?.user != null) {
            _currentUserId = credential!.user!.uid;
            _startDataStreams();
          }
        });
      } else {
        _startDataStreams();
      }
    } catch (e) {
      debugPrint('Auth initialization failed: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startDataStreams() {
    if (_currentUserId != null) {
      // Listen to user's reactions
      FirebaseFirestore.instance
          .collection('reactions')
          .where('userId', isEqualTo: _currentUserId)
          .snapshots()
          .listen((snapshot) {
            _userReactions = {
              for (var doc in snapshot.docs)
                doc.data()['confessionId']: doc.data()['reactionType'],
            };
            notifyListeners();
          });
    }

    // Listen to confessions stream with current location (even if null for now)
    _dbService
        .getConfessions(city: _city, state: _state, country: _country)
        .listen(
          (allConfessions) {
            final now = DateTime.now();
            debugPrint(
              'Data loaded: ${now.difference(startTime).inMilliseconds}ms',
            );

            // Shuffle highlights for fairness (once per session/update)
            final highlights =
                allConfessions.where((c) => c.isHighlighted).toList()
                  ..shuffle();
            final normal = allConfessions
                .where((c) => !c.isHighlighted)
                .toList();

            _confessions = [
              ...highlights.take(3), // Keep max 3 highlights
              ...normal,
            ].where((c) => !_hiddenConfessions.contains(c.id)).toList();

            _isLoading = false;
            notifyListeners();

            // Trigger free notification check for reactions (Deferred)
            Future.microtask(() {
              importService<NotificationService>().checkReactionChanges(
                _confessions,
              );
            });
          },
          onError: (error) {
            debugPrint('Confession stream error: $error');
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  Future<void> _initLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdate = prefs.getInt('location_last_update') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Refresh every 24 hours
    if (now - lastUpdate < 24 * 60 * 60 * 1000) {
      _city = prefs.getString('location_city');
      _state = prefs.getString('location_state');
      _country = prefs.getString('location_country');
      if (_city != null) {
        debugPrint('Location loaded from cache: $_city');
        return;
      }
    }

    await _detectLocation(prefs);
  }

  Future<void> _detectLocation(SharedPreferences prefs) async {
    try {
      final response = await http
          .get(Uri.parse('http://ip-api.com/json'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          _city = data['city'];
          _state = data['regionName'];
          _country = data['country'];

          // Cache results
          await prefs.setString('location_city', _city!);
          await prefs.setString('location_state', _state!);
          await prefs.setString('location_country', _country!);
          await prefs.setInt(
            'location_last_update',
            DateTime.now().millisecondsSinceEpoch,
          );

          debugPrint(
            'Location detected and cached: $_city, $_state, $_country',
          );
        }
      }
    } catch (e) {
      // debugPrint('Location detection failed: $e');
    }
  }

  /// Normalizes text (lowercase, no spaces, no symbols) for profanity check
  bool _containsProfanity(String text) {
    // 1. Standard check
    if (_profanityFilter.hasProfanity(text)) return true;

    // 2. Normalized check (lowercase, remove spaces and symbols)
    final normalized = text.toLowerCase().replaceAll(
      RegExp(r'[\s\W_]+'),
      '',
    ); // Remove spaces, symbols, underscores

    return _profanityFilter.hasProfanity(normalized);
  }

  /// Check if user can post (10 min cooldown + 5 posts/day limit)
  Future<Map<String, dynamic>> canPost() async {
    if (_currentUserId == null) {
      return {'canPost': false, 'reason': 'Not authenticated'};
    }

    final userDoc = await _dbService.getUserData(_currentUserId!);
    if (userDoc == null || !userDoc.exists) return {'canPost': true};

    final data = userDoc.data() as Map<String, dynamic>;
    final lastPostTime = (data['lastPostTime'] as Timestamp?)?.toDate();
    final dailyPostCount = data['dailyPostCount'] ?? 0;

    // Check daily limit
    if (dailyPostCount >= 5) {
      return {
        'canPost': false,
        'reason': 'You\'ve shared enough for today. Come back tomorrow!',
      };
    }

    // Check 10-minute cooldown
    if (lastPostTime != null) {
      final difference = DateTime.now().difference(lastPostTime);
      if (difference.inMinutes < 10) {
        final remaining = 10 - difference.inMinutes;
        return {
          'canPost': false,
          'reason': 'Take a moment. You can post again in $remaining minutes.',
        };
      }
    }

    return {'canPost': true};
  }

  Future<Map<String, dynamic>> addConfession(
    String content,
    ConfessionCategory category, {
    bool isPaid = false,
  }) async {
    if (_currentUserId == null) {
      return {'success': false, 'reason': 'Not authenticated'};
    }

    // 1. Profanity check
    if (_containsProfanity(content)) {
      return {
        'success': false,
        'reason': 'Please avoid abusive language. This is a safe space.',
      };
    }

    // 2. Cooldown check
    final check = await canPost();
    if (check['canPost'] == false) {
      return {'success': false, 'reason': check['reason']};
    }

    // 3. Submit
    try {
      await _dbService.addConfession(
        content,
        category.toString().split('.').last,
        _currentUserId!,
        city: _city,
        state: _state,
        country: _country,
        isPaid: isPaid,
      );
      return {'success': true};
    } catch (e) {
      return {'success': false, 'reason': 'Failed to post: ${e.toString()}'};
    }
  }

  Future<void> reportConfession(String confessionId, String reason) async {
    if (_currentUserId == null) return;

    await _reportService.reportConfession(
      confessionId: confessionId,
      userId: _currentUserId!,
      reason: reason,
    );

    // Update local state immediately
    _hiddenConfessions.add(confessionId);
    _confessions.removeWhere((c) => c.id == confessionId);
    notifyListeners();
  }

  Future<void> react(String confessionId, String reactionType) async {
    if (_currentUserId == null) return;

    // 1. Optimistic Update
    final previousReaction = _userReactions[confessionId];
    final confessionIndex = _confessions.indexWhere(
      (c) => c.id == confessionId,
    );

    if (confessionIndex != -1) {
      final confession = _confessions[confessionIndex];
      final newCounts = Map<String, int>.from(confession.reactionCounts);

      // Update counts based on toggle logic
      if (previousReaction == null) {
        // New reaction
        newCounts[reactionType] = (newCounts[reactionType] ?? 0) + 1;
        _userReactions[confessionId] = reactionType;
      } else if (previousReaction == reactionType) {
        // Remove reaction
        newCounts[reactionType] = (newCounts[reactionType] ?? 0) - 1;
        _userReactions.remove(confessionId);
      } else {
        // Change reaction
        newCounts[previousReaction] = (newCounts[previousReaction] ?? 0) - 1;
        newCounts[reactionType] = (newCounts[reactionType] ?? 0) + 1;
        _userReactions[confessionId] = reactionType;
      }

      // Update confession in list
      _confessions[confessionIndex] = Confession(
        id: confession.id,
        content: confession.content,
        category: confession.category,
        createdAt: confession.createdAt,
        reactionCounts: newCounts,
        isTop: confession.isTop,
        isHighlighted: confession.isHighlighted,
        highlightEndTime: confession.highlightEndTime,
        city: confession.city,
        state: confession.state,
        country: confession.country,
        reportCount: confession.reportCount,
      );

      notifyListeners();
    }

    // 2. Call Database
    try {
      await _dbService.toggleReaction(
        confessionId,
        _currentUserId!,
        reactionType,
        previousReaction: previousReaction,
      );
    } catch (e, stackTrace) {
      // 3. Revert on Failure
      debugPrint('Reaction failed: $e');
      debugPrint('Stack trace: $stackTrace');
      if (confessionIndex != -1) {
        // Revert user reaction
        if (previousReaction == null) {
          _userReactions.remove(confessionId);
        } else {
          _userReactions[confessionId] = previousReaction;
        }

        // Revert confession counts (simply by reloading or undoing math,
        // but since we don't have the original object handy without extra storage,
        // we'll rely on the stream to eventually correct it, or we could store the old object.
        // For now, just reverting the user reaction map is the most critical part for UI consistency).
        notifyListeners();
      }
    }
  }

  Future<void> addPaidCredit(String productId, String purchaseToken) async {
    if (_currentUserId == null) return;
    await _dbService.addPaidConfessionCredit(
      _currentUserId!,
      productId,
      purchaseToken,
    );
    notifyListeners();
  }
}
