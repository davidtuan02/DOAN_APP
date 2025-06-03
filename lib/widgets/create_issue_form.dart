import 'package:flutter/material.dart';
import '../models/sprint.dart';
import '../models/issue.dart';
import '../models/project.dart'; // Assuming Issue model is in project.dart

class CreateIssueForm extends StatefulWidget {
  final Sprint? sprint;
  final Function(Issue) onIssueCreated;

  const CreateIssueForm({Key? key, this.sprint, required this.onIssueCreated}) : super(key: key);

  @override
  _CreateIssueFormState createState() => _CreateIssueFormState();
}

class _CreateIssueFormState extends State<CreateIssueForm> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _description = '';
  String _status = 'To Do'; // Default status
  String _priority = 'Medium'; // Default priority
  String _assignee = 'Unassigned'; // Default assignee

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      // Generate a simple unique ID (for demonstration purposes)
      final newIssue = Issue(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _title,
        description: _description,
        status: _status,
        priority: _priority,
        assignee: _assignee,
      );
      widget.onIssueCreated(newIssue);
      Navigator.of(context).pop(); // Close the dialog
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Create New Issue'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Title'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
                onSaved: (value) {
                  _title = value!;
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Description'),
                maxLines: 3,
                onSaved: (value) {
                  _description = value!;
                },
              ),
              // TODO: Add dropdowns for Status, Priority, Assignee
              // TODO: Add dropdown for Issue Type
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitForm,
          child: Text('Create'),
        ),
      ],
    );
  }
} 