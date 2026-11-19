import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';

/// A responsive, animated Donut Chart widget that visually represents
/// the percentage breakdown of Covered, Partially Covered, Not Covered and
/// Needs Verification claim items. The Needs Verification segment and legend
/// row appear only when at least one item needs verification.
class CoverageDonutChart extends StatefulWidget {
  final Map<String, dynamic>? coverageBreakdown;
  final bool isPolicyValid;
  final bool isPrescriptionValid;

  const CoverageDonutChart({
    super.key,
    required this.coverageBreakdown,
    this.isPolicyValid = true,
    this.isPrescriptionValid = true,
  });

  @override
  State<CoverageDonutChart> createState() => _CoverageDonutChartState();
}

class _CoverageDonutChartState extends State<CoverageDonutChart> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;

  // Selected segment index: 0 = Covered, 1 = Partially Covered, 2 = Not Covered,
  // 3 = Needs Verification, null = none
  int? _selectedSegment;

  // Segment colours come from the app palette (set at the start of build).
  Color coveredColor = AppPalette.light.success.fg;
  Color partiallyCoveredColor = AppPalette.light.warning.fg;
  Color notCoveredColor = AppPalette.light.danger.fg;
  Color needsVerificationColor = AppPalette.light.verify.fg;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _animation = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Calculates whole percentages that guaranteed sum to 100% using Largest Remainder Method.
  Map<String, int> _calculateWholePercentages({
    required int covered,
    required int partiallyCovered,
    required int notCovered,
    int needsVerification = 0,
  }) {
    final total = covered + partiallyCovered + notCovered + needsVerification;
    if (total == 0) {
      return {'covered': 0, 'partiallyCovered': 0, 'notCovered': 0, 'needsVerification': 0};
    }

    final double coveredPct = (covered / total) * 100;
    final double partialPct = (partiallyCovered / total) * 100;
    final double notCoveredPct = (notCovered / total) * 100;
    final double verifyPct = (needsVerification / total) * 100;

    final int cFloor = coveredPct.floor();
    final int pFloor = partialPct.floor();
    final int nFloor = notCoveredPct.floor();
    final int vFloor = verifyPct.floor();

    final int remainder = 100 - (cFloor + pFloor + nFloor + vFloor);

    final remainders = [
      MapEntry('covered', coveredPct - cFloor),
      MapEntry('partiallyCovered', partialPct - pFloor),
      MapEntry('notCovered', notCoveredPct - nFloor),
      MapEntry('needsVerification', verifyPct - vFloor),
    ];

    // Sort descending by remainder
    remainders.sort((a, b) => b.value.compareTo(a.value));

    final result = {'covered': cFloor, 'partiallyCovered': pFloor, 'notCovered': nFloor, 'needsVerification': vFloor};

    for (int i = 0; i < remainder && i < remainders.length; i++) {
      final key = remainders[i].key;
      result[key] = (result[key] ?? 0) + 1;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    // 1. Visibility Check: Only display when BOTH Policy and Prescription are valid
    if (!widget.isPolicyValid || !widget.isPrescriptionValid) {
      return const SizedBox.shrink();
    }

    // 2. Error handling / Malformed data check
    if (widget.coverageBreakdown == null) {
      debugPrint('CoverageDonutChart: coverageBreakdown is null.');
      return const SizedBox.shrink();
    }

    try {
      final breakdown = widget.coverageBreakdown!;
      final int coveredCount = _parseInt(breakdown['covered']);
      final int partiallyCoveredCount = _parseInt(breakdown['partiallyCovered']);
      final int notCoveredCount = _parseInt(breakdown['notCovered']);
      final int verifyCount = _parseInt(breakdown['needsVerification']);
      final int totalEvaluated = coveredCount + partiallyCoveredCount + notCoveredCount + verifyCount;

      final isDark = context.isDark;
      final pal = context.palette;
      final Color textColor = pal.textPrimary;
      final Color textSecondary = pal.textTertiary;
      coveredColor = pal.success.fg;
      partiallyCoveredColor = pal.warning.fg;
      notCoveredColor = pal.danger.fg;
      needsVerificationColor = pal.verify.fg;

      // 3. Empty State: When zero items are evaluated
      if (totalEvaluated == 0) {
        return const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md),
          child: InfoBanner(tone: AppTone.neutral, message: 'No evaluated claim items available.'),
        );
      }

      // 4. Percentage calculation
      final percentages = _calculateWholePercentages(
        covered: coveredCount,
        partiallyCovered: partiallyCoveredCount,
        notCovered: notCoveredCount,
        needsVerification: verifyCount,
      );

      final int coveredPct = percentages['covered'] ?? 0;
      final int partialPct = percentages['partiallyCovered'] ?? 0;
      final int notCoveredPct = percentages['notCovered'] ?? 0;
      final int verifyPct = percentages['needsVerification'] ?? 0;

      // Angles in radians
      final double coveredAngle = (coveredCount / totalEvaluated) * 2 * math.pi;
      final double partialAngle = (partiallyCoveredCount / totalEvaluated) * 2 * math.pi;
      final double notCoveredAngle = (notCoveredCount / totalEvaluated) * 2 * math.pi;
      final double verifyAngle = (verifyCount / totalEvaluated) * 2 * math.pi;

      return Semantics(
        label:
            'Coverage Distribution Donut Chart: '
            '$coveredPct% Covered ($coveredCount items), '
            '$partialPct% Partially Covered ($partiallyCoveredCount items), '
            '$notCoveredPct% Not Covered ($notCoveredCount items)'
            '${verifyCount > 0 ? ', $verifyPct% Needs Verification ($verifyCount items)' : ''}.',
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              CardTitle(
                title: 'Coverage Distribution',
                icon: Icons.donut_large_rounded,
                subtitle: 'Tap a category to highlight it',
                trailing: StatusBadge(
                  label: '$totalEvaluated ${totalEvaluated == 1 ? "Item" : "Items"}',
                  tone: AppTone.neutral,
                  dense: true,
                ),
              ),
              const SizedBox(height: 20),

              // Responsive Chart & Legend Layout
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth >= 420;

                  final chartWidget = AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return SizedBox(
                        width: 170,
                        height: 170,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(170, 170),
                              painter: _DonutChartPainter(
                                coveredAngle: coveredAngle * _animation.value,
                                partialAngle: partialAngle * _animation.value,
                                notCoveredAngle: notCoveredAngle * _animation.value,
                                verifyAngle: verifyAngle * _animation.value,
                                coveredColor: coveredColor,
                                partialColor: partiallyCoveredColor,
                                notCoveredColor: notCoveredColor,
                                verifyColor: needsVerificationColor,
                                strokeWidth: 22,
                                highlightedIndex: _selectedSegment,
                              ),
                            ),
                            // Center Content
                            _buildCenterContent(
                              textColor: textColor,
                              textSecondary: textSecondary,
                              coveredPct: coveredPct,
                              partialPct: partialPct,
                              notCoveredPct: notCoveredPct,
                              coveredCount: coveredCount,
                              partialCount: partiallyCoveredCount,
                              notCoveredCount: notCoveredCount,
                              verifyPct: verifyPct,
                              verifyCount: verifyCount,
                              totalEvaluated: totalEvaluated,
                            ),
                          ],
                        ),
                      );
                    },
                  );

                  final legendWidget = Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem(
                        context: context,
                        label: 'Covered',
                        count: coveredCount,
                        percentage: coveredPct,
                        color: coveredColor,
                        index: 0,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildLegendItem(
                        context: context,
                        label: 'Partially Covered',
                        count: partiallyCoveredCount,
                        percentage: partialPct,
                        color: partiallyCoveredColor,
                        index: 1,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildLegendItem(
                        context: context,
                        label: 'Not Covered',
                        count: notCoveredCount,
                        percentage: notCoveredPct,
                        color: notCoveredColor,
                        index: 2,
                        isDark: isDark,
                      ),
                      if (verifyCount > 0) ...[
                        const SizedBox(height: 8),
                        _buildLegendItem(
                          context: context,
                          label: 'Needs Verification',
                          count: verifyCount,
                          percentage: verifyPct,
                          color: needsVerificationColor,
                          index: 3,
                          isDark: isDark,
                        ),
                      ],
                    ],
                  );

                  if (isWide) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        chartWidget,
                        const SizedBox(width: 20),
                        Expanded(child: legendWidget),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        Center(child: chartWidget),
                        const SizedBox(height: 20),
                        legendWidget,
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('CoverageDonutChart rendering error: $e\n$stackTrace');
      return const SizedBox.shrink();
    }
  }

  /// Builds the center label inside the donut hole
  Widget _buildCenterContent({
    required Color textColor,
    required Color textSecondary,
    required int coveredPct,
    required int partialPct,
    required int notCoveredPct,
    required int coveredCount,
    required int partialCount,
    required int notCoveredCount,
    int verifyPct = 0,
    int verifyCount = 0,
    required int totalEvaluated,
  }) {
    String title = 'Coverage';
    String value = '100%';
    String subtitle = '$totalEvaluated ${totalEvaluated == 1 ? "Item" : "Items"}';
    Color titleColor = textSecondary;

    if (_selectedSegment == 0) {
      title = 'Covered';
      value = '$coveredPct%';
      subtitle = '$coveredCount ${coveredCount == 1 ? "Item" : "Items"}';
      titleColor = coveredColor;
    } else if (_selectedSegment == 1) {
      title = 'Partial';
      value = '$partialPct%';
      subtitle = '$partialCount ${partialCount == 1 ? "Item" : "Items"}';
      titleColor = partiallyCoveredColor;
    } else if (_selectedSegment == 2) {
      title = 'Not Covered';
      value = '$notCoveredPct%';
      subtitle = '$notCoveredCount ${notCoveredCount == 1 ? "Item" : "Items"}';
      titleColor = notCoveredColor;
    } else if (_selectedSegment == 3) {
      title = 'Verify';
      value = '$verifyPct%';
      subtitle = '$verifyCount ${verifyCount == 1 ? "Item" : "Items"}';
      titleColor = needsVerificationColor;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSegment = null;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: titleColor, letterSpacing: 0.2),
            child: Text(title),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textColor, letterSpacing: -0.5),
            child: Text(value),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textSecondary),
            child: Text(subtitle),
          ),
        ],
      ),
    );
  }

  /// Builds a single legend row item
  Widget _buildLegendItem({
    required BuildContext context,
    required String label,
    required int count,
    required int percentage,
    required Color color,
    required int index,
    required bool isDark,
  }) {
    final bool isSelected = _selectedSegment == index;

    return Tooltip(
      message: '$label: $percentage% ($count items)',
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedSegment = isSelected ? null : index;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withAlpha(isDark ? 40 : 22) : context.palette.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color.withAlpha(120) : context.palette.border),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: context.palette.textPrimary,
                  ),
                ),
              ),
              Text(
                '$percentage%',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
              ),
              const SizedBox(width: 6),
              Text(
                '($count)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.palette.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentData {
  final double angle;
  final Color color;
  final int index;

  _SegmentData(this.angle, this.color, this.index);
}

