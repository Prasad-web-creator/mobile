import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';
import 'package:claimsupport/features/benefits/data/models/policy_benefits.dart';
import 'package:claimsupport/features/benefits/presentation/controllers/benefits_controller.dart';
import 'package:claimsupport/features/policies/data/models/policy.dart';

final _date = DateFormat('dd MMM yyyy');
final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// My Benefits: a plain-language view of one selected policy's benefits,
/// built only from the policy data already stored on the server.
class MyBenefitsScreen extends ConsumerStatefulWidget {
  const MyBenefitsScreen({super.key});

  @override
  ConsumerState<MyBenefitsScreen> createState() => _MyBenefitsScreenState();
}

class _MyBenefitsScreenState extends ConsumerState<MyBenefitsScreen> {
  String? _selectedId;

  Future<void> _refresh() async {
    ref.invalidate(benefitsPoliciesProvider);
    if (_selectedId != null) ref.invalidate(policyBenefitsProvider(_selectedId!));
    await ref.read(benefitsPoliciesProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final policiesState = ref.watch(benefitsPoliciesProvider);

    return Scaffold(
      backgroundColor: p.background,
      appBar: const TabAppBar(title: 'My Benefits', subtitle: 'Understand your insurance benefits at a glance'),
      body: SafeArea(
        child: policiesState.when(
          loading: () => const LoadingState(message: 'Loading your policies…'),
          error: (err, _) => ErrorState(
            title: 'Couldn\'t load your policies',
            message: friendlyErrorMessage(err),
            onRetry: () => ref.invalidate(benefitsPoliciesProvider),
          ),
          data: (list) {
            if (list.ready.isEmpty) return _NoPolicies(onRefresh: _refresh, hasPolicies: list.total > 0);
            final policies = list.ready;

            // Keep the selection valid: auto-select when there is one policy, or
            // when the previously selected policy no longer exists.
            final selected = policies.firstWhere((x) => x.id == _selectedId, orElse: () => policies.first);
            _selectedId = selected.id;

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.xxl),
                children: [
                  ContentWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PolicyPicker(
                          policies: policies,
                          selectedId: selected.id,
                          onChanged: (id) => setState(() => _selectedId = id),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // Keyed by policy id so nothing from the previous policy stays on screen.
                        _BenefitsBody(key: ValueKey(selected.id), policy: selected),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Policy picker & empty state
// ─────────────────────────────────────────────────────────────────────────────

String _policyLabel(Policy x) {
  final name = x.policyName.trim().isNotEmpty ? x.policyName.trim() : x.insuranceCompany.trim();
  return name.isNotEmpty ? name : 'Policy ${x.displayId}';
}

String _policyNumber(Policy x) => x.policyNumber.trim().isNotEmpty ? x.policyNumber.trim() : 'No policy number';

/// Policy selector. The menu opens directly below the field and is exactly as
/// wide as the field (not the full screen), showing name + number per policy.
class _PolicyPicker extends StatelessWidget {
  final List<Policy> policies;
  final String selectedId;
  final ValueChanged<String> onChanged;

  const _PolicyPicker({required this.policies, required this.selectedId, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final single = policies.length == 1;
    final selected = policies.firstWhere((x) => x.id == selectedId, orElse: () => policies.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          single ? 'Your policy' : 'Select your policy',
          style: context.text.labelLarge?.copyWith(color: p.textSecondary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xs),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return MenuAnchor(
              alignmentOffset: const Offset(0, AppSpacing.xxs),
              style: MenuStyle(
                backgroundColor: WidgetStatePropertyAll(p.surface),
                surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
                elevation: const WidgetStatePropertyAll(6),
                padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: AppSpacing.xxs)),
                minimumSize: WidgetStatePropertyAll(Size(width, 0)),
                maximumSize: WidgetStatePropertyAll(Size(width, 360)),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: AppRadius.mdAll,
                    side: BorderSide(color: p.border),
                  ),
                ),
              ),
              menuChildren: [
                for (final x in policies)
                  SizedBox(
                    width: width,
                    child: MenuItemButton(
                      onPressed: () => onChanged(x.id),
                      style: ButtonStyle(
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                        ),
                        backgroundColor: WidgetStatePropertyAll(x.id == selected.id ? p.primarySoft : null),
                      ),
                      trailingIcon: x.id == selected.id ? Icon(Icons.check_rounded, size: 20, color: p.primary) : null,
                      child: SizedBox(
                        width: width - AppSpacing.md * 2 - 28,
                        child: _PolicyLabel(policy: x),
                      ),
                    ),
                  ),
              ],
              builder: (context, controller, _) {
                return AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                  borderRadius: AppRadius.mdAll,
                  borderColor: controller.isOpen ? p.primary : null,
                  onTap: single ? null : () => controller.isOpen ? controller.close() : controller.open(),
                  child: Row(
                    children: [
                      const IconTile(icon: Icons.shield_outlined, size: 36),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: _PolicyLabel(policy: selected)),
                      if (!single) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          controller.isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: p.primary,
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// Policy name on the first line, policy number below it.
class _PolicyLabel extends StatelessWidget {
  final Policy policy;

  const _PolicyLabel({required this.policy});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _policyLabel(policy),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: p.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          _policyNumber(policy),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodySmall?.copyWith(color: p.textSecondary),
        ),
      ],
    );
  }
}

class _NoPolicies extends StatelessWidget {
  final Future<void> Function() onRefresh;

  /// True when the user has policies, but none has benefit details yet.
  final bool hasPolicies;

  const _NoPolicies({required this.onRefresh, this.hasPolicies = false});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xxl, AppSpacing.page, AppSpacing.xxl),
        children: [
          ContentWidth(
            child: hasPolicies
                ? const EmptyState(
                    icon: Icons.hourglass_empty_rounded,
                    title: 'Benefit details not available yet',
                    message:
                        'Your policies\' benefits are added once they have been read during a coverage check. Run a check with a policy to see its benefits here.',
                  )
                : const EmptyState(
                    icon: Icons.shield_outlined,
                    title: 'No policies yet',
                    message:
                        'Once you have a policy, its benefits, limits and waiting periods will appear here in one place.',
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Benefits of the selected policy
// ─────────────────────────────────────────────────────────────────────────────

class _BenefitsBody extends ConsumerWidget {
  final Policy policy;

  const _BenefitsBody({super.key, required this.policy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(policyBenefitsProvider(policy.id));
    return state.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: LoadingState(message: 'Loading benefits…'),
      ),
      error: (err, _) => ErrorState(
        compact: true,
        title: 'Couldn\'t load benefits',
        message: friendlyErrorMessage(err),
        onRetry: () => ref.invalidate(policyBenefitsProvider(policy.id)),
      ),
      data: (b) => _BenefitsContent(benefits: b, policy: policy),
    );
  }
}

class _BenefitsContent extends StatelessWidget {
  final PolicyBenefits benefits;
  final Policy policy;

  const _BenefitsContent({required this.benefits, required this.policy});

  @override
  Widget build(BuildContext context) {
    final b = benefits;
    final limits = [?b.roomRent, ...b.limits];
    final hasConditions = b.specialConditions.isNotEmpty || b.exclusions.isNotEmpty || b.nonPayableItems.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OverviewCard(overview: b.overview, fallback: policy),
        const SizedBox(height: AppSpacing.section),
        if (!b.hasDetails)
          const AppCard(
            child: EmptyState(
              compact: true,
              icon: Icons.hourglass_empty_rounded,
              title: 'Benefit details not available yet',
              message:
                  'Your policy\'s benefits are added once it has been read during a coverage check. Run a check with this policy to see them here.',
            ),
          )
        else ...[
          const SectionHeader(title: 'Key Benefits', icon: Icons.verified_user_outlined),
          _SumInsuredCard(benefits: b),
          const SizedBox(height: AppSpacing.sm),
          _TwoColumn(
            children: [
              _BenefitTile(item: b.coPayment, icon: Icons.percent_rounded),
              _BenefitTile(item: b.deductible, icon: Icons.account_balance_wallet_outlined),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _WaitingPeriodsCard(benefits: b),
          if (limits.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.section),
            const SectionHeader(
              title: 'Coverage Limits',
              subtitle: 'The most the policy pays for these',
              icon: Icons.straighten_rounded,
            ),
            _ItemListCard(items: limits),
          ],
          if (b.additionalBenefits.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.section),
            const SectionHeader(title: 'Additional Benefits', icon: Icons.add_moderator_outlined),
            _ItemListCard(items: b.additionalBenefits),
          ],
          if (hasConditions) ...[
            const SizedBox(height: AppSpacing.section),
            const SectionHeader(title: 'Important Conditions', icon: Icons.rule_rounded),
            _ConditionsCard(benefits: b),
          ],
          const SizedBox(height: AppSpacing.section),
          const InfoBanner(
            tone: AppTone.neutral,
            icon: Icons.info_outline_rounded,
            message:
                'Shown from the details read from your policy document. Benefits are subject to the policy\'s terms and do not guarantee claim approval.',
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overview
// ─────────────────────────────────────────────────────────────────────────────

class _OverviewCard extends StatelessWidget {
  final PolicyOverview overview;
  final Policy fallback;

  const _OverviewCard({required this.overview, required this.fallback});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final o = overview;
    final name = o.policyName ?? o.insuranceCompany ?? _policyLabel(fallback);
    final insurer = o.policyName != null ? o.insuranceCompany : null;
    final (label, tone, icon) = switch (o.validity) {
      PolicyValidity.active => ('Active', AppTone.success, Icons.check_circle_outline_rounded),
      PolicyValidity.expired => ('Expired', AppTone.danger, Icons.event_busy_outlined),
      PolicyValidity.upcoming => ('Upcoming', AppTone.info, Icons.schedule_rounded),
      PolicyValidity.unknown => ('Dates not available', AppTone.neutral, Icons.help_outline_rounded),
    };
    final period = (o.startDate != null || o.endDate != null)
        ? '${o.startDate != null ? _date.format(o.startDate!) : '—'} – ${o.endDate != null ? _date.format(o.endDate!) : '—'}'
        : null;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconTile(icon: Icons.health_and_safety_outlined, size: 40),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (insurer != null)
                      Text(insurer, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topRight,
                  child: StatusBadge(label: label, tone: tone, icon: icon, dense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, color: p.border),
          const SizedBox(height: AppSpacing.xs),
          KeyValueRow(label: 'Policy number', value: o.policyNumber ?? 'Not specified', labelWidth: 112),
          if (o.policyHolderName != null)
            KeyValueRow(label: 'Policyholder', value: o.policyHolderName!, labelWidth: 112),
          KeyValueRow(label: 'Valid', value: period ?? 'Not specified', labelWidth: 112),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Key benefits
// ─────────────────────────────────────────────────────────────────────────────

class _SumInsuredCard extends StatelessWidget {
  final PolicyBenefits benefits;

  const _SumInsuredCard({required this.benefits});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final amount = benefits.sumInsured;
    return AppCard(
      color: p.primarySoft,
      borderColor: p.primary.withAlpha(50),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const IconTile(icon: Icons.shield_rounded, size: 44),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sum Insured', style: context.text.labelLarge?.copyWith(color: p.textSecondary)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    amount != null ? _inr.format(amount) : 'Not specified',
                    style: context.text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: amount != null ? p.primary : p.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  amount != null
                      ? 'Maximum insured amount, subject to policy terms.'
                      : 'Your policy details don\'t state the sum insured.',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Two equal-height columns; stacks on very narrow screens or large text.
class _TwoColumn extends StatelessWidget {
  final List<Widget> children;

  const _TwoColumn({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        if (c.maxWidth < 330 || scale > 1.3) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                children[i],
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(child: children[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BenefitTile extends StatelessWidget {
  final BenefitItem item;
  final IconData icon;

  const _BenefitTile({required this.item, required this.icon});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final value = item.available ? (item.value ?? 'Not specified') : 'Not specified';
    final muted = !item.available || item.value == null;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => showBenefitDetails(context, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon: icon, size: 32),
              const Spacer(),
              Icon(Icons.info_outline_rounded, size: 20, color: p.primary),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(item.title, style: context.text.labelLarge?.copyWith(color: p.textSecondary)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: muted ? p.textTertiary : p.textPrimary,
              ),
            ),
          ),
          if (item.description != null) ...[
            const SizedBox(height: 4),
            Text(item.description!, style: context.text.bodySmall?.copyWith(height: 1.35)),
          ],
          if (item.conditions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.conditions.first,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(color: p.warning.fg, fontWeight: FontWeight.w600, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

class _WaitingPeriodsCard extends StatelessWidget {
  final PolicyBenefits benefits;

  const _WaitingPeriodsCard({required this.benefits});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final b = benefits;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardTitle(
            title: 'Waiting Periods',
            subtitle: 'Time before some claims can be paid',
            icon: Icons.hourglass_bottom_rounded,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (b.waitingPeriods.isEmpty)
            Text(
              'Not specified in your policy details.',
              style: context.text.bodyMedium?.copyWith(color: p.textTertiary),
            )
          else
            for (var i = 0; i < b.waitingPeriods.length; i++) ...[
              if (i > 0) Divider(height: AppSpacing.lg, color: p.border),
              _WaitingRow(period: b.waitingPeriods[i]),
            ],
          if (b.waitingStartDate != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Dates are counted from ${_date.format(b.waitingStartDate!)}'
              '${b.waitingBasis != null ? ' — ${b.waitingBasis}' : ''}.',
              style: context.text.bodySmall?.copyWith(height: 1.4),
            ),
          ],
          for (final note in b.waitingNotes) ...[
            const SizedBox(height: AppSpacing.xs),
            InfoBanner(tone: AppTone.info, padding: const EdgeInsets.all(AppSpacing.sm), message: note),
          ],
        ],
      ),
    );
  }
}

class _WaitingRow extends StatelessWidget {
  final WaitingPeriod period;

  const _WaitingRow({required this.period});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final w = period;
    final over = w.isOver;
    final details = BenefitItem(
      key: w.key,
      title: w.title,
      value: w.duration,
      description: w.description,
      conditions: w.conditions,
      wording: w.wording,
      reference: w.reference,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TitleValueRow(title: w.title, value: w.duration ?? 'Not specified', muted: w.duration == null),
        if (w.description != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(w.description!, style: context.text.bodySmall?.copyWith(height: 1.4)),
        ],
        if (w.conditions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Applies to: ${w.conditions.join('; ')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(color: p.textSecondary),
          ),
        ],
        if (w.endDate != null || details.hasDetails) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (w.endDate != null)
                StatusBadge(
                  dense: true,
                  tone: over == true ? AppTone.success : AppTone.warning,
                  icon: over == true ? Icons.event_available_outlined : Icons.event_outlined,
                  label: over == true ? 'Ended ${_date.format(w.endDate!)}' : 'Ends ${_date.format(w.endDate!)}',
                ),
              if (details.hasDetails) _ViewConditionButton(onTap: () => showBenefitDetails(context, details)),
            ],
          ),
        ],
      ],
    );
  }
}

/// Title on the left, value pinned to the right edge.
class _TitleValueRow extends StatelessWidget {
  final String title;
  final String? value;
  final bool muted;

  const _TitleValueRow({required this.title, this.value, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(title, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.3)),
        ),
        if (value != null) ...[
          const SizedBox(width: AppSpacing.sm),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.38),
            child: Text(
              value!,
              textAlign: TextAlign.right,
              style: context.text.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.3,
                color: muted ? p.textTertiary : p.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A clearly tappable pill shown only where the stored policy wording can be opened.
class _ViewConditionButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ViewConditionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.primarySoft,
      shape: StadiumBorder(side: BorderSide(color: p.primary.withAlpha(70))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_outlined, size: 15, color: p.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'View policy condition',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(color: p.primary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded, size: 16, color: p.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Limits / additional benefits
// ─────────────────────────────────────────────────────────────────────────────

class _ItemListCard extends StatelessWidget {
  final List<BenefitItem> items;

  const _ItemListCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md, color: p.border),
            _ItemRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final BenefitItem item;

  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TitleValueRow(title: item.title, value: item.value),
          if (item.description != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(item.description!, style: context.text.bodySmall?.copyWith(height: 1.4)),
          ],
          if (item.conditions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              item.conditions.first,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(color: p.warning.fg, fontWeight: FontWeight.w600, height: 1.4),
            ),
          ],
          if (item.hasDetails) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: _ViewConditionButton(onTap: () => showBenefitDetails(context, item)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Important conditions
// ─────────────────────────────────────────────────────────────────────────────

class _ConditionsCard extends StatelessWidget {
  final PolicyBenefits benefits;

  const _ConditionsCard({required this.benefits});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final b = benefits;
    final sections = [
      if (b.specialConditions.isNotEmpty)
        (
          Icons.gavel_rounded,
          AppTone.info,
          'Policy conditions',
          'Rules that apply to your claims',
          b.specialConditions,
        ),
      if (b.exclusions.isNotEmpty)
        (
          Icons.block_rounded,
          AppTone.danger,
          'Not covered',
          'Treatments and situations the policy excludes',
          b.exclusions,
        ),
      if (b.nonPayableItems.isNotEmpty)
        (
          Icons.receipt_long_outlined,
          AppTone.warning,
          'Items not paid',
          'Non-medical items you pay for yourself',
          b.nonPayableItems,
        ),
    ];

    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Column(
          children: [
            for (var i = 0; i < sections.length; i++) ...[
              if (i > 0) Divider(height: 1, color: p.border),
              ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
                childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                leading: IconTile(icon: sections[i].$1, tone: sections[i].$2, size: 32),
                title: Text(
                  '${sections[i].$3} (${sections[i].$5.length})',
                  style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(sections[i].$4, style: context.text.bodySmall),
                iconColor: p.primary,
                collapsedIconColor: p.textTertiary,
                children: [for (final line in sections[i].$5) _Bullet(text: line)],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: p.textTertiary, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(text, style: context.text.bodyMedium?.copyWith(height: 1.4, color: p.textSecondary)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Policy wording sheet
// ─────────────────────────────────────────────────────────────────────────────

/// Shows the stored policy wording behind a benefit. Clause/page references are
/// shown only when the stored data has them — never invented.
/// Plain-English meaning of key insurance terms (general explanation, not policy data).
const _termHelp = <String, String>{
  'coPayment': 'Co-payment is the share of an eligible claim you pay yourself. The insurer pays the rest.',
  'deductible': 'A deductible is a fixed amount you pay first, before the insurer starts paying a claim.',
};

void showBenefitDetails(BuildContext context, BenefitItem item) {
  final p = context.palette;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: p.surface,
    builder: (context) {
      final ref = item.reference;
      final refLabel = ref == null
          ? null
          : [if (ref.clause != null) 'Clause ${ref.clause}', if (ref.page != null) 'Page ${ref.page}'].join(' · ');
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(item.title, style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              if (item.value != null) ...[
                const SizedBox(height: 4),
                Text(
                  item.value!,
                  style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: p.primary),
                ),
              ],
              if (item.description != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(item.description!, style: context.text.bodyMedium?.copyWith(color: p.textSecondary)),
              ],
              if (_termHelp[item.key] != null) ...[
                const SizedBox(height: AppSpacing.md),
                InfoBanner(
                  tone: AppTone.info,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  title: 'What this means',
                  message: _termHelp[item.key],
                ),
              ],
              if (item.conditions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Conditions', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                for (final c in item.conditions) _Bullet(text: c),
              ],
              if (item.wording != null || ref?.text != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Policy wording', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: p.surfaceMuted,
                    borderRadius: AppRadius.mdAll,
                    border: Border(left: BorderSide(color: p.primary, width: 3)),
                  ),
                  child: Text(
                    '“${ref?.text ?? item.wording}”',
                    style: context.text.bodyMedium?.copyWith(height: 1.45, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                refLabel != null && refLabel.isNotEmpty
                    ? 'Source: $refLabel of your policy document.'
                    : (item.wording != null || item.conditions.isNotEmpty)
                    ? 'As read from your policy document. Page reference not available for this detail.'
                    : 'This is not stated in the details read from your policy document.',
                style: context.text.bodySmall,
              ),
            ],
          ),
        ),
      );
    },
  );
}
