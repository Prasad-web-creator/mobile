/// Splits a block of explanatory text into readable points (one per sentence).
///
/// Built for LLM-written coverage reasons and quoted policy wording, so it:
/// - keeps section numbers and decimals together ("Section B.16", "7.5 dioptres"),
/// - never splits inside quoted policy text ('A sickness ... treatment.'),
/// - does not split after common abbreviations ("Rs.", "e.g.", "No."),
/// - honours existing line breaks and strips bullet markers already present.
List<String> splitIntoPoints(String text) {
  final points = <String>[];
  for (final rawLine in text.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim().replaceFirst(RegExp(r'^([-•*▪◦]|\d{1,2}[.)])\s+'), '').trim();
    if (line.isEmpty) continue;
    points.addAll(_splitSentences(line));
  }
  return points;
}

const _quotes = {"'", '"', '‘', '’', '“', '”'};
const _closers = {')', ']', "'", '"', '’', '”'};
const _abbreviations = {
  'e.g', 'i.e', 'eg', 'ie', 'etc', 'rs', 'inr', 'no', 'nos', 'dr', 'mr', 'mrs', 'ms', 'vs', 'approx',
  'sec', 'cl', 'art', 'fig', 'sr', 'jr', 'st', 'max', 'min', 'yr', 'yrs', 'mo', 'mos',
};

bool _isWordChar(String c) => RegExp(r'[A-Za-z0-9]').hasMatch(c);
bool _isTerminator(String c) => c == '.' || c == '!' || c == '?';

List<String> _splitSentences(String s) {
  final out = <String>[];
  var depth = 0; // nesting of quoted text
  var start = 0;
  var i = 0;

  // If a sentence ends at [end] (exclusive), split there and return the start
  // of the next sentence; otherwise return -1.
  int trySplit(int terminatorIndex, int end) {
    if (end >= s.length || s[end] != ' ') return -1;
    var next = end;
    while (next < s.length && s[next] == ' ') {
      next++;
    }
    if (next >= s.length) return -1;
    final n = s[next];
    final startsSentence = RegExp(r'[A-Z0-9(₹]').hasMatch(n) || _quotes.contains(n);
    if (!startsSentence) return -1;

    // Word right before the terminator, e.g. "Rs" in "Rs. 5,000".
    var w = terminatorIndex;
    while (w > 0 && s[w - 1] != ' ' && s[w - 1] != '(') {
      w--;
    }
    final word = s.substring(w, terminatorIndex).toLowerCase();
    if (s[terminatorIndex] == '.' &&
        (_abbreviations.contains(word) || RegExp(r'^[a-z]$').hasMatch(word))) {
      return -1;
    }

    final sentence = s.substring(start, end).trim();
    if (sentence.isNotEmpty) out.add(sentence);
    return next;
  }

  while (i < s.length) {
    final c = s[i];

    if (_quotes.contains(c)) {
      final prev = i > 0 ? s[i - 1] : ' ';
      final next = i + 1 < s.length ? s[i + 1] : ' ';
      final prevWord = _isWordChar(prev);
      final nextWord = _isWordChar(next);
      if (prevWord && nextWord) {
        i++; // apostrophe inside a word: policy's
        continue;
      }
      if (i == 0 || prev == ' ' || prev == '(' || prev == '[') {
        depth++; // opening quote
        i++;
        continue;
      }
      // Closing quote.
      if (depth > 0) depth--;
      if (depth == 0 && _isTerminator(prev)) {
        var end = i + 1;
        while (end < s.length && _closers.contains(s[end])) {
          end++;
        }
        final resume = trySplit(i - 1, end);
        if (resume >= 0) {
          start = resume;
          i = resume;
          continue;
        }
      }
      i++;
      continue;
    }

    if (_isTerminator(c) && depth == 0) {
      var end = i + 1;
      while (end < s.length && _closers.contains(s[end])) {
        end++;
      }
      final resume = trySplit(i, end);
      if (resume >= 0) {
        start = resume;
        i = resume;
        continue;
      }
    }
    i++;
  }

  final tail = s.substring(start).trim();
  if (tail.isNotEmpty) out.add(tail);
  return out;
}