/// Custom painter for rendering the donut chart segments
class _DonutChartPainter extends CustomPainter {
  final double coveredAngle;
  final double partialAngle;
  final double notCoveredAngle;
  final double verifyAngle;
  final Color coveredColor;
  final Color partialColor;
  final Color notCoveredColor;
  final Color verifyColor;
  final double strokeWidth;
  final int? highlightedIndex;

  _DonutChartPainter({
    required this.coveredAngle,
    required this.partialAngle,
    required this.notCoveredAngle,
    this.verifyAngle = 0,
    required this.coveredColor,
    required this.partialColor,
    required this.notCoveredColor,
    this.verifyColor = const Color(0xFF6D28D9),
    required this.strokeWidth,
    this.highlightedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (baseRadius <= 0) return;

    final segments = [
      _SegmentData(coveredAngle, coveredColor, 0),
      _SegmentData(partialAngle, partialColor, 1),
      _SegmentData(notCoveredAngle, notCoveredColor, 2),
      _SegmentData(verifyAngle, verifyColor, 3),
    ];

    final nonZeroSegments = segments.where((s) => s.angle > 0.001).toList();

    // If only one segment takes 100%
    if (nonZeroSegments.length == 1) {
      final seg = nonZeroSegments.first;
      final isHighlighted = highlightedIndex == seg.index;
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHighlighted ? strokeWidth + 4 : strokeWidth;
      canvas.drawCircle(center, baseRadius, paint);
      return;
    }

    // Multiple segments: draw arcs with smooth gap
    double startAngle = -math.pi / 2;
    const double gapAngle = 0.05; // ~2.8 degrees gap

    for (final seg in segments) {
      if (seg.angle <= 0.001) continue;

      final isHighlighted = highlightedIndex == seg.index;
      final currentStroke = isHighlighted ? strokeWidth + 4 : strokeWidth;
      final currentRadius = isHighlighted ? baseRadius + 1 : baseRadius;
      final currentRect = Rect.fromCircle(center: center, radius: currentRadius);

      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = currentStroke
        ..strokeCap = StrokeCap.round;

      final sweep = math.max(0.0, seg.angle - gapAngle);
      final actualStart = startAngle + (gapAngle / 2);

      canvas.drawArc(currentRect, actualStart, sweep, false, paint);
      startAngle += seg.angle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.coveredAngle != coveredAngle ||
        oldDelegate.partialAngle != partialAngle ||
        oldDelegate.notCoveredAngle != notCoveredAngle ||
        oldDelegate.verifyAngle != verifyAngle ||
        oldDelegate.verifyColor != verifyColor ||
        oldDelegate.highlightedIndex != highlightedIndex ||
        oldDelegate.coveredColor != coveredColor ||
        oldDelegate.partialColor != partialColor ||
        oldDelegate.notCoveredColor != notCoveredColor;
  }
}
