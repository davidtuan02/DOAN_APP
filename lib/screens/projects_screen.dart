import 'package:flutter/material.dart';
import '../models/project.dart';
import 'backlog_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import '../models/user_project.dart';
import '../models/board.dart';

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
  Project? _projectDetails;
  List<UserProject> _projectMembers = [];
  bool _isDetailsLoading = false;
  String? _detailsError;

  @override
  void initState() {
    super.initState();
    if (widget.initialProject != null) {
      selectedProjectId = widget.initialProject!.id;
      selectedProjectName = widget.initialProject!.name;
      _fetchProjectDetails(selectedProjectId!);
    }
    _fetchProjects();
  }

  Future<void> _fetchProjectDetails(String projectId) async {
    if (_isDetailsLoading) return;

    setState(() {
      _isDetailsLoading = true;
      _detailsError = null;
      _projectDetails = null;
      _projectMembers = [];
    });

    try {
      final projectUrl = Uri.parse('$baseUrl/projects/$projectId');
      final projectResponse = await http.get(
        projectUrl,
        headers: {
          'Content-Type': 'application/json',
          'tasks_token': widget.accessToken,
        },
      );

      if (!mounted) return;

      if (projectResponse.statusCode == 200) {
        final dynamic projectData = json.decode(projectResponse.body);
        if (projectData is Map<String, dynamic>) {
          _projectDetails = Project.fromJson(projectData);

          final membersUrl = Uri.parse('$baseUrl/projects/$projectId/members');
          print('Fetching members from URL: $membersUrl');
          final membersResponse = await http.get(
            membersUrl,
            headers: {
              'Content-Type': 'application/json',
              'tasks_token': widget.accessToken,
            },
          );

          print('Members Response Status: ${membersResponse.statusCode}');
          print('Members Response Body: ${membersResponse.body}');

          if (!mounted) return;

          if (membersResponse.statusCode == 200) {
            final List<dynamic> membersData = json.decode(membersResponse.body);
            _projectMembers = membersData.map((json) => UserProject.fromJson(json)).toList();

            setState(() {
              _isDetailsLoading = false;
            });
          } else {
            print('Failed to load project members: ${membersResponse.statusCode}');
            setState(() {
              _detailsError = 'Failed to load members: ${membersResponse.statusCode}';
              _isDetailsLoading = false;
            });
          }
        }
      } else {
        print('Failed to load project details: ${projectResponse.statusCode}');
        setState(() {
          _detailsError = 'Failed to load project: ${projectResponse.statusCode}';
          _isDetailsLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching project details: $e');
      if (!mounted) return;
      setState(() {
        _detailsError = 'Error: ${e.toString()}';
        _isDetailsLoading = false;
      });
    }
  }

  Future<void> _fetchProjects() async {
    try {
      final url = Uri.parse('$baseUrl/projects/user/${widget.userId}');
      final headers = {
        'Content-Type': 'application/json',
        'tasks_token': widget.accessToken,
      };

      print('Fetching projects from URL: $url');
      final response = await http.get(url, headers: headers);

      print('Projects Response Status: ${response.statusCode}');
      print('Projects Response Body: ${response.body}');

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
              _fetchProjectDetails(selectedProjectId!);
            }
          });
        } else {
          print('API returned an unexpected format: ${responseData.runtimeType}');
          if (!mounted) return;
          setState(() {
            projects = [];
            selectedProjectId = null;
            selectedProjectName = null;
            _projectDetails = null;
            _projectMembers = [];
            _detailsError = null;
            _isDetailsLoading = false;
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

  void _handleProjectSelected(Project project) {
    setState(() {
      selectedProjectId = project.id;
      selectedProjectName = project.name;
    });
    if (widget.onProjectSelected != null) {
      widget.onProjectSelected!(project);
    }
    if (project.id != null) {
      _fetchProjectDetails(project.id!);
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
                              orElse: () => projects.isNotEmpty ? projects[0] : null!,
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
                                _handleProjectSelected(newValue);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    
                    Expanded(
                      child: _isDetailsLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _detailsError != null
                              ? Center(child: Text('Error loading project details: $_detailsError'))
                              : _projectDetails == null
                                  ? const Center(child: Text('Select a project to see details'))
                                  : SingleChildScrollView(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Card(
                                            elevation: 2,
                                            child: Padding(
                                              padding: const EdgeInsets.all(16.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _projectDetails!.name ?? 'No Name',
                                                    style: const TextStyle(
                                                      fontSize: 24,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  if (_projectDetails!.description != null && _projectDetails!.description!.isNotEmpty)
                                                    Text(
                                                      _projectDetails!.description!,
                                                      style: const TextStyle(fontSize: 16),
                                                    ),
                                                  const SizedBox(height: 16),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.key, size: 20),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'Key: ${_projectDetails!.key ?? 'N/A'}',
                                                        style: const TextStyle(fontSize: 16),
                                                      ),
                                                    ],
                                                  ),
                                                   if (_projectDetails!.startDate != null) ...[
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.calendar_today, size: 20),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          'Start Date: ${_projectDetails!.startDate!.toLocal().toString().split(' ')[0]}',
                                                          style: const TextStyle(fontSize: 16),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                  if (_projectDetails!.endDate != null) ...[
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.calendar_today, size: 20),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          'End Date: ${_projectDetails!.endDate!.toLocal().toString().split(' ')[0]}',
                                                          style: const TextStyle(fontSize: 16),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                          const Text(
                                            'Project Members',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          if (_projectMembers.isEmpty)
                                            const Card(
                                              child: Padding(
                                                padding: EdgeInsets.all(16.0),
                                                child: Text('No members found.'),
                                              ),
                                            )
                                          else
                                            ListView.builder(
                                              shrinkWrap: true,
                                              physics: const NeverScrollableScrollPhysics(),
                                              itemCount: _projectMembers.length,
                                              itemBuilder: (context, index) {
                                                final member = _projectMembers[index];
                                                String roleText = 'MEMBER';
                                                if (member.accessLevel != null) {
                                                  switch (member.accessLevel) {
                                                    case 50:
                                                      roleText = 'MANAGER';
                                                      break;
                                                    case 40:
                                                      roleText = 'LEADER';
                                                      break;
                                                    case 30:
                                                      roleText = 'MEMBER';
                                                      break;
                                                    default:
                                                      roleText = 'MEMBER';
                                                  }
                                                }
                                                return Card(
                                                  margin: const EdgeInsets.only(bottom: 8),
                                                  child: ListTile(
                                                    leading: CircleAvatar(
                                                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                                                      foregroundColor: Theme.of(context).primaryColor,
                                                      child: Text(
                                                        member.userName?.isNotEmpty == true
                                                            ? member.userName![0].toUpperCase()
                                                            : '?',
                                                      ),
                                                    ),
                                                    title: Text(
                                                      member.userName ?? 'Unknown User',
                                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                                    ),
                                                    subtitle: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        if (member.userEmail != null && member.userEmail!.isNotEmpty)
                                                          Text(member.userEmail!),
                                                        Text('Role: $roleText'),
                                                      ],
                                                    ),
                                                    trailing: Text(
                                                      '',
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                    ),
                  ],
                ),
    );
  }
} 