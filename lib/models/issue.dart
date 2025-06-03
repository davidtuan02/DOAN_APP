class Issue {
  final String id;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String type;
  final Map<String, dynamic>? assignee;
  String? sprintId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int storyPoints;
  final List<String> labels;
  final DateTime? startDate;
  final DateTime? dueDate;
  final Map<String, dynamic>? reporter;
  final String? boardColumn;

  Issue({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.type,
    this.assignee,
    this.sprintId,
    required this.createdAt,
    required this.updatedAt,
    this.storyPoints = 0,
    this.labels = const [],
    this.startDate,
    this.dueDate,
    this.reporter,
    this.boardColumn,
  });

  factory Issue.fromJson(Map<String, dynamic> json) {
    return Issue(
      id: json['id'] as String,
      title: json['taskName'] as String? ?? '',
      description: json['taskDescription'] as String? ?? '',
      type: json['type'] as String? ?? '',
      priority: json['priority'] as String? ?? '',
      status: json['status'] as String? ?? '',
      sprintId: json['sprintId'] as String?,
      assignee: json['assignee'] as Map<String, dynamic>?,
      reporter: json['reporter'] as Map<String, dynamic>?,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : DateTime.now(),
      storyPoints: json['storyPoints'] as int? ?? 0,
      labels: (json['labels'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate'] as String) : null,
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
      boardColumn: json['boardColumn'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskName': title,
      'taskDescription': description,
      'type': type,
      'priority': priority,
      'status': status,
      'sprintId': sprintId,
      'assignee': assignee,
      'reporter': reporter,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'storyPoints': storyPoints,
      'labels': labels,
      'startDate': startDate?.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'boardColumn': boardColumn,
    };
  }

  Issue copyWith({
    String? id,
    String? title,
    String? description,
    String? type,
    String? priority,
    String? status,
    String? sprintId,
    Map<String, dynamic>? assignee,
    Map<String, dynamic>? reporter,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? storyPoints,
    List<String>? labels,
    DateTime? startDate,
    DateTime? dueDate,
    String? boardColumn,
  }) {
    return Issue(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      sprintId: sprintId ?? this.sprintId,
      assignee: assignee ?? this.assignee,
      reporter: reporter ?? this.reporter,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      storyPoints: storyPoints ?? this.storyPoints,
      labels: labels ?? this.labels,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      boardColumn: boardColumn ?? this.boardColumn,
    );
  }
} 