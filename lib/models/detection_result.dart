enum DetectionType { none, abuse, explicit, bullying, hateSpeech, selfHarm }

class DetectionResult {
  final DetectionType type;
  final String? matchingWord;

  DetectionResult({required this.type, this.matchingWord});

  bool get hasViolation => type != DetectionType.none;
}
