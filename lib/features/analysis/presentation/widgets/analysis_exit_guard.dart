import 'package:claimsupport/core/localization/localization.dart';
import 'dart:async';

import 'package:claimsupport/core/design/widgets/app_design_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _exitGuards = Provider((ref) => <String, Future<bool> Function()>{});

VoidCallback registerAnalysisExitGuard(
  WidgetRef ref,
  String key,
  Future<bool> Function() guard,
) {
  final guards = ref.read(_exitGuards);
  guards[key] = guard;
  return () {
    if (guards[key] == guard) guards.remove(key);
  };
}

FutureOr<bool> confirmAnalysisRouteExit(
  BuildContext context,
  GoRouterState state,
) {
  final guards = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(_exitGuards);
  return guards[state.pathParameters['jobId'] ?? state.matchedLocation]
          ?.call() ??
      true;
}

Future<bool> confirmStoppingAnalysis(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AppDesignSurface(
          child: AlertDialog(
            title: Text(context.l10n.analysisStopQuestion),
            content: Text(context.l10n.analysisStopExplanation),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.analysisKeepAnalyzing),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.l10n.analysisStop),
              ),
            ],
          ),
        ),
      ) ??
      false;
}
