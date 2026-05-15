String polishVoiceTranscriptText(
  String transcript, {
  VoiceVocabularyMemory? vocabularyMemory,
}) {
  var text = _normalizeReadableText(transcript);
  if (text.isEmpty) {
    return '';
  }

  text = _removeDictationTerminator(text);
  text = _removeLeadingFillers(text);
  text = _collapseEquivalentLeadingCommands(text);
  text = _removeRepeatedNonAdjacentPhrases(text);
  text = _collapseRepeatedTokenSequences(text);
  text = _removeShortDistanceRepeatedWords(text, vocabularyMemory);
  text = _removeStrayDateConnectors(text);
  text = _removeDanglingTimeConnectors(text);
  text = _applyVocabularyCasing(text, vocabularyMemory);
  return _capitalizeFirst(_normalizeReadableText(text));
}

String polishVoiceTitleText(
  String title, {
  VoiceVocabularyMemory? vocabularyMemory,
}) {
  var text = polishVoiceTranscriptText(
    title,
    vocabularyMemory: vocabularyMemory,
  );
  if (text.isEmpty) {
    return '';
  }

  text = _removeLooseLeadingConnectors(text);
  text = _removeRepeatedNonAdjacentPhrases(text);
  text = _collapseRepeatedTokenSequences(text);
  text = _removeShortDistanceRepeatedWords(text, vocabularyMemory);
  text = _removeStrayDateConnectors(text);
  text = _removeDanglingTimeConnectors(text);
  text = _applyVocabularyCasing(text, vocabularyMemory);
  return _capitalizeFirst(_normalizeReadableText(text));
}

String formatReadableReminderTitle(String title) {
  final polished = polishVoiceTitleText(title);
  if (polished.isEmpty) {
    return 'Recordatorio sin titulo';
  }

  if (_endsWithTerminalPunctuation(polished)) {
    return polished;
  }

  return '$polished.';
}

final class VoiceVocabularyMemory {
  VoiceVocabularyMemory._(this._wordsByKey);

  factory VoiceVocabularyMemory.fromTexts(Iterable<String> texts) {
    final wordsByKey = <String, _VocabularyWord>{};
    for (final text in texts) {
      final words = _normalizeReadableText(text).split(' ');
      for (final word in words) {
        final key = _normalizeToken(word);
        if (key.length < 3 || _stopWords.contains(key)) {
          continue;
        }

        final existingWord = wordsByKey[key];
        if (existingWord == null) {
          wordsByKey[key] = _VocabularyWord(word, 1);
        } else {
          wordsByKey[key] = existingWord.incrementedWith(word);
        }
      }
    }

    return VoiceVocabularyMemory._(wordsByKey);
  }

  static final VoiceVocabularyMemory empty = VoiceVocabularyMemory._(
    const <String, _VocabularyWord>{},
  );

  bool contains(String token) =>
      _wordsByKey.containsKey(_normalizeToken(token));

  String preferredWordFor(String token) {
    final key = _normalizeToken(token);
    return _wordsByKey[key]?.word ?? token;
  }

  final Map<String, _VocabularyWord> _wordsByKey;
}

final class _VocabularyWord {
  const _VocabularyWord(this.word, this.count);

  final String word;
  final int count;

  _VocabularyWord incrementedWith(String nextWord) {
    if (_looksBetterCased(nextWord, word)) {
      return _VocabularyWord(nextWord, count + 1);
    }
    return _VocabularyWord(word, count + 1);
  }
}

