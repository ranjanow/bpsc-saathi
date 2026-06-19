import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../models/syllabus_model.dart';
import '../widgets/syllabus_tree_widget.dart';

/// Dedicated Syllabus screen — complete BPSC Prelims + Mains syllabus.
///
/// Features:
/// - Tab bar for Prelims / Mains toggle
/// - Full tree navigation via [SyllabusTreeWidget]
/// - Search/filter across all nodes
class SyllabusScreen extends StatefulWidget {
  const SyllabusScreen({super.key});

  @override
  State<SyllabusScreen> createState() => _SyllabusScreenState();
}

class _SyllabusScreenState extends State<SyllabusScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<SyllabusNode> _filterNodes(List<SyllabusNode> nodes, String query) {
    if (query.isEmpty) return nodes;
    final lowerQuery = query.toLowerCase();

    List<SyllabusNode> filtered = [];
    for (final node in nodes) {
      final childMatches = _filterNodes(node.children, query);
      if (node.title.toLowerCase().contains(lowerQuery) ||
          childMatches.isNotEmpty) {
        filtered.add(SyllabusNode(
          title: node.title,
          level: node.level,
          children: childMatches.isNotEmpty ? childMatches : node.children,
        ));
      }
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final t = BpscThemeData.of(context);
    final isDark = t.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SYLLABUS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: t.textMuted,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete BPSC Syllabus',
                  style: TextStyle(
                    fontFamily: t.displayFontFamily,
                    fontSize: isDark ? 24 : 28,
                    fontWeight: FontWeight.w800,
                    color: t.text,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Prelims GS Paper I & Mains GS Papers I–IV',
                  style: TextStyle(fontSize: 14, color: t.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Search Bar ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              decoration: BoxDecoration(
                color: t.cardSurface,
                borderRadius: BorderRadius.circular(t.radius),
                border: Border.all(color: t.borderColor),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(
                  fontFamily: t.bodyFontFamily,
                  fontSize: 14,
                  color: t.text,
                ),
                decoration: InputDecoration(
                  hintText: 'Search topics...',
                  hintStyle: TextStyle(color: t.textMuted, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: t.textMuted, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Tab Bar ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              decoration: BoxDecoration(
                color: t.surfaceAlt,
                borderRadius: BorderRadius.circular(t.radius),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: t.primary,
                  borderRadius: BorderRadius.circular(t.radius),
                ),
                labelColor: isDark ? t.bg : Colors.white,
                unselectedLabelColor: t.textMuted,
                labelStyle: TextStyle(
                  fontFamily: t.bodyFontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: TextStyle(
                  fontFamily: t.bodyFontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerHeight: 0,
                tabs: const [
                  Tab(text: 'Prelims'),
                  Tab(text: 'Mains'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Syllabus Tree ───────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Prelims tab
                _buildSyllabusTab(
                  SyllabusNode.bpscPrelimsSyllabus,
                  t,
                ),
                // Mains tab
                _buildSyllabusTab(
                  SyllabusNode.bpscMainsSyllabus,
                  t,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyllabusTab(List<SyllabusNode> nodes, BpscThemeData t) {
    final filtered = _filterNodes(nodes, _searchQuery);

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: t.textMuted),
            const SizedBox(height: 12),
            Text(
              'No topics match "$_searchQuery"',
              style: TextStyle(fontSize: 14, color: t.textMuted),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        decoration: BoxDecoration(
          color: t.cardSurface,
          borderRadius: BorderRadius.circular(t.radius),
          border: Border.all(color: t.borderColor),
        ),
        child: SyllabusTreeWidget(nodes: filtered),
      ),
    );
  }
}
