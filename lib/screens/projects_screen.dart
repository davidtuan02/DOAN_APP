import 'package:flutter/material.dart';
import '../models/project.dart';
import '../data/mock_data.dart';
import '../widgets/create_issue_form.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProjectsScreen extends StatefulWidget {
  final String userId;
  final String accessToken;
  final Function(Project)? onProjectSelected;

  const ProjectsScreen({Key? key, required this.userId, required this.accessToken, this.onProjectSelected}) : super(key: key);

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
    // Clear existing sprints and backlog
    if (!mounted) return;
    setState(() {
      print('Clearing existing sprints and backlog');
      selectedProject?.sprints.clear();
      selectedProject?.backlog.clear();
    });

    final sprintsUrl = Uri.parse('http://192.168.0.100:8000/api/sprints/project/$projectId');
    final headers = {
      'Content-Type': 'application/json',
      'tasks_token': widget.accessToken,
    };

    try {
      print('Fetching sprints...');
      final sprintsResponse = await http.get(sprintsUrl, headers: headers);

      if (!mounted) return;

      if (sprintsResponse.statusCode == 200) {
        print('Sprints response received: ${sprintsResponse.body}');
        try {
          final dynamic sprintsResponseData = json.decode(sprintsResponse.body);

          if (sprintsResponseData is List<dynamic>) {
            List<Sprint> fetchedSprints = [];

            // Process fetched sprints
            for (var sprintJson in sprintsResponseData) {
              if (sprintJson is Map<String, dynamic>) {
                final sprint = Sprint.fromJson(sprintJson);
                fetchedSprints.add(sprint);
                print('Added sprint: ${sprint.name} with ${sprint.issues.length} issues');
              }
            }

            // Fetch all tasks for the project
            print('Fetching tasks...');
            final tasksUrl = Uri.parse('http://192.168.0.100:8000/api/tasks/project/$projectId');
            try {
              final tasksResponse = await http.get(tasksUrl, headers: headers);
              
              if (!mounted) return;

              if (tasksResponse.statusCode == 200) {
                print('Tasks response received: ${tasksResponse.body}');
                final dynamic tasksResponseData = json.decode(tasksResponse.body);
                if (tasksResponseData is List<dynamic>) {
                  List<Issue> allTasks = tasksResponseData.map((issueJson) => Issue.fromJson(issueJson as Map<String, dynamic>)).toList();
                  print('Total tasks fetched: ${allTasks.length}');

                  List<Issue> backlogIssues = [];
                  Map<String, List<Issue>> sprintIssuesMap = {};

                  // Separate backlog issues and sprint issues
                  for (var task in allTasks) {
                    if (task.sprintId == null || task.sprintId!.isEmpty) {
                      backlogIssues.add(task);
                      print('Added to backlog: ${task.title}');
                    } else {
                      if (!sprintIssuesMap.containsKey(task.sprintId)) {
                        sprintIssuesMap[task.sprintId!] = [];
                      }
                      sprintIssuesMap[task.sprintId!]!.add(task);
                      print('Added to sprint ${task.sprintId}: ${task.title}');
                    }
                  }

                  // Assign issues to sprints
                  List<Sprint> sprintsWithIssues = [];
                  for (var sprint in fetchedSprints) {
                    final sprintIssues = sprintIssuesMap[sprint.id] ?? [];
                    sprintsWithIssues.add(Sprint(
                      id: sprint.id,
                      name: sprint.name,
                      startDate: sprint.startDate,
                      endDate: sprint.endDate,
                      issues: sprintIssues,
                    ));
                    print('Sprint ${sprint.name} has ${sprintIssues.length} issues');
                  }

                  if (!mounted) return;
                  print('Updating UI with new data...');
                  setState(() {
                    if (selectedProject != null) {
                      selectedProject!.backlog = backlogIssues;
                      selectedProject!.sprints = sprintsWithIssues;
                      print('UI updated - Backlog: ${backlogIssues.length} issues, Sprints: ${sprintsWithIssues.length}');
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
      print('Error fetching sprints list: $e');
    }
  }

  void _moveIssue(Issue issue, Sprint? fromSprint, Sprint? toSprint) {
    print('Moving issue: ${issue.title}');
    print('From sprint: ${fromSprint?.name ?? 'Backlog'}');
    print('To sprint: ${toSprint?.name ?? 'Backlog'}');

    if (!mounted) return;
    setState(() {
      if (fromSprint != null) {
        fromSprint.issues.remove(issue);
        print('Removed from sprint ${fromSprint.name}');
      } else {
        selectedProject!.backlog.remove(issue);
        print('Removed from backlog');
      }

      if (toSprint != null) {
        toSprint.issues.add(issue);
        print('Added to sprint ${toSprint.name}');
      } else {
        selectedProject!.backlog.add(issue);
        print('Added to backlog');
      }
    });

    // Call API to update issue's sprint
    _updateIssueSprint(issue, toSprint?.id);
  }

  Future<void> _updateIssueSprint(Issue issue, String? newSprintId) async {
    print('Updating issue sprint...');
    print('Issue: ${issue.title}');
    print('New sprint ID: $newSprintId');

    final url = Uri.parse('http://192.168.0.100:8000/api/tasks/${issue.id}/sprint');
    final headers = {
      'Content-Type': 'application/json',
      'tasks_token': widget.accessToken,
    };

    try {
      print('Sending API request...');
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
        print('Response body: ${response.body}');
        // After successful update, refetch data to ensure UI is consistent
        if (!mounted) return;
        print('Refreshing data...');
        _fetchSprintsAndIssues(selectedProject!.id!);
      } else {
        print('Failed to update issue sprint: ${response.statusCode}');
        print('Response body: ${response.body}');
        // Revert the UI change if the API call fails
        if (!mounted) return;
        setState(() {
          if (newSprintId == null) {
            // Moving to backlog failed, move back to original sprint
            selectedProject!.backlog.remove(issue);
            for (var sprint in selectedProject!.sprints) {
              if (sprint.id == issue.sprintId) {
                sprint.issues.add(issue);
                print('Reverted: Moved back to sprint ${sprint.name}');
                break;
              }
            }
          } else {
            // Moving to sprint failed, move back to original location
            for (var sprint in selectedProject!.sprints) {
              if (sprint.id == newSprintId) {
                sprint.issues.remove(issue);
                print('Reverted: Removed from sprint ${sprint.name}');
                break;
              }
            }
            if (issue.sprintId == null) {
              selectedProject!.backlog.add(issue);
              print('Reverted: Moved back to backlog');
            } else {
              for (var sprint in selectedProject!.sprints) {
                if (sprint.id == issue.sprintId) {
                  sprint.issues.add(issue);
                  print('Reverted: Moved back to sprint ${sprint.name}');
                  break;
                }
              }
            }
          }
        });
      }
    } catch (e) {
      print('Error updating issue sprint: $e');
      // Revert the UI change if the API call fails
      if (!mounted) return;
      setState(() {
        if (newSprintId == null) {
          // Moving to backlog failed, move back to original sprint
          selectedProject!.backlog.remove(issue);
          for (var sprint in selectedProject!.sprints) {
            if (sprint.id == issue.sprintId) {
              sprint.issues.add(issue);
              print('Error recovery: Moved back to sprint ${sprint.name}');
              break;
            }
          }
        } else {
          // Moving to sprint failed, move back to original location
          for (var sprint in selectedProject!.sprints) {
            if (sprint.id == newSprintId) {
              sprint.issues.remove(issue);
              print('Error recovery: Removed from sprint ${sprint.name}');
              break;
            }
          }
          if (issue.sprintId == null) {
            selectedProject!.backlog.add(issue);
            print('Error recovery: Moved back to backlog');
          } else {
            for (var sprint in selectedProject!.sprints) {
              if (sprint.id == issue.sprintId) {
                sprint.issues.add(issue);
                print('Error recovery: Moved back to sprint ${sprint.name}');
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
        // After successful update, refetch data to ensure UI is consistent
        if (!mounted) return;
         _fetchSprintsAndIssues(selectedProject!.id!);
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
        title: const Text('Projects'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Implement filter functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Show create project dialog
            },
          ),
        ],
      ),
      body: projects.isEmpty && selectedProject == null
          ? const Center(child: CircularProgressIndicator()) // Show loading indicator initially
          : projects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No projects found.',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          // TODO: Show create project dialog
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Create Project'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Project List
                    Expanded(
                      flex: 1,
                      child: ListView.builder(
                        itemCount: projects.length,
                        itemBuilder: (context, index) {
                          final project = projects[index];
                          final isSelected = selectedProject?.id == project.id;
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            elevation: isSelected ? 2 : 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: isSelected 
                                ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
                                : BorderSide.none,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              title: Text(
                                project.name ?? 'Unnamed Project',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                ),
                              ),
                              subtitle: project.description != null && project.description!.isNotEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        project.description!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    )
                                  : null,
                              trailing: isSelected 
                                ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
                                : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                              onTap: () {
                                setState(() {
                                  selectedProject = project;
                                  _fetchSprintsAndIssues(project.id!);
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    // Selected Project Content
                    if (selectedProject != null)
                      Expanded(
                        flex: 2,
                        child: DefaultTabController(
                          length: 2,
                          child: Column(
                            children: [
                              TabBar(
                                tabs: const [
                                  Tab(text: 'Backlog'),
                                  Tab(text: 'Board'),
                                ],
                              ),
                              Expanded(
                                child: TabBarView(
                                  children: [
                                    // Backlog Tab
                                    ListView.builder(
                                      itemCount: selectedProject!.backlog.length,
                                      itemBuilder: (context, index) {
                                        return _buildIssueCard(selectedProject!.backlog[index], null);
                                      },
                                    ),
                                    // Board Tab
                                    ListView.builder(
                                      itemCount: selectedProject!.sprints.length,
                                      itemBuilder: (context, index) {
                                        final sprint = selectedProject!.sprints[index];
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(16.0),
                                              child: Text(
                                                sprint.name,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            ...sprint.issues.map((issue) => _buildIssueCard(issue, sprint)).toList(),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Icon(
              issue.type == 'Task' ? Icons.task : Icons.bug_report,
              size: 16,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                issue.title ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              issue.description ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
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
                if (issue.assignee.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person,
                          size: 12,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          issue.assignee,
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
          onSelected: (String? newSprintId) {
            print('Selected menu item: ${newSprintId ?? 'Move to Backlog'}');
            if (newSprintId == 'backlog') {
              print('Moving to backlog...');
              _moveIssue(issue, sprint, null);
            } else {
              final targetSprint = selectedProject!.sprints.firstWhere(
                (s) => s.id == newSprintId,
                orElse: () => sprint!,
              );
              print('Moving to sprint: ${targetSprint.name}');
              _moveIssue(issue, sprint, targetSprint);
            }
          },
          itemBuilder: (BuildContext context) {
            print('Building popup menu items...');
            final items = <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'backlog',
                child: Text('Move to Backlog'),
              ),
              ...selectedProject!.sprints.map((s) {
                return PopupMenuItem<String>(
                  value: s.id,
                  child: Text('Move to ${s.name}'),
                );
              }).toList(),
            ];
            print('Menu items built: ${items.length} items');
            return items;
          },
        ),
      ),
    );
  }
} 