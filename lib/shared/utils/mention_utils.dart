import '../../core/debug/debug_config.dart';

class MentionService {
  static List<String> extractMentions(
    String text,
    Map<String, String> nicknames,
  ) {
    if (text.isEmpty || nicknames.isEmpty) return [];

    final result = <String>{};
    final uidByLowerNickname = <String, String>{};
    for (final entry in nicknames.entries) {
      uidByLowerNickname[entry.value.toLowerCase().trim()] = entry.key;
    }

    final regex = RegExp(r'(?<!\w)@(\S+)');
    final matches = regex.allMatches(text);

    for (final match in matches) {
      final raw = match.group(1)!;
      final candidate = raw.replaceAll(RegExp(r'[^\p{L}\p{N}]+$', unicode: true), '');
      if (candidate.isEmpty) continue;

      final uid = uidByLowerNickname[candidate.toLowerCase()];
      if (uid != null) {
        result.add(uid);
      }
    }

    final list = result.toList();
    if (list.isNotEmpty) {
      DebugConfig.log(DebugConfig.repositoryCall,
          'MentionService.extractMentions: found ${list.length} mentions');
    }
    return list;
  }

  static String formatForDisplay(String text) {
    return text;
  }

  static List<String> validateParticipants(
    List<String> mentionedUids,
    List<String> participantUids,
  ) {
    if (mentionedUids.isEmpty) return [];
    final participantSet = participantUids.toSet();
    final valid = mentionedUids.where((u) => participantSet.contains(u)).toList();

    if (valid.length != mentionedUids.length) {
      DebugConfig.warn(
        'MentionService.validateParticipants: ${mentionedUids.length - valid.length} invalid mentions filtered out',
      );
    }
    return valid;
  }
}
