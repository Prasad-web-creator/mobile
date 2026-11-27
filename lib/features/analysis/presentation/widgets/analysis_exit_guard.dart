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
            title: const Text('Stop the analysis?'),
            content: const Text(
              'The report will be discarded. Your policy and prescription documents will stay saved.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep analyzing'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Stop analysis'),
              ),
            ],
          ),
        ),
      ) ??
      false;
}
