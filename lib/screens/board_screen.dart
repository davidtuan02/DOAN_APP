import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/sprint.dart' as sprint_model;
import '../models/issue.dart' as issue_model;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

// Global API configuration
// const String baseUrl = 'http://192.168.63.1:8000/api';

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

  @override
  void didUpdateWidget(BoardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.project.id != oldWidget.project.id) {
      _fetchSprintsAndIssues(widget.project.id!);
    }
  }

  Future<void> _fetchSprintsAndIssues(String projectId) async {
    print('Fetching sprints and issues for project: $projectId');
    print('Access token being used: ${widget.accessToken}');
    if (!mounted) return;

    final sprintsUrl = Uri.parse('$baseUrl/sprints/project/$projectId');
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
                      print('Mapped issue ${issue['id']} to sprint ${sprint.id}');
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
          final tasksUrl = Uri.parse('$baseUrl/tasks/project/$projectId');
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
                print('Issue ${issue.id} mapped to sprint ${issue.sprintId}');
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
                  print('Selected sprint: ${_selectedSprint?.id}');
                  print('Found ${_issues.length} issues for selected sprint');
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

  void _handleSprintChanged(sprint_model.Sprint? newSprint) async {
    if (newSprint != null) {
      setState(() {
        _selectedSprint = newSprint;
        _isLoading = true;
        _issues = []; // Clear current issues
      });
      
      try {
        // Fetch all tasks for the project
        final tasksUrl = Uri.parse('$baseUrl/tasks/project/${widget.project.id}');
        final headers = <String, String>{
          'Content-Type': 'application/json',
          'tasks_token': widget.accessToken,
        };

        print('Fetching tasks for sprint: ${newSprint.id}');
        print('Sprint name: ${newSprint.name}');
        final tasksResponse = await http.get(tasksUrl, headers: headers);
        if (!mounted) return;

        if (tasksResponse.statusCode == 200) {
          final dynamic tasksResponseData = json.decode(tasksResponse.body);
          print('Raw tasks response: $tasksResponseData');
          
          if (tasksResponseData is List<dynamic>) {
            // First, get the sprint's issues mapping
            final sprintUrl = Uri.parse('$baseUrl/sprints/${newSprint.id}');
            final sprintResponse = await http.get(sprintUrl, headers: headers);
            Map<String, String> issueToSprintMap = {};
            
            if (sprintResponse.statusCode == 200) {
              final sprintData = json.decode(sprintResponse.body);
              if (sprintData['issues'] != null && sprintData['issues'] is List) {
                for (var issue in sprintData['issues']) {
                  if (issue is Map<String, dynamic> && issue['id'] != null) {
                    issueToSprintMap[issue['id']] = newSprint.id;
                    print('Mapped issue ${issue['id']} to sprint ${newSprint.id}');
                  }
                }
              }
            }

            List<issue_model.Issue> allTasks = tasksResponseData.map((issueJson) {
              print('Processing issue: $issueJson');
              final issue = issue_model.Issue.fromJson(issueJson as Map<String, dynamic>);
              // Set sprintId based on our mapping
              issue.sprintId = issueToSprintMap[issue.id];
              print('Issue ${issue.id} mapped to sprint ${issue.sprintId}');
              return issue;
            }).toList();

            // Filter tasks for the selected sprint
            final sprintTasks = allTasks.where((issue) {
              final matches = issue.sprintId == newSprint.id;
              print('Issue ${issue.id} - sprintId: ${issue.sprintId}, matches: $matches');
              return matches;
            }).toList();
            
            print('Found ${sprintTasks.length} tasks for sprint ${newSprint.id}');
            print('Sprint tasks: ${sprintTasks.map((t) => '${t.id}: ${t.title}').join('\n')}');

            setState(() {
              _issues = sprintTasks;
              _isLoading = false;
              _error = null;
            });
          }
        } else {
          print('Failed to load tasks: ${tasksResponse.statusCode}');
          print('Response body: ${tasksResponse.body}');
          setState(() {
            _error = 'Failed to load tasks: ${tasksResponse.statusCode}';
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error fetching tasks: $e');
        if (!mounted) return;
        setState(() {
          _error = 'Failed to load tasks: ${e.toString()}';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load tasks: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                              onPressed: () => _handleSprintChanged(_selectedSprint),
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _handleSprintChanged(_selectedSprint),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Group issues by status
    final Map<String, List<issue_model.Issue>> issuesByStatus = {
      'TO_DO': [],
      'IN_PROGRESS': [],
      'REVIEW': [],
      'DONE': [],
    };

    for (var issue in _issues) {
      if (issue.status == 'CREATED') {
        issuesByStatus['TO_DO']!.add(issue);
      } else if (issuesByStatus.containsKey(issue.status)) {
        issuesByStatus[issue.status]!.add(issue);
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildColumn('TO DO', issuesByStatus['TO_DO']!, 'CREATED'),
          _buildColumn('IN PROGRESS', issuesByStatus['IN_PROGRESS']!, 'IN_PROGRESS'),
          _buildColumn('REVIEW', issuesByStatus['REVIEW']!, 'REVIEW'),
          _buildColumn('DONE', issuesByStatus['DONE']!, 'DONE'),
        ],
      ),
    );
  }

  Widget _buildColumn(String title, List<issue_model.Issue> issues, String status) {
    return DragTarget<issue_model.Issue>(
      onWillAccept: (issue) => issue != null,
      onAccept: (issue) => _handleIssueDrop(issue, status),
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: MediaQuery.of(context).size.width * 0.8,
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
                      return Draggable<issue_model.Issue>(
                        data: issue,
                        feedback: Material(
                          elevation: 4,
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.7,
                            child: Card(
                              child: ListTile(
                                title: Text(issue.title),
                                subtitle: Text(issue.description),
                              ),
                            ),
                          ),
                        ),
                        childWhenDragging: Container(
                          height: 0,
                        ),
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: ListTile(
                            title: Text(
                              issue.title,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  issue.description,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getPriorityColor(issue.priority).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        issue.priority,
                                        style: TextStyle(
                                          color: _getPriorityColor(issue.priority),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(issue.status).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        issue.type,
                                        style: TextStyle(
                                          color: _getStatusColor(issue.status),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () {
                              // TODO: Show issue details
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
      },
    );
  }

  Future<void> _handleIssueDrop(issue_model.Issue issue, String newStatus) async {
    if (issue.status == newStatus) {
      print('Issue ${issue.id} already in status $newStatus. No update needed.');
      return;
    }

    print('Attempting to update status for Issue ${issue.id} to $newStatus');

    setState(() {
      // Optional: Show a loading indicator or temporarily move the issue in the UI
      // This requires more complex state management and might be added later if needed.
      // For now, we rely on the full refresh after the API call.
    });

    try {
      // Use the general update issue endpoint
      final url = Uri.parse('$baseUrl/tasks/${issue.id}');
      final headers = {
        'Content-Type': 'application/json',
        'tasks_token': widget.accessToken,
      };

      // Create an updated issue object with the new status
      final updatedIssue = issue.copyWith(status: newStatus);

      final body = json.encode(updatedIssue.toJson());

      print('PUT Request URL: $url');
      print('Request Headers: $headers');
      print('Request Body: $body');

      final response = await http.put(
        url,
        headers: headers,
        body: body,
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) { // Check for 200 or 201
        print('Issue status updated successfully on server');
        // Refresh the entire list to ensure UI consistency
        _handleSprintChanged(_selectedSprint); // Re-fetch and filter issues for the current sprint

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Issue status updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('Failed to update issue status: ${response.statusCode}');
        print('Response body: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update issue status: ${response.statusCode}. ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
        // If update failed, you might want to revert the UI change if you implemented one
      }
    } catch (e) {
      print('Error updating issue status: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating issue status: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      // If update failed, you might want to revert the UI change if you implemented one
    } finally {
       // Optional: Hide loading indicator
       // setState(() { _isLoading = false; }); // Ensure this is handled correctly with _handleSprintChanged loading
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'CREATED':
      case 'TO_DO':
        return Colors.blue.shade100;
      case 'IN_PROGRESS':
        return Colors.orange.shade100;
      case 'REVIEW':
        return Colors.purple.shade100;
      case 'DONE':
        return Colors.green.shade100;
      default:
        return Colors.grey.shade300;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'HIGHEST':
        return Colors.red.shade100;
      case 'HIGH':
        return Colors.red.shade100;
      case 'Medium':
        return Colors.orange.shade100;
      case 'Low':
        return Colors.green.shade100;
      default:
        return Colors.grey.shade300;
    }
  }
} 