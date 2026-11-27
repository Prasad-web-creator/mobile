import 'package:claimsupport/features/analysis/data/models/multi_analysis_session.dart';
import 'package:claimsupport/features/analysis/data/repositories/analysis_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a resumed queued job shows requested policy rows', () {
    final data = AnalysisRepository.jobSession({
      'id': 'job',
      'status': 'queued',
      'policyIds': ['p1', 'p2'],
    });
    final session = MultiAnalysisSession.fromJson(data);
    expect(session.sessionId, 'job');
    expect(session.canCancel, isTrue);
    expect(session.isWorking, isTrue);
    expect(session.policyAnalyses.map((row) => row.policyId), ['p1', 'p2']);
  });

  test('reanalyzing an answered policy suppresses only that old question', () {
    final data = AnalysisRepository.jobSession({
      'id': 'job',
      'status': 'reanalyzing',
      'activePolicyId': 'p1',
      'result': {
        'status': 'waiting_for_user',
        'policyAnalyses': [
          {'policyId': 'p1', 'status': 'waiting_for_user', 'questions': [{'id': 'date'}]},
          {'policyId': 'p2', 'status': 'waiting_for_user', 'questions': [{'id': 'member'}]},
        ],
      },
    });
    final session = MultiAnalysisSession.fromJson(data);
    expect(session.isWorking, isTrue);
    expect(session.policyAnalyses.first.questions, isEmpty);
    expect(session.pendingClarification?.policyId, 'p2');
  });

  test('expired jobs stop polling and explain how to continue', () {
    final session = MultiAnalysisSession.fromJson(AnalysisRepository.jobSession({
      'id': 'job',
      'status': 'expired',
    }));
    expect(session.isWorking, isFalse);
    expect(session.errorMessage, contains('expired'));
  });
}
