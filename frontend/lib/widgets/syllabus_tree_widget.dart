import 'package:flutter/material.dart';
import '../models/syllabus_model.dart';
import '../theme/app_theme.dart';

class SyllabusTreeWidget extends StatelessWidget {
  final List<SyllabusNode> nodes;

  const SyllabusTreeWidget({
    super.key,
    required this.nodes,
  });

  Widget _buildNode(BuildContext context, SyllabusNode node) {
    if (node.level == SyllabusLevel.subtopic || node.children.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(left: 48.0),
        child: ListTile(
          leading: const Icon(Icons.fiber_manual_record, size: 10),
          title: Text(node.title),
          dense: true,
          contentPadding: const EdgeInsets.only(right: 16.0),
        ),
      );
    }

    if (node.level == SyllabusLevel.subject) {
      return Container(
        color: AppColors.primaryLight,
        margin: const EdgeInsets.only(bottom: 2.0),
        child: ExpansionTile(
          title: Text(
            node.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          childrenPadding: EdgeInsets.zero,
          children: node.children.map((child) => _buildNode(context, child)).toList(),
        ),
      );
    }

    if (node.level == SyllabusLevel.chapter) {
      return Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: ExpansionTile(
          leading: const Icon(Icons.book, size: 20),
          title: Text(
            node.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          childrenPadding: EdgeInsets.zero,
          children: node.children.map((child) => _buildNode(context, child)).toList(),
        ),
      );
    }

    if (node.level == SyllabusLevel.topic) {
      return Padding(
        padding: const EdgeInsets.only(left: 32.0),
        child: ExpansionTile(
          leading: const Icon(Icons.subdirectory_arrow_right, size: 20),
          title: Text(
            node.title,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          childrenPadding: EdgeInsets.zero,
          children: node.children.map((child) => _buildNode(context, child)).toList(),
        ),
      );
    }

    return ExpansionTile(
      title: Text(node.title),
      children: node.children.map((child) => _buildNode(context, child)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: nodes.length,
      itemBuilder: (context, index) {
        return _buildNode(context, nodes[index]);
      },
    );
  }
}
