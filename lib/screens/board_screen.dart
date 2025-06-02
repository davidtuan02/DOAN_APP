import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/sprint.dart' as sprint_model;
import '../models/issue.dart' as issue_model;
import 'package:http/http.dart' as http;
import 'dart:convert';

enum SprintStatus {
  planning,
  active,
  completed,
}

class BoardScreen extends StatefulWidget {
  final Project project;
  final String accessToken;

  const BoardScreen({
    Key? key,
    required this.project,
    required this.accessToken,
  }) : super(key: key);

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  List<sprint_model.Sprint> _sprints = [];
  sprint_model.Sprint? _selectedSprint;
  List<issue_model.Issue> _issues = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.project.id != null) {
      _fetchSprintsAndIssues(widget.project.id!);
    }
  }

  Future<void> _fetchSprintsAndIssues(String projectId) async {
    print('Fetching sprints and issues for project: $projectId');
    print('Access token being used: ${widget.accessToken}');
    if (!mounted) return;

    final sprintsUrl = Uri.parse('http://192.168.63.1:8000/api/sprints/project/$projectId');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'tasks_token': widget.accessToken,
    };

    try {
      print('Fetching sprints...');
      final sprintsResponse = await http.get(sprintsUrl, headers: headers);
      print('Sprints response status: ${sprintsResponse.statusCode}');
      print('Sprints response body: ${sprintsResponse.body}');

      if (!mounted) return;

      if (sprintsResponse.statusCode == 200) {
        final dynamic sprintsResponseData = json.decode(sprintsResponse.body);

        if (sprintsResponseData is List<dynamic>) {
          List<sprint_model.Sprint> fetchedSprints = [];
          Map<String, String> issueToSprintMap = {};

          // Process fetched sprints
          for (var sprintJson in sprintsResponseData) {
            if (sprintJson is Map<String, dynamic>) {
              try {
                final sprint = sprint_model.Sprint.fromJson(sprintJson);
                fetchedSprints.add(sprint);
                // Map issues to sprint
                if (sprintJson['issues'] != null && sprintJson['issues'] is List) {
                  for (var issue in sprintJson['issues']) {
                    if (issue is Map<String, dynamic> && issue['id'] != null) {
                      issueToSprintMap[issue['id']] = sprint.id;
                    }
                  }
                }
              } catch (e) {
                print('Error parsing sprint: $e');
                print('Problematic sprint JSON: $sprintJson');
              }
            }
          }

          setState(() {
            _sprints = fetchedSprints;
          });

          // Fetch all tasks for the project
          final tasksUrl = Uri.parse('http://192.168.63.1:8000/api/tasks/project/$projectId');
          print('Fetching tasks...');
          final tasksResponse = await http.get(tasksUrl, headers: headers);
          print('Tasks response status: ${tasksResponse.statusCode}');
          print('Tasks response body: ${tasksResponse.body}');
              
          if (!mounted) return;

          if (tasksResponse.statusCode == 200) {
            final dynamic tasksResponseData = json.decode(tasksResponse.body);
            if (tasksResponseData is List<dynamic>) {
              List<issue_model.Issue> allTasks = tasksResponseData.map((issueJson) {
                final issue = issue_model.Issue.fromJson(issueJson as Map<String, dynamic>);
                // Set sprintId based on our mapping
                issue.sprintId = issueToSprintMap[issue.id];
                return issue;
              }).toList();

              // Filter active sprints
              final List<sprint_model.Sprint> activeSprints = fetchedSprints
                  .where((sprint) => sprint.status.toLowerCase() == SprintStatus.active.toString().split('.').last)
                  .toList();

              if (activeSprints.isNotEmpty) {
                setState(() {
                  _selectedSprint = activeSprints.first;
                  _issues = allTasks.where((issue) => issue.sprintId == _selectedSprint?.id).toList();
                });
              }
            }
          }
        }
      }
    } catch (e, stackTrace) {
      print('Error fetching sprints and issues: $e');
      print('Stack trace: $stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleSprintChanged(sprint_model.Sprint? newSprint) {
    if (newSprint != null) {
      setState(() {
        _selectedSprint = newSprint;
      });
      _fetchSprintsAndIssues(widget.project.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _sprints.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _sprints.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _fetchSprintsAndIssues(widget.project.id!);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project.name ?? 'Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_selectedSprint != null) {
                _fetchSprintsAndIssues(widget.project.id!);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Sprint Selector
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<sprint_model.Sprint>(
                  value: _selectedSprint,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down),
                  hint: const Text('Select a sprint'),
                  items: _sprints.map((sprint) {
                    return DropdownMenuItem<sprint_model.Sprint>(
                      value: sprint,
                      child: Text(
                        sprint.name,
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: _handleSprintChanged,
                ),
              ),
            ),
          ),
          // Board Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                _fetchSprintsAndIssues(widget.project.id!);
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _buildBoard(),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    // Group issues by status
    final Map<String, List<issue_model.Issue>> issuesByStatus = {
      'CREATED': [],
      'IN_PROGRESS': [],
      'REVIEW': [],
      'DONE': [],
    };

    for (var issue in _issues) {
      if (issuesByStatus.containsKey(issue.status)) {
        issuesByStatus[issue.status]!.add(issue);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildColumn('Created', issuesByStatus['CREATED']!),
        _buildColumn('In Progress', issuesByStatus['IN_PROGRESS']!),
        _buildColumn('Review', issuesByStatus['REVIEW']!),
        _buildColumn('Done', issuesByStatus['DONE']!),
      ],
    );
  }

  Widget _buildColumn(String title, List<issue_model.Issue> issues) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: issues.length,
                itemBuilder: (context, index) {
                  final issue = issues[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      title: Text(issue.title),
                      subtitle: Text(issue.description),
                      trailing: PopupMenuButton<String>(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                        onSelected: (value) {
                          // TODO: Handle edit/delete
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 