String _normalizeReadableText(String value) {
  return value
      .replaceAll(RegExp(r'[\"`´“”]'), ' ')
      .replaceAll(RegExp(r'[.,;:!?]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _removeDictationTerminator(String value) {
  return _normalizeReadableText(value.replaceFirst(_terminatorPattern, ''));
}

String _removeLeadingFillers(String value) {
  final withoutPolitePrefix = value.replaceFirst(
    RegExp(r'^(?:por\s+favor\s+)+', caseSensitive: false),
    '',
  );
  final tokens = withoutPolitePrefix.split(' ');
  while (tokens.isNotEmpty &&
      _leadingFillers.contains(_normalizeToken(tokens.first))) {
    tokens.removeAt(0);
  }

  return tokens
      .where((token) => !_noiseFillers.contains(_normalizeToken(token)))
      .join(' ');
}

String _collapseEquivalentLeadingCommands(String value) {
  final tokens = value.split(' ');
  while (tokens.length > 1 &&
      _voiceCommandWords.contains(_normalizeToken(tokens.first)) &&
      _voiceCommandWords.contains(_normalizeToken(tokens[1]))) {
    tokens.removeAt(1);
  }

  return tokens.join(' ');
}

String _removeLooseLeadingConnectors(String value) {
  final tokens = value.split(' ');
  while (tokens.isNotEmpty &&
      _looseLeadingConnectors.contains(_normalizeToken(tokens.first))) {
    tokens.removeAt(0);
  }

  return tokens.join(' ');
}

String _removeStrayDateConnectors(String value) {
  var text = value;
  text = text.replaceAllMapped(
    RegExp(
      r'\ba\s+(hoy|manana|pasado manana|lunes|martes|miercoles|jueves|viernes|sabado|domingo)\b',
      caseSensitive: false,
    ),
    (match) => match.group(1) ?? '',
  );
  return _normalizeReadableText(text);
}

String _removeDanglingTimeConnectors(String value) {
  return _normalizeReadableText(
    value.replaceFirst(
      RegExp(r'(?:\s+(?:de la|por la|en la))+$', caseSensitive: false),
      '',
    ),
  );
}

String _collapseRepeatedTokenSequences(String value) {
  var tokens = value
      .split(' ')
      .where((token) => token.trim().isNotEmpty)
      .toList();
  if (tokens.length < 2) {
    return value;
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

String _removeRepeatedNonAdjacentPhrases(String value) {
  var tokens = value
      .split(' ')
      .where((token) => token.trim().isNotEmpty)
      .toList();
  if (tokens.length < 4) {
    return value;
  }

  var changed = true;
  while (changed) {
    changed = false;
    final maxLength = tokens.length ~/ 2;
    final startLength = maxLength > 8 ? 8 : maxLength;

    for (var length = startLength; length >= 2; length--) {
      final seen = <String, int>{};
      var index = 0;
      while (index + length <= tokens.length) {
        final key = _sequenceKey(tokens, index, length);
        if (key.isEmpty) {
          index++;
          continue;
        }

        final previousIndex = seen[key];
        if (previousIndex != null && previousIndex + length <= index) {
          tokens.removeRange(index, index + length);
          changed = true;
          index = 0;
          seen.clear();
          continue;
        }

        seen[key] = index;
        index++;
      }
    }
  }

  return tokens.join(' ');
}

String _removeShortDistanceRepeatedWords(
  String value,
  VoiceVocabularyMemory? vocabularyMemory,
) {
  final tokens = value
      .split(' ')
      .where((token) => token.trim().isNotEmpty)
      .toList();
  if (tokens.length < 2) {
    return value;
  }

  final cleanedTokens = <String>[];
  for (final token in tokens) {
    final normalizedToken = _normalizeToken(token);
    if (normalizedToken.isEmpty) {
      continue;
    }

    final duplicateIndex = cleanedTokens.lastIndexWhere(
      (item) => _normalizeToken(item) == normalizedToken,
    );
    if (duplicateIndex != -1) {
      if (_stopWords.contains(normalizedToken) ||
          _weakPhraseBoundaryWords.contains(normalizedToken)) {
        cleanedTokens.add(token);
        continue;
      }

      final distance = cleanedTokens.length - duplicateIndex;
      final isLikelyDictationEcho =
          distance <= 3 ||
          (distance <= 6 && !_protectedRepeatedWords.contains(normalizedToken));
      if (isLikelyDictationEcho) {
        continue;
      }
    }

    cleanedTokens.add(_preferredVocabularyWord(token, vocabularyMemory));
  }

  return cleanedTokens.join(' ');
}

String _applyVocabularyCasing(
  String value,
  VoiceVocabularyMemory? vocabularyMemory,
) {
  if (vocabularyMemory == null) {
    return value;
  }

  final tokens = value.split(' ');
  return tokens
      .map((token) => _preferredVocabularyWord(token, vocabularyMemory))
      .join(' ');
}

String _preferredVocabularyWord(
  String token,
  VoiceVocabularyMemory? vocabularyMemory,
) {
  if (vocabularyMemory == null) {
    return token;
  }

  final normalizedToken = _normalizeToken(token);
  if (_wordsThatStayLowercase.contains(normalizedToken)) {
    return token.toLowerCase();
  }

  return vocabularyMemory.preferredWordFor(token);
}

String _sequenceKey(List<String> tokens, int start, int length) {
  final normalizedTokens = <String>[];
  for (var index = start; index < start + length; index++) {
    final token = _normalizeToken(tokens[index]);
    if (token.isEmpty || _weakPhraseBoundaryWords.contains(token)) {
      return '';
    }
    normalizedTokens.add(token);
  }

  if (normalizedTokens.every(_stopWords.contains)) {
    return '';
  }

  return normalizedTokens.join(' ');
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

String _capitalizeFirst(String value) {
  final text = _normalizeReadableText(value);
  if (text.isEmpty) {
    return '';
  }

  return '${text[0].toUpperCase()}${text.substring(1)}';
}

bool _endsWithTerminalPunctuation(String value) {
  return RegExp(r'[.!?]$').hasMatch(value.trim());
}

bool _looksBetterCased(String candidate, String current) {
  final candidateHasUppercase = RegExp(r'[A-Z]').hasMatch(candidate);
  final currentHasUppercase = RegExp(r'[A-Z]').hasMatch(current);
  if (candidateHasUppercase && !currentHasUppercase) {
    return true;
  }
  if (candidate.length > current.length && !currentHasUppercase) {
    return true;
  }
  return false;
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

final RegExp _terminatorPattern = RegExp(
  r'(?:^|\s)(?:[\u00bf\u00a1?!]|\u00c2[\u00bf\u00a1])*\s*(ok|okay|okei)\s*(?:[.!?,;:\u00bf\u00a1?!]|\u00c2[\u00bf\u00a1])*$',
  caseSensitive: false,
);

const Set<String> _leadingFillers = <String>{'bueno', 'vale', 'mira', 'oye'};

const Set<String> _noiseFillers = <String>{'eh', 'em', 'mmm', 'um'};

const Set<String> _voiceCommandWords = <String>{
  'recordarme',
  'recordame',
  'recuerdame',
  'acuerdame',
  'avisame',
  'agendame',
  'programame',
  'anotame',
  'apuntame',
  'recordatorio',
  'recordar',
};

const Set<String> _looseLeadingConnectors = <String>{
  'a',
  'al',
  'el',
  'la',
  'las',
  'los',
  'para',
  'por',
  'con',
  'que',
};

const Set<String> _protectedRepeatedWords = <String>{
  'dia',
  'dias',
  'semana',
  'semanas',
  'mes',
  'meses',
  'ano',
  'anos',
  'cada',
};

const Set<String> _wordsThatStayLowercase = <String>{
  'recordarme',
  'recordame',
  'recuerdame',
  'acuerdame',
  'avisame',
  'agendame',
  'programame',
  'anotame',
  'apuntame',
  'llamar',
  'comprar',
  'revisar',
  'pagar',
  'enviar',
  'recoger',
  'sacar',
  'hacer',
  'preparar',
  'llevar',
  'traer',
};

const Set<String> _weakPhraseBoundaryWords = <String>{
  'a',
  'al',
  'de',
  'del',
  'la',
  'las',
  'el',
  'los',
  'y',
  'o',
};

const Set<String> _stopWords = <String>{
  'a',
  'al',
  'de',
  'del',
  'la',
  'las',
  'el',
  'los',
  'un',
  'una',
  'unos',
  'unas',
  'y',
  'o',
  'que',
  'para',
  'por',
  'con',
  'sin',
  'en',
  'lo',
  'me',
  'mi',
  'mis',
  'tu',
  'tus',
};
