/// Resolves saved excerpts and section citations against the report's policy text.
class PolicyEvidence {
  PolicyEvidence(String? source) : _source = source ?? '' {
    final normalized = StringBuffer();
    for (var index = 0; index < _source.length; index++) {
      final character = _asciiLower(_source.codeUnitAt(index));
      if (character == null) continue;
      normalized.writeCharCode(character);
      _offsets.add(index);
    }
    _normalized = normalized.toString();
  }

  final String _source;
  final _offsets = <int>[];
  late final String _normalized;
  static final _quoted = RegExp(r'“([^”]+)”|"([^"]+)"', dotAll: true);
  static final _closingPunctuation = RegExp(r'''[.,;:!?)\]”’"']+''');
  static const _sectionNumber = r'[A-Z][ \t]*\.[ \t]*\d+(?:[ \t]*\.[ \t]*\d+)*';
  static const _exclusionCode = r'Excl[ \t-]*\d+';
  static final _reference = RegExp('\\b(?:$_sectionNumber|$_exclusionCode)\\b', caseSensitive: false);
  static final _heading = RegExp(
    '^[ \\t]*(?:Section[ \\t]+)?($_sectionNumber)[.:)]?[ \\t]+(?=\\S)|^[ \\t]*--- PAGE \\d+ ---',
    caseSensitive: false,
    multiLine: true,
  );
  static final _exclusion = RegExp(_exclusionCode, caseSensitive: false);
  late final _sections = _readSections();

  List<Map<String, dynamic>> clausesFor(Map<String, dynamic> item) {
    final saved = item['policyClauses'];
    final result = <Map<String, dynamic>>[];
    final seen = <(String, String)>{};
    void add(Map<String, dynamic> clause, {required bool structured}) {
      final raw = clause['quote'];
      if (raw is! String || raw.trim().isEmpty) return;
      final wording = _find(raw) ?? (_source.trim().isEmpty && structured ? raw.trim() : null);
      if (wording == null) return;
      final section = clause['section']?.toString().trim() ?? '';
      if (seen.add((section, wording))) result.add({...clause, 'quote': wording});
    }

    if (saved is List) {
      for (final clause in saved.whereType<Map<String, dynamic>>()) {
        add(clause, structured: true);
      }
    }
    if (item['policyEvidence'] case final String evidence when result.isEmpty) {
      for (final match in _quoted.allMatches(evidence)) {
        add({'quote': match[1] ?? match[2]}, structured: false);
      }
      if (result.isEmpty) add({'quote': evidence}, structured: false);
    }
    if (result.isEmpty && _normalized.isNotEmpty) {
      final citations = [
        item['verificationClause'],
        item['policyEvidence'],
        item['coverageStatusReason'],
        item['explanation'],
        item['reason'],
        if (saved is List)
          for (final clause in saved.whereType<Map<String, dynamic>>()) clause['section'],
      ].whereType<String>().join('\n');
      for (final match in _reference.allMatches(citations)) {
        final reference = _referenceKey(match[0]!);
        final exact = _sections.where((section) => section.keys.contains(reference));
        final compact = reference.replaceAll('.', '');
        final matches = exact.isNotEmpty
            ? exact
            : _sections.where((section) => section.keys.any((key) => key.replaceAll('.', '') == compact));
        final section = matches.singleOrNull;
        if (section != null && seen.add((section.number, section.quote))) {
          result.add({'section': section.number, 'quote': section.quote});
        }
      }
    }
    return result;
  }

  List<({String number, String quote, Set<String> keys})> _readSections() {
    final headings = _heading.allMatches(_source).toList();
    return [
      for (final (index, heading) in headings.indexed)
        if (heading[1] case final number?)
          _readSection(number, heading.start, index + 1 < headings.length ? headings[index + 1].start : _source.length),
    ];
  }

  ({String number, String quote, Set<String> keys}) _readSection(String number, int start, int end) {
    const maxLength = 900;
    var quote = _source.substring(start, end).trim();
    if (quote.length > maxLength) {
      final prefix = quote.substring(0, maxLength);
      quote = prefix.substring(0, RegExp(r'\s').allMatches(prefix).lastOrNull?.start ?? maxLength).trimRight();
    }
    return (
      number: number,
      quote: quote,
      keys: {
        _referenceKey(number),
        for (final code in _exclusion.allMatches(quote.split('\n').first)) _referenceKey(code[0]!),
      },
    );
  }

  static String _referenceKey(String text) => text.toLowerCase().replaceAll(RegExp(r'[\s-]+'), '');

  String? _find(String quote) {
    if (_normalized.isEmpty) return null;
    final exact = quote.trim();
    if (_source.contains(exact)) return exact;
    final key = String.fromCharCodes(quote.codeUnits.map(_asciiLower).whereType<int>());
    if (key.length < 8) return null;
    final start = _normalized.indexOf(key);
    if (start < 0) return null;
    final end = _offsets[start + key.length - 1] + 1;
    final suffix = _closingPunctuation.matchAsPrefix(_source, end)?.end ?? end;
    return _source.substring(_offsets[start], suffix);
  }

  static int? _asciiLower(int unit) {
    if (unit >= 65 && unit <= 90) return unit + 32;
    if ((unit >= 97 && unit <= 122) || (unit >= 48 && unit <= 57)) return unit;
    return null;
  }
}
