import 'package:intl/intl.dart';
import 'package:claimsupport/core/localization/localization.dart';
import 'package:claimsupport/core/localization/translation_mapper.dart';

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

String formatActivityDate(DateTime date, {DateTime? now, AppLocalizations? l10n}) {
  final local = date.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  return local.year == today.year && local.month == today.month && local.day == today.day
      ? (l10n?.sharedToday ?? 'Today')
      : l10n == null ? _activityDate.format(local) : formatLocalizedDate(l10n, local);
}

String formatActivityTimestamp(DateTime timestamp, {DateTime? now, AppLocalizations? l10n}) {
  final local = timestamp.toLocal();
  return '${formatActivityDate(local, now: now, l10n: l10n)}   ${l10n == null ? _activityTime.format(local) : formatLocalizedDate(l10n, local, pattern: 'hh : mm a')}';
}
