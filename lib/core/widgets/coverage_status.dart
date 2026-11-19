import 'package:flutter/material.dart';
import 'package:claimsupport/core/theme/app_tokens.dart';

/// Visual treatment (tone + icon) for a backend coverage status string.
///
/// This only maps the status text the backend already returned to a colour and
/// icon; it never changes or re-derives the status itself.
class CoverageStatusStyle {
  final AppTone tone;
  final IconData icon;

  const CoverageStatusStyle(this.tone, this.icon);
}

/// Returns the tone and icon for [status]. Unknown statuses use [fallback].
CoverageStatusStyle coverageStatusStyle(String? status, {AppTone fallback = AppTone.neutral}) {
  final s = (status ?? '').trim().toLowerCase();
  if (s.isEmpty) return CoverageStatusStyle(fallback, Icons.help_outline_rounded);
  if (s.startsWith('invalid')) {
    return const CoverageStatusStyle(AppTone.warning, Icons.error_outline_rounded);
  }
  if (s == 'needs verification') {
    return const CoverageStatusStyle(AppTone.verify, Icons.fact_check_outlined);
  }
  if (s.contains('not covered') || s == 'rejected') {
    return const CoverageStatusStyle(AppTone.danger, Icons.cancel_outlined);
  }
  if (s.contains('partial')) {
    return const CoverageStatusStyle(AppTone.warning, Icons.rule_rounded);
  }
  if (s.contains('review') || s.contains('pending') || s.contains('processing')) {
    return const CoverageStatusStyle(AppTone.warning, Icons.hourglass_top_rounded);
  }
  if (s == 'covered' || s == 'approved' || s == 'likely covered') {
    return const CoverageStatusStyle(AppTone.success, Icons.check_circle_outline_rounded);
  }
  return CoverageStatusStyle(fallback, fallback == AppTone.danger ? Icons.cancel_outlined : Icons.info_outline_rounded);
}
