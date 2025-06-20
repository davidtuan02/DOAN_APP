import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/sprint.dart' as sprint_model;
import '../models/issue.dart' as issue_model;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import '../globale.dart' as globals;

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

        for (var sprintJson in sprintsResponseData) {
          if (sprintJson is Map<String, dynamic>) {
            try {
              final sprint = sprint_model.Sprint.fromJson(sprintJson);
              fetchedSprints.add(sprint);
              if (sprintJson['issues'] != null && sprintJson['issues'] is List) {
                for (var issue in sprintJson['issues']) {
                  if (issue is Map<String, dynamic> && issue['id'] != null) {
                    issueToSprintMap[issue['id']] = sprint.id;
                  }
                }
              }
            } catch (e) {
              print('Error parsing sprint: $e');
            }
          }
        }

        setState(() {
          _sprints = fetchedSprints;
          // Synchronize _selectedSprint with the new list
          if (_sprints.isNotEmpty) {
            if (_selectedSprint != null) {
              final matchingSprint = _sprints.firstWhere(
                (s) => s.id == _selectedSprint!.id,
                orElse: () => _sprints.first, // Default to first sprint if no match
              );
              _selectedSprint = matchingSprint;
            } else {
              _selectedSprint = _sprints.firstWhere(
                (s) => s.status.toLowerCase() == 'active'.toLowerCase(),
                orElse: () => _sprints.first, // Default to first sprint if no active
              );
            }
          } else {
            _selectedSprint = null; // No sprints available
          }
          // Update _issues based on the new _selectedSprint
          _issues = _selectedSprint != null ? _issues.where((i) => i.sprintId == _selectedSprint!.id).toList() : [];
        });

        // Fetch tasks
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
              issue.sprintId = issueToSprintMap[issue.id];
              return issue;
            }).toList();

            for (var sprint in fetchedSprints) {
              sprint.issues.clear();
            }

            for (var task in allTasks) {
              if (task.sprintId != null) {
                try {
                  final targetSprint = fetchedSprints.firstWhere(
                    (s) => s.id == task.sprintId,
                  ); // Throws StateError if not found, handled by try-catch
                  targetSprint.issues.add(task);
                } catch (e) {
                  if (e is StateError) {
                    print('No matching sprint found for task ${task.id} with sprintId ${task.sprintId}');
                  } else {
                    print('Error processing task ${task.id}: $e');
                  }
                }
              }
            }

            final List<sprint_model.Sprint> activeSprints = fetchedSprints
                .where((sprint) => sprint.status.toLowerCase() == SprintStatus.active.toString().split('.').last)
                .toList();

            if (activeSprints.isNotEmpty && _selectedSprint == null) {
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
          // Sprint Selector and Actions
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
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
                // Complete Sprint Button (visible only for active sprints and MANAGER role)
                if (globals.isManager && 
                    _selectedSprint != null && 
                    _selectedSprint!.status.toLowerCase() == 'active')
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        _showCompleteSprintDialog(context, _selectedSprint!);
                      },
                      child: const Text('Complete Sprint'),
                    ),
                  ),
                // Start Sprint Button (visible only for planning sprints and MANAGER role)
                if (globals.isManager && 
                    _selectedSprint != null && 
                    _selectedSprint!.status.toLowerCase() == 'planning')
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        _showStartSprintDialog(context, _selectedSprint!);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Start Sprint'),
                    ),
                  ),
              ],
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
    final bool isSprintActive = _selectedSprint?.status.toLowerCase() == 'active';
    
    return DragTarget<issue_model.Issue>(
      onWillAccept: (issue) => isSprintActive && issue != null,
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
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!isSprintActive)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Icon(
                            Icons.lock_outline,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: issues.length,
                    itemBuilder: (context, index) {
                      final issue = issues[index];
                      return isSprintActive
                          ? Draggable<issue_model.Issue>(
                              data: issue,
                              feedback: Material(
                                elevation: 4,
                                child: Container(
                                  width: MediaQuery.of(context).size.width * 0.7,
                                  child: Card(
                                    child: ListTile(
                                      title: Text(issue.title ?? ''),
                                      subtitle: Text(issue.description ?? ''),
                                    ),
                                  ),
                                ),
                              ),
                              childWhenDragging: Container(
                                height: 0,
                              ),
                              child: _buildIssueCard(issue),
                            )
                          : _buildIssueCard(issue);
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

  Widget _buildIssueCard(issue_model.Issue issue) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(
          issue.title ?? '',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              issue.description ?? '',
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
                    color: _getPriorityColor(issue.priority ?? '').withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    issue.priority ?? '',
                    style: TextStyle(
                      color: _getPriorityColor(issue.priority ?? ''),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(issue.status ?? '').withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    issue.type ?? '',
                    style: TextStyle(
                      color: _getStatusColor(issue.status ?? ''),
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
    );
  }

  Future<void> _handleIssueDrop(issue_model.Issue issue, String targetStatus) async {
    print('Issue ${issue.id} dropped into column with status: $targetStatus');
    // Update status via API
    try {
      await _updateIssueStatus(issue, targetStatus);
      // Refresh issues after successful update
      if (_selectedSprint != null) {
        _handleSprintChanged(_selectedSprint!);
      } else {
        // Handle case where no sprint is selected? Maybe this shouldn't happen on the Board screen.
        // If issues are shown without a selected sprint, we might need a different refresh logic.
      }
    } catch (e) {
      print('Error updating issue status: $e');
      // Optionally show a snackbar or revert UI change
    }
  }

  Future<void> _updateIssueStatus(issue_model.Issue issue, String newStatus) async {
    final url = Uri.parse('$baseUrl/tasks/${issue.id}');
    final headers = {
      'Content-Type': 'application/json',
      'tasks_token': widget.accessToken,
    };

    try {
      final response = await http.put(
        url,
        headers: headers,
        body: json.encode({
          'status': newStatus,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        print('Successfully updated issue status');
        // Update local issue status immediately for better responsiveness
        setState(() {
          issue.status = newStatus; // Assuming issue.status is not final
        });
      } else {
        print('Failed to update issue status: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to update issue status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating issue status API: $e');
      rethrow; // Re-throw to be caught by _handleIssueDrop
    }
  }

  void _showCompleteSprintDialog(BuildContext context, sprint_model.Sprint sprint) {
    // Calculate based on the currently displayed issues (_issues list), which reflects recent drag-and-drop updates
    final completedTasks = _issues.where((issue) => issue.status == 'DONE').length;
    final incompleteTasks = _issues.length - completedTasks;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Complete Sprint: ${sprint.name}'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Goal: ${sprint.goal ?? "No goal set"}'),
                const SizedBox(height: 16),
                Text('Completed Tasks: $completedTasks'),
                Text('Incomplete Tasks: $incompleteTasks'),
                const SizedBox(height: 16),
                const Text('Completing this sprint will move incomplete issues to the backlog.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Complete'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _completeSprint(sprint.id);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _completeSprint(String sprintId) async {
  print('Attempting to complete sprint: $sprintId');
  final url = Uri.parse('$baseUrl/sprints/$sprintId/complete');
  final headers = {
    'Content-Type': 'application/json',
    'tasks_token': widget.accessToken,
  };

  try {
    final response = await http.put(url, headers: headers);

    if (!mounted) return;

    if (response.statusCode == 200) {
      print('Successfully completed sprint via API');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sprint completed successfully'),
          backgroundColor: Colors.green,
        ),
      );
      // Refresh data and reset selected sprint if needed
      await _fetchSprintsAndIssues(widget.project.id!);
    } else {
      print('Failed to complete sprint: ${response.statusCode}');
      print('Response body: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to complete sprint: ${response.statusCode}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    print('Error completing sprint: $e');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error completing sprint: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  void _showStartSprintDialog(BuildContext context, sprint_model.Sprint sprint) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Start Sprint: ${sprint.name}'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Goal: ${sprint.goal ?? "No goal set"}'),
                const SizedBox(height: 16),
                Text('Total Tasks: ${sprint.issues.length}'),
                const SizedBox(height: 16),
                const Text('Starting this sprint will make it active and allow task movement.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Start'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _startSprint(sprint.id);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _startSprint(String sprintId) async {
    print('Attempting to start sprint: $sprintId');
    final url = Uri.parse('$baseUrl/sprints/$sprintId/start');
    final headers = {
      'Content-Type': 'application/json',
      'tasks_token': widget.accessToken,
    };

    try {
      final response = await http.put(
        url,
        headers: headers,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        print('Successfully started sprint via API');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sprint started successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchSprintsAndIssues(widget.project.id!);
      } else {
        print('Failed to start sprint: ${response.statusCode}');
        print('Response body: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start sprint: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error starting sprint: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting sprint: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'CREATED':
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
      case 'Highest':
        return Colors.red.shade700;
      case 'High':
        return Colors.red.shade400;
      case 'Medium':
        return Colors.orange.shade400;
      case 'Low':
        return Colors.green.shade400;
      case 'Lowest':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade300;
    }
  }
} 