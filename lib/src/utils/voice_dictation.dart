String mergeVoiceDictationTranscript(String existing, String incoming) {
  final current = _normalizeSpaces(existing);
  final next = _normalizeSpaces(incoming);

  if (current.isEmpty) {
    return _collapseRepeatedDictationText(next);
  }
  if (next.isEmpty) {
    return _collapseRepeatedDictationText(current);
  }

  final currentLower = current.toLowerCase();
  final nextLower = next.toLowerCase();

  if (currentLower == nextLower || currentLower.endsWith(nextLower)) {
    return _collapseRepeatedDictationText(current);
  }
  if (nextLower.startsWith(currentLower) || nextLower.contains(currentLower)) {
    return _collapseRepeatedDictationText(next);
  }

  final currentTokens = current.split(' ');
  final nextTokens = next.split(' ');
  final overlapLength = _longestTokenOverlap(currentTokens, nextTokens);
  final mergedTokens = <String>[
    ...currentTokens,
    ...nextTokens.skip(overlapLength),
  ];

  return _collapseRepeatedDictationText(mergedTokens.join(' '));
}

bool hasVoiceDictationTerminator(String transcript) {
  final normalized = _normalizeSpaces(transcript);
  if (normalized.isEmpty) {
    return false;
  }

  return _terminatorPattern.hasMatch(normalized);
}

String sanitizeVoiceDictationTranscript(String transcript) {
  final normalized = _normalizeSpaces(transcript);
  if (normalized.isEmpty) {
    return '';
  }

  return _normalizeSpaces(normalized.replaceFirst(_terminatorPattern, ''));
}

final RegExp _terminatorPattern = RegExp(
  r'(?:^|\s)(?:[\u00bf\u00a1?!]|\u00c2[\u00bf\u00a1])*\s*(ok|okay|okei)\s*(?:[.!?,;:\u00bf\u00a1?!]|\u00c2[\u00bf\u00a1])*$',
  caseSensitive: false,
);

String _normalizeSpaces(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

int _longestTokenOverlap(List<String> currentTokens, List<String> nextTokens) {
  final maxOverlap = currentTokens.length < nextTokens.length
      ? currentTokens.length
      : nextTokens.length;

  for (var length = maxOverlap; length >= 1; length--) {
    var matches = true;
    for (var offset = 0; offset < length; offset++) {
      final currentToken = _normalizeToken(
        currentTokens[currentTokens.length - length + offset],
      );
      final nextToken = _normalizeToken(nextTokens[offset]);
      if (currentToken.isEmpty || currentToken != nextToken) {
        matches = false;
        break;
      }
    }
    if (matches) {
      return length;
    }
  }

  return 0;
}

String _collapseRepeatedDictationText(String value) {
  var tokens = _normalizeSpaces(
    value,
  ).split(' ').where((token) => token.trim().isNotEmpty).toList();
  if (tokens.length < 2) {
    return tokens.join(' ');
  }

  var changed = true;
  while (changed) {
    changed = false;
    final maxSequenceLength = tokens.length ~/ 2;
    final startLength = maxSequenceLength > 6 ? 6 : maxSequenceLength;
    for (var length = startLength; length >= 1; length--) {
      var index = 0;
      while (index + (length * 2) <= tokens.length) {
        if (_sameTokenSequence(tokens, index, index + length, length)) {
          tokens.removeRange(index + length, index + (length * 2));
          changed = true;
        } else {
          index++;
        }
      }
    }
  }

  return tokens.join(' ');
}

bool _sameTokenSequence(
  List<String> tokens,
  int firstStart,
  int secondStart,
  int length,
) {
  for (var offset = 0; offset < length; offset++) {
    final firstToken = _normalizeToken(tokens[firstStart + offset]);
    final secondToken = _normalizeToken(tokens[secondStart + offset]);
    if (firstToken.isEmpty || firstToken != secondToken) {
      return false;
    }
  }

  return true;
}

String _normalizeToken(String token) {
  const replacements = <String, String>{
    '\u00e1': 'a',
    '\u00e0': 'a',
    '\u00e4': 'a',
    '\u00e9': 'e',
    '\u00e8': 'e',
    '\u00eb': 'e',
    '\u00ed': 'i',
    '\u00ec': 'i',
    '\u00ef': 'i',
    '\u00f3': 'o',
    '\u00f2': 'o',
    '\u00f6': 'o',
    '\u00fa': 'u',
    '\u00f9': 'u',
    '\u00fc': 'u',
    '\u00f1': 'n',
  };

  var normalized = token.toLowerCase();
  replacements.forEach((from, to) {
    normalized = normalized.replaceAll(from, to);
  });
  return normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '');
}
