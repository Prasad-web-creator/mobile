enum CheckStatusKind {
  covered,
  partial,
  notCovered,
  verification,
  other,
  checking,
  failed;

  String? get coverageLabel => switch (this) {
    covered => 'Fully covered',
    partial => 'Partially covered',
    notCovered => 'Not covered',
    verification => 'Needs verification',
    _ => null,
  };
}
