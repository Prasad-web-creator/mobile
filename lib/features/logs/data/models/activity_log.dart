class ActivityLog {
  final String id;
  final String action;
  final String entityType;
  final String? entityId;
  final DateTime createdAt;

  ActivityLog({
    required this.id,
    required this.action,
    required this.entityType,
    this.entityId,
    required this.createdAt,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['_id'] ?? '',
      action: json['action'] ?? '',
      entityType: json['entityType'] ?? '',
      entityId: json['entityId'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt']).toLocal()
          : DateTime.now(),
    );
  }
}

class PaginatedActivityLogs {
  final List<ActivityLog> docs;
  final int totalDocs;
  final int limit;
  final int page;
  final int totalPages;
  final bool hasNextPage;

  PaginatedActivityLogs({
    required this.docs,
    required this.totalDocs,
    required this.limit,
    required this.page,
    required this.totalPages,
    required this.hasNextPage,
  });

  factory PaginatedActivityLogs.fromJson(Map<String, dynamic> json) {
    return PaginatedActivityLogs(
      docs: (json['docs'] as List<dynamic>?)
              ?.map((e) => ActivityLog.fromJson(e))
              .toList() ??
          [],
      totalDocs: json['totalDocs'] ?? 0,
      limit: json['limit'] ?? 10,
      page: json['page'] ?? 1,
      totalPages: json['totalPages'] ?? 1,
      hasNextPage: json['hasNextPage'] ?? false,
    );
  }
}
