import 'package:claimsupport/core/localization/localization.dart';
import 'package:flutter/material.dart';

String reportLanguage(Object? value) => value == 'ta' ? 'ta' : 'en';

bool hasTamilText(String value) => RegExp(r'[\u0B80-\u0BFF]').hasMatch(value);

String? reportNarrative(
  AppLocalizations l10n,
  String language,
  Object? source, [
  Object? translation,
]) {
  final original = source?.toString().trim() ?? '';
  final localized = translation?.toString().trim() ?? '';
  if (language != l10n.localeName) return original.isEmpty ? null : original;
  if (localized.isNotEmpty && (language == 'en' || hasTamilText(localized)))
    return localized;
  if (original.isEmpty) return null;
  if (hasTamilText(original) != (language == 'ta'))
    return l10n.analysisDetailTranslationUnavailable;
  return original;
}

String reportItemName(AppLocalizations l10n, String language, Map item) {
  final original = item['displayName'] ?? item['item'];
  final type = item['itemType']?.toString().trim().toLowerCase();
  if (const {'diagnosis', 'medicine', 'medication', 'drug'}.contains(type)) {
    final name = (item['item'] ?? original)?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
  }
  return reportNarrative(l10n, language, original, item['localizedItem']) ??
      l10n.analysisTreatmentItem;
}

String reportLanguageName(AppLocalizations l10n, String language) =>
    language == 'ta'
    ? l10n.analysisTamilLanguage
    : l10n.analysisEnglishLanguage;

String localizedClauseEffect(AppLocalizations l10n, String effect) {
  if (l10n.localeName != 'ta') return effect;
  return switch (effect.trim().toLowerCase().replaceAll('_', ' ')) {
    'excludes' => l10n.analysisClauseExcludes,
    'waiting period' => l10n.analysisClauseWaiting,
    'condition' => l10n.analysisClauseCondition,
    'limit' => l10n.analysisClauseLimit,
    'covers' => l10n.analysisClauseCovers,
    _ => l10n.analysisClauseOther,
  };
}

class LocalizedPolicyWording extends StatelessWidget {
  const LocalizedPolicyWording({
    super.key,
    required this.original,
    this.translation,
    this.style,
  });

  final String original;
  final String? translation;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final translated = translation?.trim() ?? '';
    final sourceMatchesLocale = l10n.localeName == 'ta'
        ? hasTamilText(original)
        : !hasTamilText(original);
    if (translated.isEmpty && sourceMatchesLocale) {
      return SelectableText(original, style: style);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (translated.isEmpty)
          Text(l10n.analysisTranslationUnavailable, style: style)
        else ...[
          Text(
            l10n.analysisTranslatedWording,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          SelectableText(translated, style: style),
        ],
        Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            title: Text(l10n.analysisViewOriginalWording),
            children: [SelectableText(original, style: style)],
          ),
        ),
      ],
    );
  }
}
