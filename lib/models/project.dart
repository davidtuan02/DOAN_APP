import '../models/sprint.dart';
import '../models/issue.dart';
import '../models/user_project.dart';
import '../models/board.dart';

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
  final String? key;
  final List<UserProject>? usersIncludes;
  final List<Board>? boards;

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
    this.key,
    this.usersIncludes,
    this.boards,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    print('Project.fromJson input: $json');
    print('Project id type: ${json['id']?.runtimeType}');
    print('Project name type: ${json['name']?.runtimeType}');
    print('Project owner_id type: ${json['owner_id']?.runtimeType}');
    
    return Project(
      id: json['id']?.toString(),
      name: json['name'] as String?,
      description: json['description'] as String?,
      status: json['status'] as String?,
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date'] as String) : null,
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
      ownerId: json['owner_id']?.toString(),
      accessToken: json['access_token'] ?? '',
      sprints: (json['sprints'] as List<dynamic>?)?.map((sprintJson) => Sprint.fromJson(sprintJson as Map<String, dynamic>)).toList() ?? [],
      backlog: (json['backlog'] as List<dynamic>?)?.map((issueJson) => Issue.fromJson(issueJson as Map<String, dynamic>)).toList() ?? [],
      key: json['key'] as String?,
      usersIncludes: (json['usersIncludes'] as List<dynamic>?)?.map((e) => UserProject.fromJson(e as Map<String, dynamic>)).toList(),
      boards: (json['boards'] as List<dynamic>?)?.map((e) => Board.fromJson(e as Map<String, dynamic>)).toList(),
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
      'key': key,
      'usersIncludes': usersIncludes?.map((e) => e.toJson()).toList(),
      'boards': boards?.map((e) => e.toJson()).toList(),
    };
  }
}