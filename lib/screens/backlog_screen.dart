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
    final url = Uri.parse('http://192.168.0.101:8000/api/projects/user/${widget.userId}');
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
    // Clear existing sprints and backlog
    if (!mounted) return;
    setState(() {
      selectedProject?.sprints.clear();
      selectedProject?.backlog.clear();
    });

    final sprintsUrl = Uri.parse('http://192.168.0.101:8000/api/sprints/project/$projectId');
    final headers = {
      'Content-Type': 'application/json',
      'tasks_token': widget.accessToken,
    };

    try {
      final sprintsResponse = await http.get(sprintsUrl, headers: headers);

      if (!mounted) return;

      if (sprintsResponse.statusCode == 200) {
        print('Raw sprints response body: ${sprintsResponse.body}');
        try {
          final dynamic sprintsResponseData = json.decode(sprintsResponse.body);

          if (sprintsResponseData is List<dynamic>) {
            List<Sprint> fetchedSprints = [];

            // Process fetched sprints
            for (var sprintJson in sprintsResponseData) {
              if (sprintJson is Map<String, dynamic>) {
                final sprint = Sprint.fromJson(sprintJson);
                fetchedSprints.add(sprint);
              } else {
                print('Unexpected item format in sprints list: ${sprintJson.runtimeType} - Value: $sprintJson');
              }
            }

            // Fetch all tasks for the project
            final tasksUrl = Uri.parse('http://192.168.0.101:8000/api/tasks/project/$projectId');
            try {
              final tasksResponse = await http.get(tasksUrl, headers: headers);
              
              if (!mounted) return;

              if (tasksResponse.statusCode == 200) {
                final dynamic tasksResponseData = json.decode(tasksResponse.body);
                if (tasksResponseData is List<dynamic>) {
                  List<Issue> allTasks = tasksResponseData.map((issueJson) => Issue.fromJson(issueJson as Map<String, dynamic>)).toList();

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

                } else {
                  print('API returned unexpected format for tasks list: ${tasksResponseData.runtimeType}');
                }
              } else {
                print('Failed to load tasks list: ${tasksResponse.statusCode}');
                print('Response body: ${tasksResponse.body}');
              }
            } catch (e) {
              print('Error fetching tasks list: $e');
            }

          } else {
            print('API returned an unexpected format for sprints list: ${sprintsResponseData.runtimeType}');
          }
        } catch (e) {
          print('Error decoding or processing sprints list: $e');
        }
      } else {
        print('Failed to load sprints list: ${sprintsResponse.statusCode}');
        print('Response body: ${sprintsResponse.body}');
      }
    } catch (e) {
      print('Error fetching sprints list (outer catch): $e');
    }
  }

  void _moveIssue(Issue issue, Sprint? fromSprint, Sprint? toSprint) {
    if (!mounted) return;
    setState(() {
      if (fromSprint != null) {
        fromSprint.issues.remove(issue);
      } else {
        selectedProject!.backlog.remove(issue);
      }

      if (toSprint != null) {
        toSprint.issues.add(issue);
      } else {
        selectedProject!.backlog.add(issue);
      }
    });

    // Call API to update issue's sprint
    _updateIssueSprint(issue, toSprint?.id);
  }

  Future<void> _updateIssueSprint(Issue issue, String? newSprintId) async {
    final url = Uri.parse('http://192.168.0.101:8000/api/tasks/${issue.id}/sprint');
    final headers = {
      'Content-Type': 'application/json',
      'tasks_token': widget.accessToken,
    };

    try {
      final response = await http.put(
        url,
        headers: headers,
        body: json.encode({
          'sprintId': newSprintId,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Successfully updated issue sprint');
        if (!mounted) return;
         _fetchSprintsAndIssues(selectedProject!.id!);
      } else {
        print('Failed to update issue sprint: ${response.statusCode}');
        print('Response body: ${response.body}');
        if (!mounted) return;
        setState(() {
          if (newSprintId == null) {
            selectedProject!.backlog.remove(issue);
            for (var sprint in selectedProject!.sprints) {
              if (sprint.id == issue.sprintId) {
                sprint.issues.add(issue);
                break;
              }
            }
          } else {
            for (var sprint in selectedProject!.sprints) {
              if (sprint.id == newSprintId) {
                sprint.issues.remove(issue);
                break;
              }
            }
            if (issue.sprintId == null) {
              selectedProject!.backlog.add(issue);
            } else {
              for (var sprint in selectedProject!.sprints) {
                if (sprint.id == issue.sprintId) {
                  sprint.issues.add(issue);
                  break;
                }
              }
            }
          }
        });
      }
    } catch (e) {
      print('Error updating issue sprint: $e');
      if (!mounted) return;
      setState(() {
        if (newSprintId == null) {
          selectedProject!.backlog.remove(issue);
          for (var sprint in selectedProject!.sprints) {
            if (sprint.id == issue.sprintId) {
              sprint.issues.add(issue);
              break;
            }
          }
        } else {
          for (var sprint in selectedProject!.sprints) {
            if (sprint.id == newSprintId) {
              sprint.issues.remove(issue);
              break;
            }
          }
          if (issue.sprintId == null) {
            selectedProject!.backlog.add(issue);
          } else {
            for (var sprint in selectedProject!.sprints) {
              if (sprint.id == issue.sprintId) {
                sprint.issues.add(issue);
                break;
              }
            }
          }
        }
      });
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
    final url = Uri.parse('http://192.168.0.101:8000/api/tasks/${issue.id}');
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
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Implement create new project
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Project Dropdown
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<Project>(
              value: selectedProject,
              decoration: const InputDecoration(
                labelText: 'Select Project',
                border: OutlineInputBorder(),
              ),
              items: projects.map((Project project) {
                return DropdownMenuItem<Project>(
                  value: project,
                  child: Text(project.name ?? ''),
                );
              }).toList(),
              onChanged: (Project? newValue) {
                if (!mounted) return;
                setState(() {
                  selectedProject = newValue;
                });
                if (newValue != null) {
                  if (newValue.id != null) {
                    _fetchSprintsAndIssues(newValue.id!);
                  } else {
                    // Handle case where selected project has a null ID (optional)
                    print('Selected project has a null ID.');
                  }
                }
              },
            ),
          ),

          // Kanban Board
          Expanded(
            child: selectedProject == null
                ? const Center(child: Text('Please select a project'))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Backlog Column
                        _buildColumn(
                          'Backlog',
                          selectedProject!.backlog,
                          null,
                        ),
                        // Sprint Columns
                        ...selectedProject!.sprints.map(
                          (sprint) => _buildColumn(
                            sprint.name,
                            sprint.issues,
                            sprint,
                          ),
                        ),
                      ]
                    ),
                  ),
          ),
        ]
      ),
    );
  }

  Widget _buildColumn(String title, List<Issue> issues, Sprint? sprint) {
    return Container(
      width: 300,
      margin: const EdgeInsets.all(8),
      child: Card(
        child: ExpansionTile(
          title: Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[200],
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${issues.length})',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    // TODO: Implement add issue to this section
                    _showCreateIssueDialog(context, sprint);
                  },
                ),
              ],
            ),
          ),
          children: [
            DragTarget<Issue>(
              onWillAccept: (issue) => true,
              onAccept: (issue) {
                // Find the source sprint
                Sprint? sourceSprint;
                for (var s in selectedProject!.sprints) {
                  if (s.issues.contains(issue)) {
                    sourceSprint = s;
                    break;
                  }
                }
                _moveIssue(issue, sourceSprint, sprint);
              },
              builder: (context, candidateItems, rejectedItems) {
                return ReorderableListView.builder(
                  shrinkWrap: true,
                  itemCount: issues.length,
                  onReorder: (oldIndex, newIndex) {
                    if (!mounted) return; 
                    setState(() {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final item = issues.removeAt(oldIndex);
                      issues.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final issue = issues[index];
                    return Draggable<Issue>(
                      key: ValueKey(issue.id),
                      data: issue,
                      feedback: Material(
                        elevation: 4,
                        child: Container(
                          width: 280,
                          padding: const EdgeInsets.all(8),
                          color: Colors.white,
                          child: Text(issue.title ?? ''),
                        ),
                      ),
                      childWhenDragging: Container(
                        height: 60,
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: Card(
                        margin: const EdgeInsets.all(4),
                        child: InkWell(
                          onTap: () => _showIssueDetails(context, issue),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  issue.title ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (issue.description != null && issue.description!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      issue.description!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      if (issue.type != null && issue.type!.isNotEmpty)
                                         Chip(
                                           label: Text(issue.type!),
                                           visualDensity: VisualDensity.compact,
                                         ),
                                      Chip(
                                        label: Text(issue.status ?? ''),
                                        backgroundColor: _getStatusColor(issue.status ?? ''),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      Chip(
                                        label: Text(issue.priority ?? ''),
                                        backgroundColor: _getPriorityColor(issue.priority ?? ''),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      // TODO: Add assignee display
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
} 