import 'issue.dart';

class Sprint {
  final String id;
  final String name;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? goal;
  final List<Issue> issues;

  Sprint({
    required this.id,
    required this.name,
    required this.status,
    this.startDate,
    this.endDate,
    this.goal,
    this.issues = const [],
  });

  factory Sprint.fromJson(Map<String, dynamic> json) {
    return Sprint(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? '',
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate'] as String) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : null,
      goal: json['goal'] as String?,
      issues: (json['issues'] as List<dynamic>?)?.map((issueJson) => Issue.fromJson(issueJson as Map<String, dynamic>)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'goal': goal,
      'issues': issues.map((issue) => issue.toJson()).toList(),
    };
  }
} 