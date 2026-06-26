import 'package:flutter/material.dart';
import '../models/syllabus_model.dart';
import '../theme/app_theme.dart';

/// Fully theme-aware syllabus tree widget.
///
/// Uses [BpscThemeData] for all colors so it syncs correctly
/// when switching between Vibrant / Professional / Dark Tech themes.
class SyllabusTreeWidget extends StatelessWidget {
  final List<SyllabusNode> nodes;

  const SyllabusTreeWidget({
    super.key,
    required this.nodes,
  });

  Widget _buildNode(BuildContext context, SyllabusNode node) {
    final t = BpscThemeData.of(context);

    if (node.level == SyllabusLevel.subtopic || node.children.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(left: 48.0),
        child: ListTile(
          leading: Icon(Icons.fiber_manual_record, size: 10, color: t.textMuted),
          title: Text(
            node.title,
            style: TextStyle(fontSize: 14, color: t.text),
          ),
          dense: true,
          contentPadding: const EdgeInsets.only(right: 16.0),
        ),
      );
    }

    if (node.level == SyllabusLevel.subject) {
      return Container(
        color: t.primarySoft,
        margin: const EdgeInsets.only(bottom: 2.0),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(
              node.title,
              style: TextStyle(
                fontFamily: t.displayFontFamily,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: t.text,
              ),
            ),
            iconColor: t.primary,
            collapsedIconColor: t.textMuted,
            childrenPadding: EdgeInsets.zero,
            children: node.children.map((child) => _buildNode(context, child)).toList(),
          ),
        ),
      );
    }

    if (node.level == SyllabusLevel.chapter) {
      return Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(Icons.book, size: 20, color: t.secondary),
            title: Text(
              node.title,
              style: TextStyle(
                fontFamily: t.bodyFontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: t.text,
              ),
            ),
            iconColor: t.primary,
            collapsedIconColor: t.textMuted,
            childrenPadding: EdgeInsets.zero,
            children: node.children.map((child) => _buildNode(context, child)).toList(),
          ),
        ),
      );
    }

    if (node.level == SyllabusLevel.topic) {
      return Padding(
        padding: const EdgeInsets.only(left: 32.0),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(Icons.subdirectory_arrow_right, size: 20, color: t.textMuted),
            title: Text(
              node.title,
              style: TextStyle(
                fontSize: 14,
                color: t.text,
              ),
            ),
            iconColor: t.primary,
            collapsedIconColor: t.textMuted,
            childrenPadding: EdgeInsets.zero,
            children: node.children.map((child) => _buildNode(context, child)).toList(),
          ),
        ),
      );
    }

    // Fallback
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          node.title,
          style: TextStyle(color: t.text),
        ),
        iconColor: t.primary,
        collapsedIconColor: t.textMuted,
        children: node.children.map((child) => _buildNode(context, child)).toList(),
      ),
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
