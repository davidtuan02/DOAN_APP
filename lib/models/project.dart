class Project {
  final String? id;
  final String? name;
  final String? description;
  List<Sprint> sprints;
  List<Issue> backlog;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.sprints,
    required this.backlog,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      sprints: (json['sprints'] as List<dynamic>?)?.map((sprintJson) => Sprint.fromJson(sprintJson as Map<String, dynamic>)).toList() ?? [],
      backlog: (json['backlog'] as List<dynamic>?)?.map((issueJson) => Issue.fromJson(issueJson as Map<String, dynamic>)).toList() ?? [],
    );
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
}

class Issue {
  final String id;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String assignee;
  final String? type;
  final String? sprintId;

  Issue({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.assignee,
    this.type,
    this.sprintId,
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
    );
  }
} 