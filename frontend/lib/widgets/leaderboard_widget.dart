import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Data for a single leaderboard entry.
class LeaderboardEntry {
  final int rank;
  final String initials;
  final String name;
  final int xp;
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.rank,
    required this.initials,
    required this.name,
    required this.xp,
    this.isCurrentUser = false,
  });
}

/// Default mock leaderboard data.
final List<LeaderboardEntry> defaultLeaderboard = const [
  LeaderboardEntry(rank: 1, initials: 'RK', name: 'Ravi Kumar', xp: 2480),
  LeaderboardEntry(rank: 2, initials: 'A', name: 'You', xp: 1240, isCurrentUser: true),
  LeaderboardEntry(rank: 3, initials: 'SK', name: 'Sunita K.', xp: 1180),
  LeaderboardEntry(rank: 4, initials: 'MP', name: 'Manish P.', xp: 1050),
  LeaderboardEntry(rank: 5, initials: 'PD', name: 'Priya D.', xp: 980),
];

/// Weekly leaderboard card — shows rank, avatar, name, and XP.
///
/// Highlights the current user's row with the secondary accent colour.
class LeaderboardWidget extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final String title;

  const LeaderboardWidget({
    super.key,
    this.entries = const [],
    this.title = "This week's leaders",
  });

  @override
  Widget build(BuildContext context) {
    final t = BpscThemeData.of(context);
    final data = entries.isEmpty ? defaultLeaderboard : entries;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.cardSurface,
        borderRadius: BorderRadius.circular(t.radius),
        border: Border.all(color: t.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontFamily: t.displayFontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: t.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          ...data.map((entry) => _LeaderboardRow(entry: entry)),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatefulWidget {
  final LeaderboardEntry entry;

  const _LeaderboardRow({required this.entry});

  @override
  State<_LeaderboardRow> createState() => _LeaderboardRowState();
}

class _LeaderboardRowState extends State<_LeaderboardRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final t = BpscThemeData.of(context);
    final entry = widget.entry;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: entry.isCurrentUser
              ? t.secondarySoft
              : _isHovered
                  ? t.surfaceAlt
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(t.radius - 6),
        ),
        child: Row(
          children: [
            // Rank
            SizedBox(
              width: 22,
              child: Text(
                '${entry.rank}',
                style: TextStyle(
                  fontFamily: t.displayFontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: entry.isCurrentUser ? t.secondary : t.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Avatar
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.primarySoft,
              ),
              child: Center(
                child: Text(
                  entry.initials,
                  style: TextStyle(
                    fontFamily: t.displayFontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: t.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Name
            Expanded(
              child: Text(
                entry.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: t.text,
                ),
              ),
            ),
            // XP
            Text(
              '${_formatXp(entry.xp)} XP',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: t.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatXp(int xp) {
    if (xp >= 1000) {
      return '${(xp / 1000).toStringAsFixed(xp % 1000 == 0 ? 0 : 1)}k'.replaceAll('.0k', 'k');
    }
    return xp.toString();
  }
}
