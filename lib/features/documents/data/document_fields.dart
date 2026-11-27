import 'package:intl/intl.dart';

String? documentText(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  const empty = {'', '-', 'unknown', 'not specified', 'n/a', 'null', 'none'};
  return empty.contains(text.toLowerCase()) ? null : text;
}

List<String> documentNames(Object? input, List<String> keys) {
  if (input is! List) return const [];
  final names = <String>[];
  for (final item in input) {
    final name = item is Map ? keys.map((key) => documentText(item[key])).nonNulls.firstOrNull : documentText(item);
    if (name != null) names.add(name);
  }
  return names;
}

Map<String, dynamic> documentMap(Object? value) => value is Map<String, dynamic> ? value : const {};

String? firstDocumentText(Iterable<Object?> values) => values.map(documentText).nonNulls.firstOrNull;

DateTime? firstDocumentDate(Iterable<Object?> values) => values.map(_documentDate).nonNulls.firstOrNull;

DateTime? _documentDate(Object? value) {
  if (value is DateTime) return value;
  final text = documentText(value);
  if (text == null) return null;
  final iso = DateTime.tryParse(text);
  if (iso != null) return iso;

  for (final pattern in [
    'd/M/yyyy',
    'd-M-yyyy',
    'yyyy/M/d',
    'd MMM yyyy',
    'd MMMM yyyy',
    'd-MMM-yyyy',
    'MMM d, yyyy',
    'MMMM d, yyyy',
  ]) {
    try {
      return DateFormat(pattern, 'en_US').parseStrict(text, true);
    } on FormatException {
      // Try the next document date format.
    }
  }
  return null;
}

double? firstDocumentAmount(Iterable<Object?> values) {
  for (final value in values) {
    final text = documentText(
      value,
    )?.replaceAll(RegExp(r'^(?:₹|INR|Rs\.?)\s*', caseSensitive: false), '').replaceAll(',', '');
    final number = value is num ? value.toDouble() : double.tryParse(text ?? '');
    if (number != null && number.isFinite && number > 0) return number;
  }
  return null;
}

bool? firstDocumentBoolean(Iterable<Object?> values) {
  for (final value in values) {
    if (value is bool) return value;
    switch (documentText(value)?.toLowerCase()) {
      case 'yes':
      case 'true':
        return true;
      case 'no':
      case 'false':
        return false;
    }
  }
  return null;
}
