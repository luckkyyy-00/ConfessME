import 'package:cloud_firestore/cloud_firestore.dart';

enum ConfessionCategory { love, regret, secret, fear }

class Confession {
  final String id;
  final String content;
  final ConfessionCategory category;
  final DateTime createdAt;
  final Map<String, int> reactionCounts;
  final bool isTop;
  final bool isHighlighted;
  final DateTime? highlightEndTime;
  final String? city;
  final String? state;
  final String? country;
  final int reportCount;

  Confession({
    required this.id,
    required this.content,
    required this.category,
    required this.createdAt,
    required this.reactionCounts,
    this.isTop = false,
    this.isHighlighted = false,
    this.highlightEndTime,
    this.city,
    this.state,
    this.country,
    this.reportCount = 0,
  });

  factory Confession.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Confession(
      id: doc.id,
      content: data['content'] ?? '',
      category: _parseCategory(data['category']),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      reactionCounts: Map<String, int>.from(data['reactionCounts'] ?? {}),
      isTop: data['isTop'] ?? false,
      isHighlighted: data['isHighlighted'] ?? false,
      highlightEndTime: (data['highlightEndTime'] as Timestamp?)?.toDate(),
      city: data['city'],
      state: data['state'],
      country: data['country'],
      reportCount: data['reportCount'] ?? 0,
    );
  }

  static ConfessionCategory _parseCategory(String? category) {
    switch (category) {
      case 'love':
        return ConfessionCategory.love;
      case 'regret':
        return ConfessionCategory.regret;
      case 'secret':
        return ConfessionCategory.secret;
      case 'fear':
        return ConfessionCategory.fear;
      default:
        return ConfessionCategory.secret;
    }
  }

  String get categoryString {
    return category.toString().split('.').last;
  }
}
