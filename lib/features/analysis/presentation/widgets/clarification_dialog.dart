// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';
import 'dart:developer' as developer;

// ─── Individual Question Widgets ────────────────────────────────────────────
// Each question is its own StatefulWidget so that setState() only
// rebuilds the ONE question card that changed, not the entire dialog.

class _SingleChoiceQuestion extends StatefulWidget {
  final Map<String, dynamic> question;
  final String? currentValue;
  final ValueChanged<String?> onChanged;

  const _SingleChoiceQuestion({super.key, required this.question, required this.currentValue, required this.onChanged});

  @override
  State<_SingleChoiceQuestion> createState() => _SingleChoiceQuestionState();
}

class _SingleChoiceQuestionState extends State<_SingleChoiceQuestion> {
  String? _selected;
  late final TextEditingController _customInputController;
  DateTime? _pickedDate;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentValue;
    _customInputController = TextEditingController();
  }

  @override
  void dispose() {
    _customInputController.dispose();
    super.dispose();
  }

  /// A date already written into the option, e.g. "Use my entered date (01-11-2022)".
  static final RegExp _concreteDate = RegExp(
    r'\b\d{1,2}[-/ .](\d{1,2}|[A-Za-z]{3,9})[-/ .]\d{2,4}\b|\b\d{4}-\d{1,2}-\d{1,2}\b',
  );

  /// Whole-word prompts for free input ("Enter date", "Other", "Specify"); words like
  /// "entered" or "otherwise" do not count.
  static final RegExp _inputPrompt = RegExp(
    r'\b(enter|select|specify|other)\b|specific past date',
    caseSensitive: false,
  );

  bool _isOptionRequiringInput(String optStr) {
    // An option that already names its date is a fixed choice, not a prompt for a date.
    if (_concreteDate.hasMatch(optStr)) return false;
    return _inputPrompt.hasMatch(optStr);
  }

  bool _isDateContext(String optStr) {
    final q = widget.question;
    final id = (q['id'] ?? '').toString().toLowerCase();
    final title = (q['title'] ?? '').toString().toLowerCase();
    final qText = (q['question'] ?? '').toString().toLowerCase();
    final optLower = optStr.toLowerCase();

    return id.contains('date') || title.contains('date') || qText.contains('date') || optLower.contains('date');
  }

  Future<void> _pickDateForOption(String optStr) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickedDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      final formatted = DateFormat('dd-MMM-yyyy').format(picked);
      setState(() {
        _pickedDate = picked;
        _customInputController.text = formatted;
      });
      widget.onChanged(formatted);
      developer.log('[Clarification] Picked date: $formatted for question ${widget.question['id']}');
    }
  }

  void _handleOptionSelection(String optStr) {
    setState(() => _selected = optStr);
    if (_isOptionRequiringInput(optStr)) {
      if (_isDateContext(optStr)) {
        if (_customInputController.text.isNotEmpty) {
          widget.onChanged(_customInputController.text);
        } else {
          widget.onChanged(optStr);
          _pickDateForOption(optStr);
        }
      } else {
        widget.onChanged(_customInputController.text.isNotEmpty ? "$optStr: ${_customInputController.text}" : optStr);
      }
    } else {
      widget.onChanged(optStr);
    }
    developer.log('[Clarification] Single choice selected: $optStr for question ${widget.question['id']}');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final options = List<dynamic>.from(widget.question['options'] ?? []);

    if (options.isEmpty) {
      return _TextInputWidget(question: widget.question, onChanged: (val) => widget.onChanged(val));
    }

    return Column(
      children: options.map((opt) {
        final optStr = opt.toString();
        final isSelected = _selected == optStr;
        final requiresInput = _isOptionRequiringInput(optStr);
        final isDate = _isDateContext(optStr);

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: _OptionTile(
            selected: isSelected,
            onTap: () => _handleOptionSelection(optStr),
            indicator: Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: isSelected ? p.primary : p.borderStrong,
            ),
            label: optStr,
            mutuallyExclusive: true,
            footer: (isSelected && requiresInput)
                ? (isDate
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _pickDateForOption(optStr),
                              icon: Icon(Icons.calendar_month_rounded, size: 18, color: p.primary),
                              label: Text(
                                _pickedDate != null
                                    ? DateFormat('dd-MMM-yyyy').format(_pickedDate!)
                                    : 'Select Date from Calendar',
                              ),
                              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            TextFormField(
                              controller: _customInputController,
                              decoration: InputDecoration(
                                hintText: 'Or enter date (e.g. 15-Feb-2026)',
                                isDense: true,
                                prefixIcon: Icon(Icons.edit_calendar_rounded, size: 18, color: p.primary),
                                suffixIcon: IconButton(
                                  tooltip: 'Open calendar',
                                  icon: Icon(Icons.calendar_month_rounded, size: 18, color: p.primary),
                                  onPressed: () => _pickDateForOption(optStr),
                                ),
                              ),
                              onChanged: (val) {
                                widget.onChanged(val.trim().isEmpty ? null : val.trim());
                              },
                            ),
                          ],
                        )
                      : TextFormField(
                          controller: _customInputController,
                          decoration: const InputDecoration(hintText: 'Please specify details...', isDense: true),
                          onChanged: (val) {
                            widget.onChanged(val.trim().isEmpty ? null : "$optStr: ${val.trim()}");
                          },
                        ))
                : null,
          ),
        );
      }).toList(),
    );
  }
}

