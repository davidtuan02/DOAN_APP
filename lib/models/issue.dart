class Issue {
  final String id;
  String? taskName;
  String? taskDescription;
  int? storyPoints;
  List<String>? labels;
  DateTime? startDate;
  DateTime? dueDate;
  Map<String, dynamic>? reporter;
  String? title;
  String description;
  String status;
  String priority;
  dynamic assignee;
  String? type;
  String? sprintId;
  final DateTime? createdAt;
  DateTime? updatedAt;
  String? boardColumn;

  Issue({
    required this.id,
    this.taskName,
    this.taskDescription,
    this.storyPoints,
    this.labels,
    this.startDate,
    this.dueDate,
    this.reporter,
    this.title,
    this.description = '',
    required this.status,
    required this.priority,
    this.assignee,
    this.type,
    this.sprintId,
    this.createdAt,
    this.updatedAt,
    this.boardColumn,
  });

  factory Issue.fromJson(Map<String, dynamic> json) {
    print('Issue.fromJson input: $json');
    print('Issue id type: ${json['id']?.runtimeType}');
    print('Issue taskName type: ${json['taskName']?.runtimeType}');
    print('Issue sprintId type: ${json['sprintId']?.runtimeType}');
    
    return Issue(
      id: json['id'].toString(),
      taskName: json['taskName'] as String?,
      taskDescription: json['taskDescription'] as String?,
      storyPoints: json['storyPoints'] as int?,
      labels: (json['labels'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate'] as String) : null,
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
      reporter: json['reporter'] as Map<String, dynamic>?,
      title: json['taskName'] as String? ?? '',
      description: json['taskDescription'] as String? ?? '',
      type: json['type'] as String? ?? '',
      priority: json['priority'] as String? ?? '',
      status: json['status'] as String? ?? '',
      sprintId: json['sprintId']?.toString(),
      assignee: json['assignee'] is Map<String, dynamic> ? json['assignee'] as Map<String, dynamic>? : null,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : DateTime.now(),
      boardColumn: json['boardColumn'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskName': taskName ?? title,
      'taskDescription': taskDescription ?? description,
      'storyPoints': storyPoints,
      'labels': labels,
      'startDate': startDate?.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'reporter': reporter,
      'type': type,
      'priority': priority,
      'status': status,
      'sprintId': sprintId,
      'assignee': assignee,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
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