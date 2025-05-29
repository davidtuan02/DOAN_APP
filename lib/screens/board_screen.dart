import 'package:flutter/material.dart';
import '../models/project.dart'; // Assuming Project, Sprint, Issue are defined here
import 'dart:math';

class BoardScreen extends StatefulWidget {
  const BoardScreen({Key? key}) : super(key: key);

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  List<Sprint> _sprints = [];
  Sprint? _selectedSprint;
  // Map to hold issues grouped by their status (Kanban columns)
  Map<String, List<Issue>> _kanbanColumns = {
    'CREATED': [],
    'IN_PROGRESS': [],
    'REVIEW': [],
    'DONE': [],
  };

  @override
  void initState() {
    super.initState();
    _generateMockData();
    _selectDefaultSprint();
  }

  void _generateMockData() {
    // Mock Sprints
    _sprints = ['Sprint 1', 'Sprint 2', 'Sprint 3'].map((name) {
      final id = UniqueKey().toString();
      return Sprint(
        id: id,
        name: name,
        startDate: DateTime.now().subtract(Duration(days: 14)),
        endDate: DateTime.now().add(Duration(days: 14)),
        issues: [], // Issues will be assigned below
      );
    }).toList();

    // Mock Issues
    List<Issue> allMockIssues = [
      Issue(id: '1', title: 'Setup project', description: 'Initial project setup', status: 'DONE', priority: 'High', type: 'Task', assignee: 'user1', sprintId: _sprints[0].id!, createdAt: DateTime.now(), updatedAt: DateTime.now()),
      Issue(id: '2', title: 'Implement login screen', description: 'Develop the user login interface', status: 'IN_PROGRESS', priority: 'High', type: 'Task', assignee: 'user2', sprintId: _sprints[0].id!, createdAt: DateTime.now(), updatedAt: DateTime.now()),
      Issue(id: '3', title: 'Design database schema', description: 'Create the database structure', status: 'REVIEW', priority: 'Medium', type: 'Task', assignee: 'user1', sprintId: _sprints[0].id!, createdAt: DateTime.now(), updatedAt: DateTime.now()),
      Issue(id: '4', title: 'Write API documentation', description: 'Document the REST APIs', status: 'CREATED', priority: 'Low', type: 'Task', assignee: 'user3', sprintId: _sprints[0].id!, createdAt: DateTime.now(), updatedAt: DateTime.now()),
      Issue(id: '5', title: 'Fix minor UI bug', description: 'Correct alignment issue on dashboard', status: 'CREATED', priority: 'High', type: 'Bug', assignee: 'user2', sprintId: _sprints[0].id!, createdAt: DateTime.now(), updatedAt: DateTime.now()),
      Issue(id: '6', title: 'Plan next sprint', description: 'Outline tasks for the next sprint', status: 'CREATED', priority: 'Medium', type: 'Task', assignee: 'user1', sprintId: _sprints[1].id!, createdAt: DateTime.now(), updatedAt: DateTime.now()),
      Issue(id: '7', title: 'Refactor authentication module', description: 'Improve code structure for auth', status: 'CREATED', priority: 'High', type: 'Task', assignee: 'user3', sprintId: _sprints[1].id!, createdAt: DateTime.now(), updatedAt: DateTime.now()),
    ];

    // Distribute issues into columns based on status
    for (var issue in allMockIssues) {
      if (_kanbanColumns.containsKey(issue.status)) {
        _kanbanColumns[issue.status]!.add(issue);
      }
    }

    // Assign issues to sprints for the Sprint model structure (optional, mainly for mock data consistency)
    for (var issue in allMockIssues) {
      if (issue.sprintId != null && issue.sprintId!.isNotEmpty) {
        final sprint = _sprints.firstWhere((s) => s.id == issue.sprintId);
        sprint.issues.add(issue);
      }
    }

    setState(() {}); // Update UI after generating data
  }

  void _selectDefaultSprint() {
    if (_sprints.isNotEmpty) {
      setState(() {
        _selectedSprint = _sprints[0];
        // Filter issues based on the selected sprint
        _filterIssuesBySprint(_selectedSprint);
      });
    }
  }

   void _filterIssuesBySprint(Sprint? sprint) {
    // Regenerate _kanbanColumns based on the selected sprint's issues
    _kanbanColumns = {
      'CREATED': [],
      'IN_PROGRESS': [],
      'REVIEW': [],
      'DONE': [],
    };

    if (sprint != null) {
      for (var issue in sprint.issues) {
         if (_kanbanColumns.containsKey(issue.status)) {
           _kanbanColumns[issue.status]!.add(issue);
         }
      }
    }

     setState(() {}); // Update UI after filtering
   }