/// Selectable answer tile used by single- and multi-choice questions.
class _OptionTile extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget indicator;
  final String label;
  final Widget? footer;
  final bool mutuallyExclusive;

  const _OptionTile({
    required this.selected,
    required this.onTap,
    required this.indicator,
    required this.label,
    this.footer,
    this.mutuallyExclusive = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      checked: selected,
      inMutuallyExclusiveGroup: mutuallyExclusive,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mdAll,
          child: Ink(
            decoration: BoxDecoration(
              color: selected ? p.primarySoft : p.surface,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: selected ? p.primary : p.border, width: selected ? 1.5 : 1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(padding: const EdgeInsets.only(top: 1), child: indicator),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          label,
                          style: context.text.bodyMedium?.copyWith(
                            color: p.textPrimary,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (footer != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Padding(padding: const EdgeInsets.only(left: 34), child: footer),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MultiChoiceQuestion extends StatefulWidget {
  final Map<String, dynamic> question;
  final List<String> currentValues;
  final ValueChanged<List<String>> onChanged;

  const _MultiChoiceQuestion({super.key, required this.question, required this.currentValues, required this.onChanged});

  @override
  State<_MultiChoiceQuestion> createState() => _MultiChoiceQuestionState();
}

class _MultiChoiceQuestionState extends State<_MultiChoiceQuestion> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.currentValues);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final options = List<dynamic>.from(widget.question['options'] ?? []);

    if (options.isEmpty) {
      return _TextInputWidget(
        question: widget.question,
        onChanged: (val) => widget.onChanged(val != null ? [val] : []),
      );
    }

    return Column(
      children: options.map((opt) {
        final optStr = opt.toString();
        final isSelected = _selected.contains(optStr);
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: _OptionTile(
            selected: isSelected,
            label: optStr,
            indicator: Icon(
              isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              size: 22,
              color: isSelected ? p.primary : p.borderStrong,
            ),
            onTap: () {
              setState(() {
                if (!isSelected) {
                  _selected.add(optStr);
                } else {
                  _selected.remove(optStr);
                }
              });
              widget.onChanged(List<String>.from(_selected));
              developer.log('[Clarification] Multi-choice updated: $_selected for question ${widget.question['id']}');
            },
          ),
        );
      }).toList(),
    );
  }
}

class _BooleanQuestion extends StatefulWidget {
  final Map<String, dynamic> question;
  final bool? currentValue;
  final ValueChanged<bool> onChanged;

  const _BooleanQuestion({super.key, required this.question, required this.currentValue, required this.onChanged});

  @override
  State<_BooleanQuestion> createState() => _BooleanQuestionState();
}

class _BooleanQuestionState extends State<_BooleanQuestion> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.currentValue ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: _value ? p.primarySoft : p.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: _value ? p.primary : p.border),
      ),
      child: SwitchListTile(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        title: Text(
          'Yes / No',
          style: context.text.bodyMedium?.copyWith(color: p.textPrimary, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_value ? 'Yes' : 'No', style: context.text.bodySmall),
        value: _value,
        onChanged: (val) {
          setState(() => _value = val);
          widget.onChanged(val);
          developer.log('[Clarification] Boolean changed: $val for question ${widget.question['id']}');
        },
      ),
    );
  }
}

