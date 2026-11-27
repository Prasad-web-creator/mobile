import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:claimsupport/core/utils/auth_storage.dart';
import 'package:claimsupport/features/analysis_reports/data/models/analysis_report_group.dart';
import 'package:claimsupport/features/home/data/check_summary.dart';

typedef HomeDocumentCounts = ({int prescriptions, int policies});

class HomeSnapshot {
  const HomeSnapshot({required this.account, required this.name, this.checks, this.counts});

  final String account;
  final String name;
  final List<CheckSummary>? checks;
  final HomeDocumentCounts? counts;
}

/// Keeps the previous Home display for the account in the saved session.
class HomeCheckCache {
  static const _storage = FlutterSecureStorage();
  static const _key = 'policy_pal_home_v1';
  HomeSnapshot? _saved;
  Future<void> _pending = Future.value();

  static Future<HomeCheckCache> restore() async {
    final cache = HomeCheckCache();
    try {
      final token = await AuthStorage.getToken();
      if (token == null) return cache;
      final parts = token.split('.');
      if (parts.length != 3) return cache;
      // This is a cache partition lookup. Authentication still goes through the API.
      final claims = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map;
      final owner = (claims['user'] as Map?)?['id'];
      if (owner is! String || owner.isEmpty) return cache;
      final raw = await _storage.read(key: _key);
      if (raw == null) return cache;
      final data = jsonDecode(raw) as Map;
      if (data['account'] != owner) return cache;
      final counts = data['counts'] as Map?;
      cache._saved = HomeSnapshot(
        account: owner,
        name: data['name'] as String,
        counts: counts == null
            ? null
            : (prescriptions: counts['prescriptions'] as int, policies: counts['policies'] as int),
        checks: (data['checks'] as List?)?.map((row) => _decodeCheck(row as Map)).toList(growable: false),
      );
    } catch (_) {
      debugPrint('[Home cache] Saved data could not be loaded.');
    }
    return cache;
  }

  HomeSnapshot? read(String? account) {
    final saved = _saved;
    return account == null || saved?.account == account ? saved : null;
  }

  HomeSnapshot? update({
    required String account,
    required String name,
    List<CheckSummary>? checks,
    HomeDocumentCounts? counts,
  }) {
    final old = read(account);
    final currentChecks = checks ?? old?.checks;
    final currentCounts = counts ?? old?.counts;
    if (currentChecks == null && currentCounts == null) return null;
    if (old?.name == name && identical(old?.checks, currentChecks) && old?.counts == currentCounts) {
      return old;
    }

    final saved = HomeSnapshot(account: account, name: name, checks: currentChecks, counts: currentCounts);
    _saved = saved;
    final payload = jsonEncode({
      'account': account,
      'name': name,
      'counts': currentCounts == null
          ? null
          : {'prescriptions': currentCounts.prescriptions, 'policies': currentCounts.policies},
      'checks': currentChecks?.take(5).map(_encodeCheck).toList(),
    });
    _enqueue(() => _storage.write(key: _key, value: payload));
    return saved;
  }

  void clear() {
    _saved = null;
    _enqueue(() => _storage.delete(key: _key));
  }

  void _enqueue(Future<void> Function() operation) {
    _pending = _pending.then((_) async {
      try {
        await operation();
      } catch (_) {
        debugPrint('[Home cache] Saved data could not be updated.');
      }
    });
    unawaited(_pending);
  }

  static Map<String, Object?> _encodeCheck(CheckSummary check) => {
    'id': check.id,
    'treatment': check.treatment,
    'patient': check.patientName,
    'date': check.createdAt?.toIso8601String(),
    'meta': check.meta,
    'status': check.statusLabel,
    'kind': check.statusKind.name,
    'count': check.policyCount,
    'policy': check.bestPolicyName,
    'issue': check.issue?.name,
    'route': check.route,
    'group': check.group?.toJson(),
  };

  static CheckSummary _decodeCheck(Map data) {
    final date = DateTime.tryParse(data['date'] as String? ?? '')?.toLocal();
    return CheckSummary(
      id: data['id'] as String,
      treatment: data['treatment'] as String,
      patientName: data['patient'] as String,
      createdAt: date,
      dateLabel: date == null ? '' : CheckSummary.displayDate(date, DateTime.now()),
      meta: data['meta'] as String,
      statusLabel: data['status'] as String,
      statusKind: CheckStatusKind.values.byName(data['kind'] as String),
      policyCount: data['count'] as int,
      bestPolicyName: data['policy'] as String,
      issue: data['issue'] is String ? CheckIssue.values.byName(data['issue'] as String) : null,
      route: data['route'] as String,
      group: data['group'] is Map<String, dynamic>
          ? AnalysisReportGroup.fromJson(data['group'] as Map<String, dynamic>)
          : null,
    );
  }
}
