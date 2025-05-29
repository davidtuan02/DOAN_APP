import 'package:flutter/material.dart';
// Assuming Project model is in ../models/project.dart
import '../models/project.dart'; 

// Simple mock Project data if not using a model:
/*
class Project {
  final String id;
  final String name;
  final String description;

  Project({required this.id, required this.name, required this.description});
}
*/

class ProjectScreen extends StatefulWidget {
  final Function(Project) onProjectSelected;

  const ProjectScreen({Key? key, required this.onProjectSelected}) : super(key: key);

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  List<Project> _projects = [];
  Project? _selectedProject;

  @override
  void initState() {
    super.initState();
    _generateMockProjects();
  }

  void _generateMockProjects() {
    // TODO: Replace with actual data fetching
    _projects = [
      Project(id: 'p1', name: 'Project Alpha', description: 'Description for Project Alpha', backlog: [], sprints: []),
      Project(id: 'p2', name: 'Project Beta', description: 'Description for Project Beta', backlog: [], sprints: []),
      Project(id: 'p3', name: 'Project Gamma', description: 'Description for Project Gamma', backlog: [], sprints: []),
    ];
    setState(() {});
  }

  void _selectProject(Project project) {
    setState(() {
      _selectedProject = project;
    });
  }

  void _goToBoard(Project project) {
    widget.onProjectSelected(project);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
      ),
      body: Row(
        children: [
          // Project List (Takes 1/3 of the screen width)
          SizedBox(
            width: MediaQuery.of(context).size.width / 3,
            child: ListView.builder(
              itemCount: _projects.length,
              itemBuilder: (context, index) {
                final project = _projects[index];
                return ListTile(
                  title: Text(project.name ?? ''),
                  onTap: () => _selectProject(project),
                  selected: _selectedProject?.id == project.id,
                  selectedTileColor: Colors.blue[100],
                );
              },
            ),
          ),
          // Project Details (Takes 2/3 of the screen width)
          Expanded(
            child: _selectedProject == null
                ? const Center(child: Text('Select a project to view details'))
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedProject!.name ?? '',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedProject!.description ?? '',
                          style: const TextStyle(fontSize: 16),
                        ),
                        // TODO: Display more project details
                        const Spacer(),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: ElevatedButton(
                            onPressed: () => _goToBoard(_selectedProject!),
                            child: const Text('Go to Board'),
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
} 