class _TextInputWidget extends StatefulWidget {
  final Map<String, dynamic> question;
  final ValueChanged<String?> onChanged;

  const _TextInputWidget({super.key, required this.question, required this.onChanged});

  @override
  State<_TextInputWidget> createState() => _TextInputWidgetState();
}

class _TextInputWidgetState extends State<_TextInputWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isDateContext {
    final q = widget.question;
    final id = (q['id'] ?? '').toString().toLowerCase();
    final title = (q['title'] ?? '').toString().toLowerCase();
    final qText = (q['question'] ?? '').toString().toLowerCase();
    final type = (q['type'] ?? '').toString().toLowerCase();
    return type == 'date' ||
        type == 'datetime' ||
        id.contains('date') ||
        title.contains('date') ||
        qText.contains('date');
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      final formatted = DateFormat('dd-MMM-yyyy').format(picked);
      setState(() {
        _controller.text = formatted;
      });
      widget.onChanged(formatted);
      developer.log('[Clarification] TextInput picked date: $formatted for question ${widget.question['id']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final type = widget.question['type'] ?? 'text';
    final isDate = _isDateContext;

    return TextFormField(
      controller: _controller,
      keyboardType: type == 'number' ? TextInputType.number : TextInputType.text,
      onChanged: (val) {
        widget.onChanged(val.isEmpty ? null : val);
      },
      decoration: InputDecoration(
        hintText: isDate ? 'e.g., 15-Feb-2026 (or tap calendar)' : 'Type your answer',
        prefixIcon: isDate ? Icon(Icons.edit_calendar_rounded, size: 18, color: p.primary) : null,
        suffixIcon: isDate
            ? IconButton(
                tooltip: 'Open calendar',
                icon: Icon(Icons.calendar_month_rounded, size: 20, color: p.primary),
                onPressed: _pickDate,
              )
            : null,
      ),
    );
  }
}

class _DateQuestionWidget extends StatefulWidget {
  final Map<String, dynamic> question;
  final String? currentValue;
  final ValueChanged<String?> onChanged;

  const _DateQuestionWidget({super.key, required this.question, required this.currentValue, required this.onChanged});

  @override
  State<_DateQuestionWidget> createState() => _DateQuestionWidgetState();
}

