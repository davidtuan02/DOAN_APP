import '../models/project.dart';

final List<Project> mockProjects = [
  Project(
    id: '1',
    name: 'E-commerce Website',
    description: 'Development of a new e-commerce platform',
    sprints: [
      Sprint(
        id: '1',
        name: 'Sprint 1 - Setup',
        startDate: DateTime(2024, 3, 1),
        endDate: DateTime(2024, 3, 14),
        issues: [
          Issue(
            id: '1',
            title: 'Setup project structure',
            description: 'Create basic project structure and setup dependencies',
            status: 'Done',
            priority: 'High',
            assignee: 'John Doe',
          ),
          Issue(
            id: '2',
            title: 'Design database schema',
            description: 'Create database schema for products and users',
            status: 'In Progress',
            priority: 'High',
            assignee: 'Jane Smith',
          ),
        ],
      ),
      Sprint(
        id: '2',
        name: 'Sprint 2 - Features',
        startDate: DateTime(2024, 3, 15),
        endDate: DateTime(2024, 3, 28),
        issues: [
          Issue(
            id: '3',
            title: 'Implement user authentication',
            description: 'Add login and registration functionality',
            status: 'To Do',
            priority: 'High',
            assignee: 'John Doe',
          ),
        ],
      ),
    ],
    backlog: [
      Issue(
        id: '4',
        title: 'Add payment integration',
        description: 'Integrate payment gateway',
        status: 'To Do',
        priority: 'Medium',
        assignee: 'Unassigned',
      ),
      Issue(
        id: '5',
        title: 'Implement search functionality',
        description: 'Add product search with filters',
        status: 'To Do',
        priority: 'Medium',
        assignee: 'Unassigned',
      ),
    ],
  ),
  Project(
    id: '2',
    name: 'Mobile App',
    description: 'Development of a mobile application',
    sprints: [
      Sprint(
        id: '3',
        name: 'Sprint 1 - UI',
        startDate: DateTime(2024, 3, 1),
        endDate: DateTime(2024, 3, 14),
        issues: [
          Issue(
            id: '6',
            title: 'Design app screens',
            description: 'Create UI mockups for all screens',
            status: 'Done',
            priority: 'High',
            assignee: 'Alice Johnson',
          ),
        ],
      ),
    ],
    backlog: [
      Issue(
        id: '7',
        title: 'Implement push notifications',
        description: 'Add push notification functionality',
        status: 'To Do',
        priority: 'Low',
        assignee: 'Unassigned',
      ),
    ],
  ),
]; 