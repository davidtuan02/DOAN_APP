import 'package:flutter/material.dart';
import '../models/project.dart';
import '../data/mock_data.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({Key? key}) : super(key: key);

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  Project? selectedProject;

  @override
  void initState() {
    super.initState();
    if (mockProjects.isNotEmpty) {
      selectedProject = mockProjects[0];
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
              items: mockProjects.map((Project project) {
                return DropdownMenuItem<Project>(
                  value: project,
                  child: Text(project.name),
                );
              }).toList(),
              onChanged: (Project? newValue) {
                setState(() {
                  selectedProject = newValue;
                });
              },
            ),
          ),

          // Kanban Board
          Expanded(
            child: selectedProject == null
                ? const Center(child: Text('Please select a project'))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
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
        child: Column(
          children: [
            Container(
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
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: DragTarget<Issue>(
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
                            child: Text(issue.title),
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
                          child: ListTile(
                            title: Text(issue.title),
                            subtitle: Text(
                              issue.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(
                                  label: Text(issue.status),
                                  backgroundColor: _getStatusColor(issue.status),
                                ),
                                const SizedBox(width: 4),
                                Chip(
                                  label: Text(issue.priority),
                                  backgroundColor: _getPriorityColor(issue.priority),
                                ),
                              ],
                            ),
                            onTap: () {
                              // TODO: Implement issue details view
                            },
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