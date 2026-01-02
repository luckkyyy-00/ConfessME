import 'package:profanity_filter/profanity_filter.dart';

class SafetyService {
  static final ProfanityFilter _filter = ProfanityFilter();

  /// Checks if the given text contains profanity.
  static bool hasProfanity(String text) {
    return _filter.hasProfanity(text);
  }

  /// Returns a list of profanity words found in the text.
  static List<String> getProfanityWords(String text) {
    return _filter.getAllProfanity(text);
  }

  /// Censors the given text by replacing profanity with asterisks.
  static String censorText(String text) {
    return _filter.censor(text);
  }

  /// Validates if the text is safe to post.
  /// Returns null if safe, or an error message if not.
  static String? validateContent(String text) {
    if (text.trim().isEmpty) {
      return 'Confession cannot be empty.';
    }
    if (text.length > 300) {
      return 'Confession is too long (max 300 characters).';
    }
    if (hasProfanity(text)) {
      return 'Your confession contains inappropriate language. Please keep it respectful.';
    }
    return null;
  }
}
