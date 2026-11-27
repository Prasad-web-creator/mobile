class DashboardStats {
  final int totalPolicies;
  final int totalPrescriptions;

  DashboardStats({required this.totalPolicies, required this.totalPrescriptions});

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalPolicies: (json['totalPolicies'] as num?)?.toInt() ?? 0,
      totalPrescriptions: (json['totalPrescriptions'] as num?)?.toInt() ?? 0,
    );
  }
}
