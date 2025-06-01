import 'sprint.dart';
import 'issue.dart';

class Project {
  final String? id;
  final String? name;
  final String? description;
  final String? status;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? ownerId;
  final String accessToken;
  final List<Sprint> sprints;
  final List<Issue> backlog;

  Project({
    this.id,
    this.name,
    this.description,
    this.status,
    this.startDate,
    this.endDate,
    this.ownerId,
    required this.accessToken,
    this.sprints = const [],
    this.backlog = const [],
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      status: json['status'],
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : null,
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      ownerId: json['owner_id'],
      accessToken: json['access_token'] ?? '',
      sprints: (json['sprints'] as List<dynamic>?)?.map((sprintJson) => Sprint.fromJson(sprintJson as Map<String, dynamic>)).toList() ?? [],
      backlog: (json['backlog'] as List<dynamic>?)?.map((issueJson) => Issue.fromJson(issueJson as Map<String, dynamic>)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'status': status,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'owner_id': ownerId,
      'access_token': accessToken,
      'sprints': sprints.map((sprint) => sprint.toJson()).toList(),
      'backlog': backlog.map((issue) => issue.toJson()).toList(),
    };
  }
}

class Sprint {
  final String id;
  final String name;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<Issue> issues;

  Sprint({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.issues,
  });

  factory Sprint.fromJson(Map<String, dynamic> json) {
    return Sprint(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate'] as String) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : null,
      issues: (json['issues'] as List<dynamic>)
          .map((issueJson) => Issue.fromJson(issueJson as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'issues': issues.map((issue) => issue.toJson()).toList(),
    };
  }
}

class Issue {
  final String id;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String assignee;
  final String? type;
  String? sprintId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Issue({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.assignee,
    this.type,
    this.sprintId,
    this.createdAt,
    this.updatedAt,
  });

  factory Issue.fromJson(Map<String, dynamic> json) {
    return Issue(
      id: json['id'] as String? ?? '',
      title: json['taskName'] as String? ?? '',
      description: json['taskDescription'] as String? ?? '',
      status: json['status'] is Map ? (json['status'] as Map)['name'] as String? ?? '' : json['status'] as String? ?? '',
      priority: json['priority'] is Map ? (json['priority'] as Map)['name'] as String? ?? '' : json['priority'] as String? ?? '',
      type: json['type'] is Map ? (json['type'] as Map)['name'] as String? ?? '' : json['type'] as String? ?? '',
      assignee: json['assignee'] is Map ? (json['assignee'] as Map)['name'] as String? ?? '' : json['assignee'] as String? ?? '',
      sprintId: json['sprintId'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskName': title,
      'taskDescription': description,
      'status': status,
      'priority': priority,
      'type': type,
      'assignee': assignee,
      'sprintId': sprintId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
} 