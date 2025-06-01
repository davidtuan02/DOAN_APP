import 'package:flutter/material.dart';
import '../models/project.dart';
import 'backlog_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProjectsScreen extends StatefulWidget {
  final String userId;
  final String accessToken;
  final Function(Project)? onProjectSelected;
  final Project? initialProject;

  const ProjectsScreen({
    Key? key, 
    required this.userId, 
    required this.accessToken,
    this.onProjectSelected,
    this.initialProject,
  }) : super(key: key);

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  String? selectedProjectId;
  String? selectedProjectName;
  List<Project> projects = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialProject != null) {
      selectedProjectId = widget.initialProject!.id;
      selectedProjectName = widget.initialProject!.name;
    }
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
            if (projects.isNotEmpty && selectedProjectId == null) {
              selectedProjectId = projects[0].id;
              selectedProjectName = projects[0].name;
              if (widget.onProjectSelected != null) {
                widget.onProjectSelected!(projects[0]);
              }
            }
          });
        } else {
          print('API returned an unexpected format: ${responseData.runtimeType}');
          if (!mounted) return;
          setState(() {
            projects = [];
            selectedProjectId = null;
            selectedProjectName = null;
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
      body: projects.isEmpty && selectedProjectId == null
          ? const Center(child: CircularProgressIndicator())
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
                    // Project Selector
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Project>(
                            value: projects.firstWhere(
                              (p) => p.id == selectedProjectId,
                              orElse: () => projects[0],
                            ),
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down),
                            hint: const Text('Select a project'),
                            items: projects.map((Project project) {
                              return DropdownMenuItem<Project>(
                                value: project,
                                child: Text(
                                  project.name ?? 'Unnamed Project',
                                  style: const TextStyle(
                                    fontSize: 16,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (Project? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  selectedProjectId = newValue.id;
                                  selectedProjectName = newValue.name;
                                });
                                if (widget.onProjectSelected != null) {
                                  widget.onProjectSelected!(newValue);
                                }
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: selectedProjectId != null
          ? FloatingActionButton(
              onPressed: () {
                print('FAB pressed - Selected project ID: $selectedProjectId');
                print('Selected project name: $selectedProjectName');
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      print('Building BacklogScreen with project ID: $selectedProjectId');
                      return BacklogScreen(
                        userId: widget.userId,
                        accessToken: widget.accessToken,
                        projectId: selectedProjectId!,
                        projectName: selectedProjectName ?? 'Unnamed Project',
                      );
                    },
                  ),
                );
              },
              child: const Icon(Icons.list_alt),
            )
          : null,
    );
  }
} 