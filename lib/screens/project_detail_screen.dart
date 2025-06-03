import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import '../models/project.dart' as project_model;
import '../models/user_project.dart'; // Assuming you have a model for project members

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;
  final String accessToken;

  const ProjectDetailScreen({
    Key? key,
    required this.projectId,
    required this.accessToken,
  }) : super(key: key);

  @override
  _ProjectDetailScreenState createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  project_model.Project? _projectDetails;
  List<UserProject> _projectMembers = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProjectData(widget.projectId);
  }

  @override
  void didUpdateWidget(ProjectDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.projectId != oldWidget.projectId) {
      _fetchProjectData(widget.projectId);
    }
  }

  Future<void> _fetchProjectData(String projectId) async {
    if (_isLoading) return; // Prevent multiple calls

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch project details
      final projectUrl = Uri.parse('$baseUrl/projects/$projectId');
      print('Fetching project from URL: $projectUrl');
      final projectResponse = await http.get(
        projectUrl,
        headers: {
          'Content-Type': 'application/json',
          'tasks_token': widget.accessToken,
        },
      );

      print('Project Response Status: ${projectResponse.statusCode}');
      print('Project Response Body: ${projectResponse.body}');

      if (!mounted) return;

      if (projectResponse.statusCode == 200) {
        final projectData = json.decode(projectResponse.body);
        print('Decoded Project Data: $projectData');
        _projectDetails = project_model.Project.fromJson(projectData);

        // Fetch project members
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
          print('Decoded Members Data: $membersData');
          _projectMembers = membersData.map((json) => UserProject.fromJson(json)).toList();

          setState(() {
            _isLoading = false;
          });
        } else {
          print('Failed to load project members: ${membersResponse.statusCode}');
          print('Members response body: ${membersResponse.body}');
          setState(() {
            _error = 'Failed to load members: ${membersResponse.statusCode}';
            _isLoading = false;
          });
        }
      } else {
        print('Failed to load project details: ${projectResponse.statusCode}');
        print('Project response body: ${projectResponse.body}');
         setState(() {
          _error = 'Failed to load project: ${projectResponse.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching project data: $e');
      if (!mounted) return;
       setState(() {
        _error = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building ProjectDetailScreen');
    print('Project Details: $_projectDetails');
    print('Project Members: $_projectMembers');
    
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Project Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _fetchProjectData(widget.projectId),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_projectDetails == null) {
      print('Project details is null');
      return Scaffold(
        appBar: AppBar(title: const Text('Project Details')),
        body: const Center(child: Text('Project data not available.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_projectDetails!.name ?? 'Project Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchProjectData(widget.projectId),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project Info Card
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
            // Members Section
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
                      case 3:
                        roleText = 'MANAGER';
                        break;
                      case 2:
                        roleText = 'LEADER';
                        break;
                      case 1:
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
    );
  }
} 