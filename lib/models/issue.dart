class Issue {
  final String id;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String type;
  final String? assignee;
  final String sprintId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Issue({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.type,
    this.assignee,
    required this.sprintId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Issue.fromJson(Map<String, dynamic> json) {
    return Issue(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      status: json['status'],
      priority: json['priority'],
      type: json['type'],
      assignee: json['assignee'],
      sprintId: json['sprint_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'type': type,
      'assignee': assignee,
      'sprint_id': sprintId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
} 