  void _moveIssue(Issue issue, String newStatus) {
    setState(() {
      // Remove issue from its current column
      _kanbanColumns.forEach((status, issues) {
        issues.removeWhere((item) => item.id == issue.id);
      });

      // Add issue to the new column and update its status
      if (_kanbanColumns.containsKey(newStatus)) {
        final updatedIssue = Issue(
          id: issue.id,
          title: issue.title,
          description: issue.description,
          status: newStatus, // Update status
          priority: issue.priority,
          type: issue.type,
          assignee: issue.assignee,
          sprintId: issue.sprintId,
          createdAt: issue.createdAt,
          updatedAt: DateTime.now(), // Update updated time
        );
        _kanbanColumns[newStatus]!.add(updatedIssue);
        // Also update in the _sprints list for data consistency
        final sprint = _sprints.firstWhere((s) => s.id == issue.sprintId, orElse: () => throw Exception('Sprint not found'));
        final issueIndexInSprint = sprint.issues.indexWhere((i) => i.id == issue.id);
        if (issueIndexInSprint != -1) {
           sprint.issues[issueIndexInSprint] = updatedIssue;
        }
      }
    });
    // TODO: Implement API call to update issue status
  }

  void _addIssue(String description, String status) {
    if (_selectedSprint == null) return; // Cannot add issue without a selected sprint

    final newIssue = Issue(
      id: UniqueKey().toString(), // Generate unique ID
      title: description.split('\n')[0], // Use first line of description as title
      description: description,
      status: status,
      priority: 'Medium', // Default priority
      type: 'Task', // Default type
      assignee: '', // No assignee by default
      sprintId: _selectedSprint!.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setState(() {
      _kanbanColumns[status]!.add(newIssue);
      _selectedSprint!.issues.add(newIssue);
    });

    // TODO: Implement API call to create new issue
    print('New issue added to $status: ${newIssue.title}');
  }

  void _showAddIssueDialog(String status) {
    final _descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add New Issue to $status'),
          content: TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_descriptionController.text.isNotEmpty) {
                  _addIssue(_descriptionController.text, status);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _completeSprint() {
    // TODO: Implement sprint completion logic (move unfinished issues, etc.)
    print('Complete Sprint pressed for ${_selectedSprint?.name}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Board'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sprint Selection and Complete Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Sprint>(
                    decoration: const InputDecoration(
                      labelText: 'Select Sprint',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedSprint,
                    items: _sprints.map((Sprint sprint) {
                      return DropdownMenuItem<Sprint>(
                        value: sprint,
                        child: Text(sprint.name ?? ''),
                      );
                    }).toList(),
                    onChanged: (Sprint? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedSprint = newValue;
                          _filterIssuesBySprint(newValue);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16.0),
                ElevatedButton(
                  onPressed: _selectedSprint == null ? null : _completeSprint,
                  child: const Text('Complete Sprint'),
                ),
              ],
            ),
          ),
          // Kanban Board Area
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _kanbanColumns.keys.map((status) {
                  return _buildKanbanColumn(status, _kanbanColumns[status]!);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanColumn(String status, List<Issue> issues) {
    return Container(
      width: 300, // Fixed width for each column
      margin: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$status (${issues.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    _showAddIssueDialog(status);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: DragTarget<Issue>(
              onWillAccept: (data) => true, // Accept any dragged Issue
              onAccept: (data) {
                _moveIssue(data, status);
              },
              builder: (context, candidateData, rejectedData) {
                return ListView.builder(
                  itemCount: issues.length,
                  itemBuilder: (context, index) {
                    final issue = issues[index];
                    return Draggable<Issue>(
                      data: issue,
                      feedback: Material(
                        elevation: 4.0,
                        child: Container(
                          padding: const EdgeInsets.all(8.0),
                          width: 280, // Match column width
                          child: Text(issue.title ?? ''),
                        ),
                      ),
                      childWhenDragging: Container(
                        height: 80, // Placeholder height
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        color: Colors.grey.shade200,
                      ),
                      child: Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                issue.title ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (issue.description != null && issue.description!.isNotEmpty)
                                Text(
                                  issue.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              // TODO: Add more issue details like assignee, priority etc.
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 