class _DateQuestionWidgetState extends State<_DateQuestionWidget> {
  late final TextEditingController _controller;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A YYYY-MM-DD hint the server may send with a date question.
  DateTime? _hint(String key) {
    final value = widget.question[key];
    if (value == null) return null;
    final parsed = DateTime.tryParse(value.toString());
    return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final DateTime firstDate = _hint('minDate') ?? DateTime(2000);
    final DateTime maxHint = _hint('maxDate') ?? DateTime(2035);
    final DateTime lastDate = maxHint.isBefore(firstDate) ? firstDate : maxHint;
    // Open on the date picked before, else the server's suggestion, else today,
    // kept inside the allowed range so the picker never fails to open.
    DateTime initialDate = _selectedDate ?? _hint('initialDate') ?? now;
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      final formatted = DateFormat('dd-MMM-yyyy').format(picked);
      setState(() {
        _selectedDate = picked;
        _controller.text = formatted;
      });
      widget.onChanged(formatted);
      developer.log('[Clarification] DateQuestionWidget picked date: $formatted for question ${widget.question['id']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasValue = _controller.text.isNotEmpty;

    return Material(
      color: p.surfaceMuted,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: _pickDate,
        borderRadius: AppRadius.mdAll,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: hasValue ? p.primary : p.border),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_month_rounded, size: 20, color: p.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  hasValue ? _controller.text : 'Select date *',
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                    color: hasValue ? p.textPrimary : p.textTertiary,
                  ),
                ),
              ),
              Icon(Icons.expand_more_rounded, color: p.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Main Dialog ─────────────────────────────────────────────────────────────

class ClarificationDialog extends StatefulWidget {
  final Map<String, dynamic> clarificationData;
  final Function(Map<String, dynamic>) onSubmit;
  final VoidCallback onCancel;

  /// Name of the policy these questions belong to (multi-policy analysis).
  /// Omitted for single-policy analysis, which keeps its original wording.
  final String? contextLabel;

  /// Insurer behind that policy, shown under its name to tell apart two
  /// similarly named policies.
  final String? contextSubLabel;

  /// e.g. "1 of 2 policies need your input" — only when more than one policy is
  /// waiting, so the user knows another question follows.
  final String? queueLabel;

  /// Temporary number of the asking policy in a comparison (e.g. 2 of 4).
  final int? policyNumber;
  final int? policyCount;

  const ClarificationDialog({
    super.key,
    required this.clarificationData,
    required this.onSubmit,
    required this.onCancel,
    this.contextLabel,
    this.contextSubLabel,
    this.queueLabel,
    this.policyNumber,
    this.policyCount,
  });

  @override
  State<ClarificationDialog> createState() => _ClarificationDialogState();
}

class _ClarificationDialogState extends State<ClarificationDialog> {
  // Answers stored centrally in the parent dialog, but individual
  // question widgets manage their own visual state locally.
  final Map<String, dynamic> _answers = {};
  late final List<dynamic> _questions;

  @override
  void initState() {
    super.initState();
    _questions = widget.clarificationData['questions'] ?? [];
    developer.log(
      '[Clarification] Dialog opened with ${_questions.length} questions: '
      '${_questions.map((q) => q['id']).toList()}',
    );
  }

  bool _canSubmit() {
    for (var q in _questions) {
      if (q['required'] == true) {
        final answer = _answers[q['id']];
        if (answer == null) return false;
        if (answer is String && answer.trim().isEmpty) return false;
        if (answer is List && answer.isEmpty) return false;
      }
    }
    return true;
  }

  void _onAnswerChanged(String questionId, dynamic value) {
    setState(() {
      _answers[questionId] = value;
    });
    developer.log('[Clarification] Answer stored: $questionId = $value');
  }

  /// Splits backend question text into lead-in context and the final question
  /// sentence, so the question itself can be shown prominently. Text is unchanged.
  ({String context, String question}) _splitQuestion(String text) {
    final trimmed = text.trim();
    final qMark = trimmed.lastIndexOf('?');
    if (qMark <= 0) return (context: '', question: trimmed);
    final before = trimmed.substring(0, qMark);
    final boundary = RegExp(r'[.!?]\s+').allMatches(before).fold<int>(-1, (_, m) => m.end);
    if (boundary <= 0) return (context: '', question: trimmed);
    return (context: trimmed.substring(0, boundary).trim(), question: trimmed.substring(boundary).trim());
  }

  void _handleSubmit() {
    developer.log('[Clarification] Submit pressed. Payload: $_answers');
    widget.onSubmit(Map<String, dynamic>.from(_answers));
  }

  Widget _buildQuestionInput(Map<String, dynamic> q) {
    final String type = (q['type'] ?? 'text').toString().toLowerCase();
    final String id = (q['id'] ?? '').toString();
    final String title = (q['title'] ?? '').toString();
    final String qText = (q['question'] ?? '').toString();
    final options = List<dynamic>.from(q['options'] ?? []);

    final bool isDate =
        type == 'date' ||
        type == 'datetime' ||
        (options.isEmpty &&
            (id.toLowerCase().contains('date') ||
                title.toLowerCase().contains('date') ||
                qText.toLowerCase().contains('date')));

    if (isDate) {
      return _DateQuestionWidget(
        key: ValueKey('date_$id'),
        question: q,
        currentValue: _answers[id] as String?,
        onChanged: (val) => _onAnswerChanged(id, val),
      );
    }

    switch (type) {
      case 'date':
      case 'datetime':
        return _DateQuestionWidget(
          key: ValueKey('date_$id'),
          question: q,
          currentValue: _answers[id] as String?,
          onChanged: (val) => _onAnswerChanged(id, val),
        );
      case 'single_choice':
        return _SingleChoiceQuestion(
          key: ValueKey('sc_$id'),
          question: q,
          currentValue: _answers[id] as String?,
          onChanged: (val) => _onAnswerChanged(id, val),
        );
      case 'multi_choice':
        return _MultiChoiceQuestion(
          key: ValueKey('mc_$id'),
          question: q,
          currentValues: (_answers[id] as List<String>?) ?? [],
          onChanged: (val) => _onAnswerChanged(id, val),
        );
      case 'boolean':
        return _BooleanQuestion(
          key: ValueKey('bool_$id'),
          question: q,
          currentValue: _answers[id] as bool?,
          onChanged: (val) => _onAnswerChanged(id, val),
        );
      case 'text':
      case 'number':
      default:
        return _TextInputWidget(key: ValueKey('text_$id'), question: q, onChanged: (val) => _onAnswerChanged(id, val));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    final canSubmit = _canSubmit();
    final hasRequired = _questions.any((q) => q is Map && q['required'] == true);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xl),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconTile(icon: Icons.quiz_outlined, size: 44),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Clarification Needed', style: t.titleLarge),
                        // Multi-policy comparison only: which policy (by its
                        // number on the comparison screen) is asking.
                        if (widget.policyNumber != null) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          StatusBadge(
                            dense: true,
                            tone: AppTone.warning,
                            icon: Icons.shield_outlined,
                            label: (widget.policyCount ?? 0) > 1
                                ? 'Policy ${widget.policyNumber} of ${widget.policyCount}'
                                : 'Policy ${widget.policyNumber}',
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          widget.contextLabel != null
                              ? 'These questions are about one policy only.'
                              : 'Answer to complete your coverage analysis.',
                          style: t.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: p.border),

            // ── Which policy is asking ───────────────────────────────
            // In a multi-policy comparison the answers only apply to this one
            // policy, so it is named up front rather than in fine print.
            if (widget.contextLabel != null) ...[
              Container(
                color: p.primarySoft,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.policyNumber != null)
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
                        child: Text(
                          '${widget.policyNumber}',
                          style: t.titleSmall?.copyWith(color: p.onPrimary, fontWeight: FontWeight.w700),
                        ),
                      )
                    else
                      Icon(Icons.shield_outlined, size: 20, color: p.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.policyNumber != null
                                ? 'Asked about Policy ${widget.policyNumber}'
                                      '${(widget.policyCount ?? 0) > 1 ? ' of ${widget.policyCount}' : ''}'
                                : 'Asked about this policy',
                            style: t.labelSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(widget.contextLabel!, style: t.titleSmall),
                          if ((widget.contextSubLabel ?? '').isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(widget.contextSubLabel!, style: t.bodySmall),
                          ],
                          const SizedBox(height: AppSpacing.xxs),
                          Text(widget.queueLabel ?? 'Your other policies are unaffected.', style: t.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: p.border),
            ],

            // ── Scrollable Questions ─────────────────────────────────
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                shrinkWrap: true,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: _questions.length,
                separatorBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Divider(height: 1, color: p.border),
                ),
                itemBuilder: (context, index) {
                  final q = _questions[index];
                  final reason = q['reason'];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Question header: topic, any context sentences, then the question itself.
                      Builder(
                        builder: (context) {
                          final parts = _splitQuestion((q['question'] ?? '').toString());
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(color: p.primarySoft, shape: BoxShape.circle),
                                    child: Text(
                                      '${index + 1}',
                                      style: t.labelSmall?.copyWith(
                                        color: p.primary,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      (q['title'] ?? 'Question ${index + 1}').toString(),
                                      style: t.labelMedium?.copyWith(color: p.primary, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                              if (parts.context.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(parts.context, textAlign: TextAlign.start, style: t.bodyMedium),
                              ],
                              if (parts.question.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text(parts.question, style: t.titleMedium?.copyWith(height: 1.35)),
                              ],
                            ],
                          );
                        },
                      ),
                      if (reason != null && (reason as String).isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        InfoBanner(
                          tone: AppTone.warning,
                          icon: Icons.info_outline_rounded,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                          child: Text(
                            reason,
                            textAlign: TextAlign.start,
                            style: t.bodySmall?.copyWith(color: p.textPrimary.withAlpha(220)),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      // Input widget — isolated StatefulWidget per question
                      _buildQuestionInput(q),
                    ],
                  );
                },
              ),
            ),

            // ── Footer ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: p.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasRequired && !canSubmit) ...[
                    Text(
                      'Please answer the questions above to continue.',
                      textAlign: TextAlign.center,
                      style: t.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            developer.log('[Clarification] Cancel pressed');
                            widget.onCancel();
                          },
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: canSubmit ? _handleSubmit : null,
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                          child: const Text('Submit Answers', overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
