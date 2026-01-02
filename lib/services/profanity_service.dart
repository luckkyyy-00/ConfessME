import '../models/detection_result.dart';

class ProfanityService {
  static final ProfanityService _instance = ProfanityService._internal();
  factory ProfanityService() => _instance;
  ProfanityService._internal();

  /// Comprehensive lists of blocked patterns
  /// Using regex to handle common variations (wildcards, separators, repetitions)

  // 1. Hinglish / Hindi Abuse
  final List<String> _abuseHinglish = [
    r'ch[u]*t[i]*y[a]*',
    r'bkch[o]*d',
    r'mdrch[o]*d',
    r'b[h]*nch[o]*d',
    r'g[u]*nd',
    r'l[a]*v[a]*d[e]*',
    r'k[a]*m[i]*n[a]*',
    r'rnd[i]*',
    r'hrm[i]*',
    r's[a]*l[a]*',
    r'ttt', // Variation of tatti
    r'jh[u]*nt',
    r's[u]*r',
    r'hrmzd',
    r'k[u]*t[t]*',
    r'bhsd',
  ];

  // 2. English Swear Words
  final List<String> _abuseEnglish = [
    r'f[u]*ck',
    r'sh[i]*t',
    r'b[i]*tch',
    r'b[a]*st[a]*rd',
    r'a[s]*[s]*h[o]*le',
    r'd[i]*ck',
    r'p[u]*ssy',
    r'sl[u]*t',
    r'wh[o]*re',
    r'c[u]*nt',
  ];

  // 3. Sexual / Explicit
  final List<String> _explicit = [
    r's[e]x',
    r's[e]xual',
    r'p[o]rn',
    r'hndjb',
    r'blw[ ]*jb',
    r'f[u]ck[ ]*buddy',
    r'n[u]d[e]',
    r'n[a]k[e]d',
    r'r[a]pe',
  ];

  // 4. Bullying / Harassment
  final List<String> _bullying = [
    r'tu pagal hai',
    r'tu useless hai',
    r'mar ja',
    r'nobody likes you',
    r'kill yourself',
    r'you deserve pain',
    r'tu kuch nahi hai',
    r'tu failure hai',
  ];

  // 5. Hate Speech (Religion/Caste/Community)
  final List<String> _hateSpeech = [
    r'terrorist',
    r'anti[- ]*national',
    // Add common Indian caste/religious slurs here (omitted for safety in documentation, but included in implementation if provided)
  ];

  // 6. Self-Harm & Suicide
  final List<String> _selfHarm = [
    r'suicide',
    r'kill myself',
    r'marna chahta hoon',
    r'jeena nahi chahta',
    r'end my life',
    r'khudkhushi',
  ];

  DetectionResult checkContent(String text) {
    if (text.isEmpty) return DetectionResult(type: DetectionType.none);

    final originalText = text.toLowerCase();
    // Remove symbols and spaces for variation matching (e.g. "c-h-u-t-i-y-a" -> "chutiya")
    final normalizedText = originalText
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(' ', '');

    // Check Self-Harm (Highest Priority)
    for (final pattern in _selfHarm) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(originalText)) {
        return DetectionResult(
          type: DetectionType.selfHarm,
          matchingWord: pattern,
        );
      }
    }

    // Check Hate Speech
    for (final pattern in _hateSpeech) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(normalizedText) ||
          RegExp(pattern, caseSensitive: false).hasMatch(originalText)) {
        return DetectionResult(
          type: DetectionType.hateSpeech,
          matchingWord: pattern,
        );
      }
    }

    // Check Explicit
    for (final pattern in _explicit) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(normalizedText) ||
          RegExp(pattern, caseSensitive: false).hasMatch(originalText)) {
        return DetectionResult(
          type: DetectionType.explicit,
          matchingWord: pattern,
        );
      }
    }

    // Check Bullying
    for (final pattern in _bullying) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(originalText)) {
        return DetectionResult(
          type: DetectionType.bullying,
          matchingWord: pattern,
        );
      }
    }

    // Check Abuse (Hinglish + English)
    for (final pattern in [..._abuseHinglish, ..._abuseEnglish]) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(normalizedText) ||
          RegExp(pattern, caseSensitive: false).hasMatch(originalText)) {
        return DetectionResult(
          type: DetectionType.abuse,
          matchingWord: pattern,
        );
      }
    }

    return DetectionResult(type: DetectionType.none);
  }
}
