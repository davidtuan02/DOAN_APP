import 'package:flutter/material.dart';
import '../models/project.dart';
import '../widgets/create_issue_form.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class BacklogScreen extends StatefulWidget {
  final String userId;
  final String accessToken;
  final String projectId;
  final String projectName;

  const BacklogScreen({
    Key? key, 
    required this.userId, 
    required this.accessToken, 
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  State<BacklogScreen> createState() => _BacklogScreenState();
}

class _BacklogScreenState extends State<BacklogScreen> {
  late Project selectedProject;
  String? _boardId;

  @override
  void initState() {
    super.initState();
    print('BacklogScreen initState called');
    print('Project ID: ${widget.projectId}');
    print('Project name: ${widget.projectName}');
    print('Access token in initState: ${widget.accessToken}');
    
    // Initialize project with basic info
    selectedProject = Project(
      id: widget.projectId,
      name: widget.projectName,
      description: '',
      accessToken: widget.accessToken,
      backlog: [],
      sprints: [],
    );
    print('Project access token: ${selectedProject.accessToken}');
    
    // Fetch project data
    _fetchSprintsAndIssues(widget.projectId);
  }

  void _moveIssue(Issue issue, Sprint? fromSprint, Sprint? toSprint) async {
    print('Starting to move issue:');
    print('Issue ID: ${issue.id}');
    print('From Sprint: ${fromSprint?.name ?? 'Backlog'}');
    print('To Sprint: ${toSprint?.name ?? 'Backlog'}');
    
    try {
      // Call API to update issue's sprint first
      await _updateIssueSprint(issue, toSprint?.id, toSprint);
      
      // After successful API call, refresh the data
      if (mounted && selectedProject.id != null) {
        print('Refreshing data after move...');
        await _fetchSprintsAndIssues(selectedProject.id!);
        print('Data refresh completed');
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
    final url = Uri.parse('$baseUrl/tasks/${issue.id}/sprint');
    final headers = {
      'Content-Type': 'application/json',
      'tasks_token': widget.accessToken,
    };

    // If toSprint is null, it means we're moving to backlog
    final body = {
      'sprintId': toSprint == null ? null : newSprintId,
    };

    print('Updating issue sprint:');
    print('Issue ID: ${issue.id}');
    print('Current sprint: ${issue.sprintId}');
    print('New sprint: ${toSprint?.id ?? 'backlog'}');
    print('URL: $url');
    print('Headers: $headers');
    print('Body: $body');

    try {
      print('Sending PUT request...');
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
        // Update the issue's sprintId immediately
        issue.sprintId = toSprint?.id;
        
        // Force refresh data after successful update
        if (mounted && selectedProject.id != null) {
          print('Starting data refresh after successful update...');
          await _fetchSprintsAndIssues(selectedProject.id!);
          print('Data refresh completed after update');
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
                selectedProject.backlog.add(newIssue);
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

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Successfully updated issue');
        if (!mounted) return;
         _fetchSprintsAndIssues(selectedProject.id!);
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

  Future<void> _fetchSprintsAndIssues(String projectId) async {
    print('Fetching sprints and issues for project: $projectId');
    print('Access token being used: ${widget.accessToken}');
    if (!mounted) return;

    // Fetch project details to get boardId
    final projectUrl = Uri.parse('$baseUrl/projects/$projectId');
     final headers = <String, String>{
      'Content-Type': 'application/json',
      'tasks_token': widget.accessToken,
    };

    try {
      print('Fetching project details from URL: $projectUrl');
      final projectResponse = await http.get(projectUrl, headers: headers);
      print('Project response status: ${projectResponse.statusCode}');
      print('Project response body: ${projectResponse.body}');

      if (!mounted) return;

      if (projectResponse.statusCode == 200) {
        final dynamic projectData = json.decode(projectResponse.body);
        if (projectData is Map<String, dynamic>) {
          // Update selectedProject with full details if needed
          // selectedProject = Project.fromJson(projectData);

          // Extract boardId
          if (projectData['boards'] is List && projectData['boards'].isNotEmpty) {
            _boardId = projectData['boards'][0]['id']; // Assuming the first board is the one needed
            print('Extracted boardId: $_boardId');
          } else {
            print('No boards found for this project.');
             // Handle case where no board is found - maybe show an error or disable sprint creation
          }
        }
      }

      // Fetch sprints
      final sprintsUrl = Uri.parse('$baseUrl/sprints/project/$projectId');
      print('Fetching sprints from URL: $sprintsUrl');
      print('Using headers: $headers');
      final sprintsResponse = await http.get(sprintsUrl, headers: headers);
      print('Sprints response status: ${sprintsResponse.statusCode}');
      print('Sprints response body: ${sprintsResponse.body}');

      if (!mounted) return;

      if (sprintsResponse.statusCode == 200) {
        final dynamic sprintsResponseData = json.decode(sprintsResponse.body);
        print('Decoded sprints data: $sprintsResponseData');

        if (sprintsResponseData is List<dynamic>) {
          print('Number of sprints received: ${sprintsResponseData.length}');
          List<Sprint> fetchedSprints = [];
          Map<String, String> issueToSprintMap = {};

          // Process fetched sprints and build issue-to-sprint mapping
          for (var sprintJson in sprintsResponseData) {
            print('Processing sprint JSON: $sprintJson');
            if (sprintJson is Map<String, dynamic>) {
              try {
                final sprint = Sprint.fromJson(sprintJson);
                print('Successfully created Sprint object: ${sprint.name} (${sprint.id})');
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
                print('Error creating Sprint object: $e');
                print('Problematic sprint JSON: $sprintJson');
              }
            }
          }

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
              List<Issue> allTasks = tasksResponseData.map((issueJson) {
                final issue = Issue.fromJson(issueJson as Map<String, dynamic>);
                // Set sprintId based on our mapping
                issue.sprintId = issueToSprintMap[issue.id];
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
                  selectedProject = Project(
                    id: selectedProject.id,
                    name: selectedProject.name,
                    description: selectedProject.description,
                    status: selectedProject.status,
                    startDate: selectedProject.startDate,
                    endDate: selectedProject.endDate,
                    ownerId: selectedProject.ownerId,
                    accessToken: widget.accessToken,
                    backlog: backlogIssues,
                    sprints: sprintsWithIssues,
                  );
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

  void _showAddIssueDialog(BuildContext context, {String? sprintId}) {
    final formKey = GlobalKey<FormState>();
    String name = '';
    String type = 'Task';
    String priority = 'Medium';
    String status = 'CREATED';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(sprintId != null ? 'Add Issue to Sprint' : 'Add Issue to Backlog'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                    onSaved: (value) => name = value!,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    value: type,
                    items: const [
                      DropdownMenuItem(value: 'Epic', child: Text('Epic')),
                      DropdownMenuItem(value: 'Story', child: Text('Story')),
                      DropdownMenuItem(value: 'Task', child: Text('Task')),
                      DropdownMenuItem(value: 'Bug', child: Text('Bug')),
                    ],
                    onChanged: (value) {
                      type = value!;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      border: OutlineInputBorder(),
                    ),
                    value: priority,
                    items: const [
                      DropdownMenuItem(value: 'Highest', child: Text('Highest')),
                      DropdownMenuItem(value: 'High', child: Text('High')),
                      DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'Low', child: Text('Low')),
                      DropdownMenuItem(value: 'Lowest', child: Text('Lowest')),
                    ],
                    onChanged: (value) {
                      priority = value!;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    value: status,
                    items: const [
                      DropdownMenuItem(value: 'CREATED', child: Text('Created')),
                      DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In Progress')),
                      DropdownMenuItem(value: 'REVIEW', child: Text('Review')),
                      DropdownMenuItem(value: 'DONE', child: Text('Done')),
                    ],
                    onChanged: (value) {
                       status = value!;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  
                  try {
                    // Step 1: Create the issue
                    final requestBody = json.encode({
                      'taskName': name,
                      'priority': priority,
                      'status': status,
                      'type': type,
                      'taskDescription': ' ',
                      'reporterId': widget.userId,
                    });
                    print('Create Issue Request Body: $requestBody');

                    final createResponse = await http.post(
                      Uri.parse('$baseUrl/tasks/create/${widget.projectId}'),
                      headers: {
                        'Content-Type': 'application/json',
                        'tasks_token': widget.accessToken,
                      },
                      body: requestBody,
                    );

                    if (createResponse.statusCode != 201) {
                      throw Exception('Failed to create issue: ${createResponse.statusCode}');
                    }

                    final createdIssue = json.decode(createResponse.body);
                    final issueId = createdIssue['id'];

                    // Step 2: Add to sprint if sprintId is provided
                    if (sprintId != null) {
                      final sprintResponse = await http.put(
                        Uri.parse('$baseUrl/tasks/$issueId/sprint'),
                        headers: {
                          'Content-Type': 'application/json',
                          'tasks_token': widget.accessToken,
                        },
                        body: json.encode({
                          'sprintId': sprintId,
                        }),
                      );

                      if (sprintResponse.statusCode != 200) {
                        throw Exception('Failed to add issue to sprint: ${sprintResponse.statusCode}');
                      }
                    }

                    if (!mounted) return;
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Issue created successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _fetchSprintsAndIssues(widget.projectId);
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error creating issue: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    print('BacklogScreen build called');
    print('Current selected project: ${selectedProject.name}');
    print('Current backlog count: ${selectedProject.backlog.length}');
    print('Current sprints count: ${selectedProject.sprints.length}');
    
    return Scaffold(
      appBar: AppBar(
        title: Text(selectedProject.name ?? 'Backlog'),
        elevation: 2,
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchSprintsAndIssues(widget.projectId),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add Sprint Button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton.icon(
                  onPressed: () => _showAddSprintDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Sprint'),
                ),
              ),
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
                            onPressed: () => _showAddIssueDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Create Issue'),
                          ),
                        ],
                      ),
                    ),
                    if (selectedProject.backlog.isEmpty)
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
                        itemCount: selectedProject.backlog.length,
                        itemBuilder: (context, index) {
                          final issue = selectedProject.backlog[index];
                          return _buildIssueCard(issue, null);
                        },
                      ),
                  ],
                ),
              ),
              // Sprints section
              ...selectedProject.sprints.map((sprint) {
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
                              onPressed: () => _showAddIssueDialog(context, sprintId: sprint.id),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddIssueDialog(context),
        child: const Icon(Icons.add),
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
        onTap: () => _showEditIssueDialog(context, issue),
        trailing: PopupMenuButton<String>(
          onSelected: (String? newSprintId) {
            print('Selected menu item: ${newSprintId ?? 'Move to Backlog'}');
            if (newSprintId == 'backlog') {
              print('Moving to backlog...');
              _moveIssue(issue, sprint, null);
            } else {
              final targetSprint = selectedProject.sprints.firstWhere(
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
              ...selectedProject.sprints.map((s) {
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

  void _showEditIssueDialog(BuildContext context, Issue issue) {
    final formKey = GlobalKey<FormState>();
    String name = issue.title ?? '';
    String type = issue.type ?? 'Task';
    String priority = issue.priority ?? 'Medium';
    String status = issue.status ?? 'CREATED';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Issue'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: name,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                    onSaved: (value) => name = value!,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    value: type,
                    items: const [
                      DropdownMenuItem(value: 'Epic', child: Text('Epic')),
                      DropdownMenuItem(value: 'Story', child: Text('Story')),
                      DropdownMenuItem(value: 'Task', child: Text('Task')),
                      DropdownMenuItem(value: 'Bug', child: Text('Bug')),
                    ],
                    onChanged: (value) {
                      if (value != null) type = value;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      border: OutlineInputBorder(),
                    ),
                    value: priority,
                    items: const [
                      DropdownMenuItem(value: 'Highest', child: Text('Highest')),
                      DropdownMenuItem(value: 'High', child: Text('High')),
                      DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'Low', child: Text('Low')),
                      DropdownMenuItem(value: 'Lowest', child: Text('Lowest')),
                    ],
                    onChanged: (value) {
                      if (value != null) priority = value;
                    },
                  ),
                   const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    value: status,
                    items: const [
                      DropdownMenuItem(value: 'CREATED', child: Text('Created')),
                      DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In Progress')),
                      DropdownMenuItem(value: 'REVIEW', child: Text('Review')),
                      DropdownMenuItem(value: 'DONE', child: Text('Done')),
                    ],
                    onChanged: (value) {
                       if (value != null) status = value;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  Navigator.of(context).pop(); // Close dialog
                  await _updateIssueDetails(issue.id!, name, type, priority, status); // Call update API
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateIssueDetails(String issueId, String name, String type, String priority, String status) async {
     try {
      final url = Uri.parse('$baseUrl/tasks/$issueId');
      final headers = {
        'Content-Type': 'application/json',
        'tasks_token': widget.accessToken,
      };

      final body = json.encode({
        'taskName': name,
        'type': type,
        'priority': priority,
        'status': status,
        // Include other fields if required by the PUT API (e.g., taskDescription, reporterId)
        // For now, assuming only editable fields are needed.
      });

      print('Update Issue Details Request Body: $body');

      final response = await http.put(
        url,
        headers: headers,
        body: body,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        print('Successfully updated issue details');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Issue updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchSprintsAndIssues(widget.projectId); // Refresh list after update
      } else {
        print('Failed to update issue details: ${response.statusCode}');
        print('Response body: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update issue: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error updating issue details: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating issue: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Function to show add sprint dialog
  void _showAddSprintDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    String name = '';
    String goal = '';
    DateTime? startDate;
    DateTime? endDate;
    String status = 'planning'; // Use lowercase as per API requirement

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) { // Use dialogContext to avoid confusion
        return StatefulBuilder( // Use StatefulBuilder here
          builder: (BuildContext context, StateSetter setDialogState) { // setDialogState to rebuild the dialog
            return AlertDialog(
              title: const Text('Create Sprint'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a name';
                          }
                          return null;
                        },
                        onSaved: (value) => name = value!,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Goal',
                          border: OutlineInputBorder(),
                        ),
                        onSaved: (value) => goal = value!,
                      ),
                      const SizedBox(height: 16),
                      // Start Date Picker
                       ListTile(
                        title: Text(startDate == null ? 'Select Start Date' : 'Start Date: ${startDate!.toLocal().toString().split(' ')[0]}'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: startDate ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                          );
                          if (pickedDate != null) {
                            setDialogState(() { // Use setDialogState here
                              startDate = pickedDate;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                       // End Date Picker
                      ListTile(
                        title: Text(endDate == null ? 'Select End Date' : 'End Date: ${endDate!.toLocal().toString().split(' ')[0]}'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: endDate ?? startDate ?? DateTime.now(),
                            firstDate: startDate ?? DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                          );
                          if (pickedDate != null) {
                            setDialogState(() { // Use setDialogState here
                              endDate = pickedDate;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                        ),
                        value: status,
                        items: const [
                          DropdownMenuItem(value: 'planning', child: Text('Planning')),
                          DropdownMenuItem(value: 'active', child: Text('Active')),
                          DropdownMenuItem(value: 'completed', child: Text('Completed')),
                        ],
                        onChanged: (value) {
                          if (value != null) setDialogState(() { status = value!; }); // Use setDialogState here
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      formKey.currentState!.save();
                      if (_boardId == null) {
                         // Handle case where boardId is not available
                         print('Error: Board ID not available.');
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(
                             content: Text('Error: Cannot create sprint, board ID not found.'),
                             backgroundColor: Colors.red,
                           ),
                         );
                         Navigator.of(dialogContext).pop(); // Use dialogContext here
                         return;
                      }

                      try {
                        final response = await http.post(
                          Uri.parse('$baseUrl/sprints/create/$_boardId'),
                          headers: {
                            'Content-Type': 'application/json',
                            'tasks_token': widget.accessToken,
                          },
                          body: json.encode({
                            'name': name,
                            'goal': goal,
                            'startDate': startDate?.toIso8601String(),
                            'endDate': endDate?.toIso8601String(),
                            'status': status,
                          }),
                        );

                        if (!mounted) return;

                        if (response.statusCode == 201) {
                          Navigator.of(dialogContext).pop(); // Use dialogContext here
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sprint created successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _fetchSprintsAndIssues(widget.projectId); // Refresh the list
                        } else {
                          print('Failed to create sprint: ${response.statusCode}');
                          print('Response body: ${response.body}');
                           ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to create sprint: ${response.statusCode}. ${response.body}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        print('Error creating sprint: $e');
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error creating sprint: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }
} 