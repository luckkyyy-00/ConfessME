import 'package:cloud_firestore/cloud_firestore.dart';

class Report {
  final String id;
  final String confessionId;
  final String reporterId;
  final String reason;
  final DateTime timestamp;

  Report({
    required this.id,
    required this.confessionId,
    required this.reporterId,
    required this.reason,
    required this.timestamp,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'confessionId': confessionId,
      'reporterId': reporterId,
      'reason': reason,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory Report.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Report(
      id: doc.id,
      confessionId: data['confessionId'] ?? '',
      reporterId: data['reporterId'] ?? '',
      reason: data['reason'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }
}
