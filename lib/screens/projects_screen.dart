import 'package:flutter/material.dart';
import '../models/project.dart';
import '../data/mock_data.dart';
import '../widgets/create_issue_form.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProjectsScreen extends StatefulWidget {
  final String userId;
  final String accessToken;

  const ProjectsScreen({Key? key, required this.userId, required this.accessToken}) : super(key: key);

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  Project? selectedProject;
  List<Project> projects = [];

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    final url = Uri.parse('http://localhost:8000/api/projects/user/${widget.userId}');
    final headers = {
      'Content-Type': 'application/json',
      'tasks_token': widget.accessToken,
    };

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);
        if (responseData is List<dynamic>) {
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
    setState(() {
      selectedProject?.sprints.clear();
      selectedProject?.backlog.clear();
    });

    final sprintsUrl = Uri.parse('http://localhost:8000/api/sprints/project/$projectId'); // API to fetch sprints for a project
    final headers = {
      'Content-Type': 'application/json',
      'tasks_token': widget.accessToken,
    };

    try {
      final sprintsResponse = await http.get(sprintsUrl, headers: headers);

      if (sprintsResponse.statusCode == 200) {
        print('Raw sprints response body: ${sprintsResponse.body}'); // Log the raw response body
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
                // Handle unexpected item in the sprints list
                print('Unexpected item format in sprints list: ${sprintJson.runtimeType} - Value: $sprintJson');
              }
            }

            // Fetch all tasks for the project
            final tasksUrl = Uri.parse('http://localhost:8000/api/tasks/project/$projectId'); // API to fetch all tasks for a project
            try {
              final tasksResponse = await http.get(tasksUrl, headers: headers);
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
                       issues: sprintIssuesMap[sprint.id] ?? [], // Assign issues for this sprint
                     ));
                   }

                  setState(() {
                    if (selectedProject != null) {
                      selectedProject!.backlog = backlogIssues;
                      selectedProject!.sprints = sprintsWithIssues;
                    }
                  });

                } else {
                  print('API returned unexpected format for tasks list: ${tasksResponseData.runtimeType}');
                  // TODO: Show an error message
                }
              } else {
                print('Failed to load tasks list: ${tasksResponse.statusCode}');
                print('Response body: ${tasksResponse.body}');
                // TODO: Show an error message
              }
            } catch (e) {
              print('Error fetching tasks list: $e');
              // TODO: Show an error message
            }

          } else {
            print('API returned an unexpected format for sprints list: ${sprintsResponseData.runtimeType}');
            // TODO: Show an error message to the user about the unexpected data
          }
        } catch (e) {
          print('Error decoding or processing sprints list: $e');
          // TODO: Show a more specific error message to the user
        }
      } else {
        print('Failed to load sprints list: ${sprintsResponse.statusCode}');
        print('Response body: ${sprintsResponse.body}');
        // TODO: Show an error message to the user
      }
    } catch (e) {
      print('Error fetching sprints list (outer catch): $e');
      // TODO: Show an error message to the user
    }
  }

  void _moveIssue(Issue issue, Sprint? fromSprint, Sprint? toSprint) {
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
    final url = Uri.parse('http://localhost:8000/api/tasks/${issue.id}/sprint');
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

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Successfully updated issue sprint');
      } else {
        print('Failed to update issue sprint: ${response.statusCode}');
        print('Response body: ${response.body}');
        // Revert the UI change if the API call fails
        setState(() {
          if (newSprintId == null) {
            // Moving to backlog failed, move back to original sprint
            selectedProject!.backlog.remove(issue);
            for (var sprint in selectedProject!.sprints) {
              if (sprint.id == issue.sprintId) {
                sprint.issues.add(issue);
                break;
              }
            }
          } else {
            // Moving to sprint failed, move back to original location
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
        // TODO: Show error message to user
      }
    } catch (e) {
      print('Error updating issue sprint: $e');
      // Revert the UI change if the API call fails
      setState(() {
        if (newSprintId == null) {
          // Moving to backlog failed, move back to original sprint
          selectedProject!.backlog.remove(issue);
          for (var sprint in selectedProject!.sprints) {
            if (sprint.id == issue.sprintId) {
              sprint.issues.add(issue);
              break;
            }
          }
        } else {
          // Moving to sprint failed, move back to original location
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
      // TODO: Show error message to user
    }
  }

  void _showCreateIssueDialog(BuildContext context, Sprint? sprint) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CreateIssueForm(
          sprint: sprint,
          onIssueCreated: (Issue newIssue) {
            setState(() {
              if (sprint == null) {
                selectedProject!.backlog.add(newIssue);
              } else {
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
                            await _updateIssue(issue, selectedStatus);
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
    final url = Uri.parse('http://localhost:8000/api/tasks/${issue.id}');
    final headers = {
      'Content-Type': 'application/json',
      'tasks_token': widget.accessToken,
    };

    try {
      final response = await http.put(
        url,
        headers: headers,
        body: json.encode({
          'taskName': issue.title,
          'taskDescription': issue.description,
          'status': newStatus,
          'priority': issue.priority,
          'storyPoints': 0, // TODO: Add story points field to Issue model
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Successfully updated issue');
        // Refresh the sprints and issues list
        if (selectedProject?.id != null) {
          await _fetchSprintsAndIssues(selectedProject!.id!);
        }
      } else {
        print('Failed to update issue: ${response.statusCode}');
        print('Response body: ${response.body}');
        // TODO: Show error message to user
      }
    } catch (e) {
      print('Error updating issue: $e');
      // TODO: Show error message to user
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute}';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
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
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement create new issue
        },
        child: const Icon(Icons.add),
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'done':
        return Colors.green.withOpacity(0.2);
      case 'in progress':
        return Colors.blue.withOpacity(0.2);
      case 'to do':
        return Colors.grey.withOpacity(0.2);
      default:
        return Colors.grey.withOpacity(0.2);
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red.withOpacity(0.2);
      case 'medium':
        return Colors.orange.withOpacity(0.2);
      case 'low':
        return Colors.green.withOpacity(0.2);
      default:
        return Colors.grey.withOpacity(0.2);
    }
  }
} 