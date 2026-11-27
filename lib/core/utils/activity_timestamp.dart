import 'package:intl/intl.dart';

final _activityDate = DateFormat('d MMM yyyy', 'en_US');
final _activityTime = DateFormat('hh : mm a', 'en_US');
final _dateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Backend timestamps without a timezone are stored in UTC.
DateTime? parseActivityTimestamp(Object? raw) {
  final text = raw?.toString().trim() ?? '';
  final parsed = DateTime.tryParse(text);
  if (parsed == null || parsed.isUtc || _dateOnly.hasMatch(text)) return parsed;
  return DateTime.tryParse('${text}Z');
}

String formatActivityDate(DateTime date, {DateTime? now}) {
  final local = date.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  return local.year == today.year && local.month == today.month && local.day == today.day
      ? 'Today'
      : _activityDate.format(local);
}

String formatActivityTimestamp(DateTime timestamp, {DateTime? now}) {
  final local = timestamp.toLocal();
  return '${formatActivityDate(local, now: now)}   ${_activityTime.format(local)}';
}
