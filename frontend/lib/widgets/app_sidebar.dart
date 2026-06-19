import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'diya_icon.dart';

/// Sidebar navigation item descriptor.
class SidebarItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Default navigation items — exact sidebar order per user spec.
const List<SidebarItem> defaultSidebarItems = [
  SidebarItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
  SidebarItem(icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book_rounded, label: 'Syllabus'),
  SidebarItem(icon: Icons.quiz_outlined, activeIcon: Icons.quiz_rounded, label: 'Prelims'),
  SidebarItem(icon: Icons.edit_document, activeIcon: Icons.edit_document, label: 'Mains'),
  SidebarItem(icon: Icons.bolt_outlined, activeIcon: Icons.bolt_rounded, label: 'Daily Quiz'),
  SidebarItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
];

/// Custom sidebar matching the BPSC Saathi HTML prototype.
///
/// Features:
/// - Diya brand icon + app name
/// - Navigation items with active indicator
/// - Streak footer with animated diya
class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final int streakDays;
  final List<SidebarItem> items;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.streakDays = 0,
    this.items = defaultSidebarItems,
  });

  @override
  Widget build(BuildContext context) {
    final t = BpscThemeData.of(context);
    final isDark = t.brightness == Brightness.dark;
    final isPro = t.sidebar == AppColors.proSidebar;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 240,
      decoration: BoxDecoration(
        color: t.sidebar,
        border: (isDark || isPro)
            ? null
            : Border(right: BorderSide(color: t.borderColor)),
      ),
      child: Column(
        children: [
          // ── Brand ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 18, 0),
            child: Row(
              children: [
                DiyaIcon(size: 38),
                const SizedBox(width: 10),
                Text(
                  'BPSC Saathi',
                  style: TextStyle(
                    fontFamily: t.displayFontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _brandNameColor(t, isDark, isPro),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Navigation Items ──────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  for (int i = 0; i < items.length; i++)
                    _NavItem(
                      item: items[i],
                      isActive: i == selectedIndex,
                      onTap: () => onDestinationSelected(i),
                    ),
                ],
              ),
            ),
          ),

          // ── Streak Footer ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (isDark || isPro)
                    ? Colors.white.withValues(alpha: 0.05)
                    : t.surfaceAlt,
                borderRadius: BorderRadius.circular(t.radius),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'STREAK',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _footerMutedColor(t, isDark, isPro),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$streakDays day${streakDays == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontFamily: t.displayFontFamily,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _footerCountColor(t, isDark, isPro),
                        ),
                      ),
                    ],
                  ),
                  DiyaIcon(size: 34),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _brandNameColor(BpscThemeData t, bool isDark, bool isPro) {
    if (isDark) return t.text;
    if (isPro) return Colors.white;
    return t.text;
  }

  Color _footerMutedColor(BpscThemeData t, bool isDark, bool isPro) {
    if (isDark || isPro) return Colors.white60;
    return t.textMuted;
  }

  Color _footerCountColor(BpscThemeData t, bool isDark, bool isPro) {
    if (isDark) return t.text;
    if (isPro) return Colors.white;
    return t.text;
  }
}

/// A single sidebar navigation item.
class _NavItem extends StatefulWidget {
  final SidebarItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final t = BpscThemeData.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? t.primarySoft
                  : _isHovered
                      ? t.primarySoft.withValues(alpha: 0.4)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(t.radius),
              border: Border(
                left: BorderSide(
                  color: widget.isActive ? t.primary : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.isActive ? widget.item.activeIcon : widget.item.icon,
                  size: 18,
                  color: widget.isActive ? t.primary : t.textMuted,
                ),
                const SizedBox(width: 12),
                Text(
                  widget.item.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.isActive ? t.primary : t.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
