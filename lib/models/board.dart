import 'package:flutter/material.dart'; // Assuming Material is needed for any UI related parts of the model (can be removed)

class Board {
  final String id;
  final String? name;
  final List<BoardColumn>? columns;

  Board({
    required this.id,
    this.name,
    this.columns,
  });

  factory Board.fromJson(Map<String, dynamic> json) {
    return Board(
      id: json['id'] as String,
      name: json['name'] as String?,
      columns: (json['columns'] as List<dynamic>?)?.map((e) => BoardColumn.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'columns': columns?.map((e) => e.toJson()).toList(), // Use null-aware map access
    };
  }
}

class BoardColumn {
  final String id;
  final String? name;
  final int? order;

  BoardColumn({
    required this.id,
    this.name,
    this.order,
  });

  factory BoardColumn.fromJson(Map<String, dynamic> json) {
    return BoardColumn(
      id: json['id'] as String,
      name: json['name'] as String?,
      order: json['order'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'order': order,
    };
  }
} 