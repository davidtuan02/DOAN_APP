import 'package:flutter/material.dart';
import '../models/project.dart';
import '../data/mock_data.dart';
import '../widgets/create_issue_form.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BacklogScreen extends StatefulWidget {
  final String userId;
  final String accessToken;

  const BacklogScreen({Key? key, required this.userId, required this.accessToken}) : super(key: key);

  @override
  State<BacklogScreen> createState() => _BacklogScreenState();
}

class _BacklogScreenState extends State<BacklogScreen> {
  Project? selectedProject;
  List<Project> projects = [];

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    final url = Uri.parse('http://192.168.0.100:8000/api/projects/user/${widget.userId}');
    final headers = {
      'Content-Type': 'application/json',
      'tasks_token': widget.accessToken,
    };

    try {
      final response = await http.get(url, headers: headers);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);
        if (responseData is List<dynamic>) {
          if (!mounted) return;
          setState(() {
            projects = responseData.map((json) => Project.fromJson(json as Map<String, dynamic>)).toList();
            if (projects.isNotEmpty) {
              selectedProject = projects[0];
              // Fetch sprints and issues for the first project
              if (selectedProject?.id != null) {
                _fetchSprintsAndIssues(selectedProject!.id!);
              }
            }
          });
        } else {
          print('API returned an unexpected format: ${responseData.runtimeType}');
          if (!mounted) return;
          setState(() {
            projects = [];
            selectedProject = null;
          });
        }
      } else {
        print('Failed to load projects: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error fetching projects: $e');
    }
  }

  Future<void> _fetchSprintsAndIssues(String projectId) async {
    print('Fetching sprints and issues for project: $projectId');
    if (!mounted) return;
    
    final sprintsUrl = Uri.parse('http://192.168.0.100:8000/api/sprints/project/$projectId');
    final headers = {
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
          List<Sprint> fetchedSprints = [];

          // Process fetched sprints
          for (var sprintJson in sprintsResponseData) {
            if (sprintJson is Map<String, dynamic>) {
              final sprint = Sprint.fromJson(sprintJson);
              fetchedSprints.add(sprint);
            }
          }

          // Fetch all tasks for the project
          final tasksUrl = Uri.parse('http://192.168.0.100:8000/api/tasks/project/$projectId');
          print('Fetching tasks...');
          final tasksResponse = await http.get(tasksUrl, headers: headers);
          print('Tasks response status: ${tasksResponse.statusCode}');
          print('Tasks response body: ${tasksResponse.body}');
          
          if (!mounted) return;

          if (tasksResponse.statusCode == 200) {
            final dynamic tasksResponseData = json.decode(tasksResponse.body);
            if (tasksResponseData is List<dynamic>) {
              List<Issue> allTasks = tasksResponseData.map((issueJson) {
                final issue = Issue.fromJson(issueJson as Map<String, dynamic>);
                // Find the sprint ID from the sprints data
                for (var sprint in fetchedSprints) {
                  if (sprint.issues.any((i) => i.id == issue.id)) {
                    issue.sprintId = sprint.id;
                    break;
                  }
                }
                return issue;
              }).toList();

              List<Issue> backlogIssues = [];
              Map<String, List<Issue>> sprintIssuesMap = {};

              // Separate backlog issues and sprint issues
              for (var task in allTasks) {
                if (task.sprintId == null || task.sprintId!.isEmpty) {
                  backlogIssues.add(task);
                } else {
                  if (!sprintIssuesMap.containsKey(task.sprintId)) {
                    sprintIssuesMap[task.sprintId!] = [];
                  }
                  sprintIssuesMap[task.sprintId!]!.add(task);
                }
              }

              // Assign issues to sprints
              List<Sprint> sprintsWithIssues = [];
              for (var sprint in fetchedSprints) {
                sprintsWithIssues.add(Sprint(
                  id: sprint.id,
                  name: sprint.name,
                  startDate: sprint.startDate,
                  endDate: sprint.endDate,
                  issues: sprintIssuesMap[sprint.id] ?? [],
                ));
              }

              if (!mounted) return;
              setState(() {
                if (selectedProject != null) {
                  selectedProject!.backlog = backlogIssues;
                  selectedProject!.sprints = sprintsWithIssues;
                }
              });
              print('Successfully updated project data');
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching sprints and issues: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to refresh data. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _moveIssue(Issue issue, Sprint? fromSprint, Sprint? toSprint) async {
    try {
      // Call API to update issue's sprint first
      await _updateIssueSprint(issue, toSprint?.id, toSprint);
      
      // After successful API call, refresh the data
      if (mounted && selectedProject?.id != null) {
        await _fetchSprintsAndIssues(selectedProject!.id!);
      }
    } catch (e) {
      print('Error moving issue: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to move issue. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateIssueSprint(Issue issue, String? newSprintId, Sprint? toSprint) async {
    final url = Uri.parse('http://192.168.0.100:8000/api/tasks/${issue.id}/sprint');
    final headers = {
      'Content-Type': 'application/json',
      'tasks_token': widget.accessToken,
    };

    final body = {
      'sprintId': newSprintId,
    };

    print('Updating issue sprint:');
    print('URL: $url');
    print('Headers: $headers');
    print('Body: $body');

    try {
      final response = await http.put(
        url,
        headers: headers,
        body: json.encode(body),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Successfully updated issue sprint');
        // Force refresh data after successful update
        if (mounted && selectedProject?.id != null) {
          await _fetchSprintsAndIssues(selectedProject!.id!);
        }
      } else {
        print('Failed to update issue sprint: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to update issue sprint');
      }
    } catch (e) {
      print('Error updating issue sprint: $e');
      throw e;
    }
  }

  void _showCreateIssueDialog(BuildContext context, Sprint? sprint) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CreateIssueForm(
          sprint: sprint,
          onIssueCreated: (Issue newIssue) {
            if (!mounted) return;
            setState(() {
              if (sprint == null) {
                selectedProject!.backlog.add(newIssue);
              }
              else {
                sprint.issues.add(newIssue);
              }
            });
          },
        );
      },
    );
  }

  void _showIssueDetails(BuildContext context, Issue issue) {
    String selectedStatus = issue.status;
    final List<String> statusOptions = ['CREATED', 'IN_PROGRESS', 'REVIEW', 'DONE'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              child: Container(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            issue.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (issue.description.isNotEmpty) ...[
                      const Text(
                        'Description:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(issue.description),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'Details:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow('ID', issue.id),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(
                              'Status:',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: DropdownButton<String>(
                              value: selectedStatus,
                              isExpanded: true,
                              items: statusOptions.map((String status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                   // This setState is for the dialog's state, not ProjectsScreen
                                   setState(() {
                                      selectedStatus = newValue;
                                   });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildDetailRow('Priority', issue.priority),
                    if (issue.type != null && issue.type!.isNotEmpty)
                      _buildDetailRow('Type', issue.type!),
                    if (issue.assignee.isNotEmpty)
                      _buildDetailRow('Assignee', issue.assignee),
                    if (issue.sprintId != null)
                      _buildDetailRow('Sprint ID', issue.sprintId!),
                    if (issue.createdAt != null)
                      _buildDetailRow('Created At', _formatDateTime(issue.createdAt!)),
                    if (issue.updatedAt != null)
                      _buildDetailRow('Updated At', _formatDateTime(issue.updatedAt!)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            // Add mounted check before calling _updateIssue
                            if (mounted) {
                              await _updateIssue(issue, selectedStatus);
                            }
                          },
                          child: const Text('Save Changes'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateIssue(Issue issue, String newStatus) async {
    final url = Uri.parse('http://192.168.0.100:8000/api/tasks/${issue.id}');
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

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Successfully updated issue');
        if (!mounted) return;
         _fetchSprintsAndIssues(selectedProject!.id!);
      } else {
        print('Failed to update issue: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error updating issue: $e');
    }
  }

  String _formatDateTime(DateTime dateTime) {
    // You can use intl package for more complex formatting if needed
    return '${dateTime.toLocal()}'.split('.')[0]; // Simple formatting
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
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
      case 'High':
        return Colors.red.shade100;
      case 'Medium':
        return Colors.orange.shade100;
      case 'Low':
        return Colors.green.shade100;
      default:
        return Colors.grey.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backlog'),
        elevation: 2,
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: selectedProject == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Project selector
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButton<Project>(
                    value: selectedProject,
                    isExpanded: true,
                    underline: Container(
                      height: 2,
                      color: Theme.of(context).primaryColor,
                    ),
                    items: projects.map((Project project) {
                      return DropdownMenuItem<Project>(
                        value: project,
                        child: Text(
                          project.name ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (Project? newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedProject = newValue;
                        });
                        _fetchSprintsAndIssues(newValue.id!);
                      }
                    },
                  ),
                ),
                // Main content
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Backlog section
                          Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      topRight: Radius.circular(4),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Backlog',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () {
                                          _showCreateIssueDialog(context, null);
                                        },
                                        icon: const Icon(Icons.add),
                                        label: const Text('Create Issue'),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selectedProject!.backlog.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: Text(
                                        'No issues in backlog',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: selectedProject!.backlog.length,
                                    itemBuilder: (context, index) {
                                      final issue = selectedProject!.backlog[index];
                                      return _buildIssueCard(issue, null);
                                    },
                                  ),
                              ],
                            ),
                          ),
                          // Sprints section
                          ...selectedProject!.sprints.map((sprint) {
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(4),
                                        topRight: Radius.circular(4),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                sprint.name,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${sprint.startDate} - ${sprint.endDate}',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: () {
                                            _showCreateIssueDialog(context, sprint);
                                          },
                                          icon: const Icon(Icons.add),
                                          label: const Text('Create Issue'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (sprint.issues.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                        child: Text(
                                          'No issues in this sprint',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: sprint.issues.length,
                                      itemBuilder: (context, index) {
                                        final issue = sprint.issues[index];
                                        return _buildIssueCard(issue, sprint);
                                      },
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildIssueCard(Issue issue, Sprint? sprint) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          issue.title ?? '',
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(issue.description ?? ''),
            const SizedBox(height: 8),
            Row(
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
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(issue.status ?? '').withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    issue.status ?? '',
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
        trailing: PopupMenuButton<String>(
          onSelected: (String? newSprintId) {
            if (newSprintId == null) {
              _moveIssue(issue, sprint, null);
            } else {
              final targetSprint = selectedProject!.sprints.firstWhere(
                (s) => s.id == newSprintId,
                orElse: () => sprint!,
              );
              _moveIssue(issue, sprint, targetSprint);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: null,
              child: Text('Move to Backlog'),
            ),
            ...selectedProject!.sprints.map((s) {
              return PopupMenuItem<String>(
                value: s.id,
                child: Text('Move to ${s.name}'),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
} 