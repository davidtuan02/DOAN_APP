class Project {
  final String id;
  final String name;
  final String description;
  final List<Sprint> sprints;
  final List<Issue> backlog;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.sprints,
    required this.backlog,
  });
}

class Sprint {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final List<Issue> issues;

  Sprint({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.issues,
  });
}

class Issue {
  final String id;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String assignee;

  Issue({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.assignee,
  });
} 