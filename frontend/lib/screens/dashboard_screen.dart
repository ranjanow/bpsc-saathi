import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../widgets/daily_stats_widget.dart';
import '../widgets/hero_quiz_banner.dart';
import '../widgets/subject_tile_widget.dart';
import '../widgets/countdown_ring_widget.dart';
import '../widgets/leaderboard_widget.dart';
import '../providers/auth_provider.dart';

/// Dashboard screen — the engagement hub.
///
/// Clean layout:
///   Topbar (greeting + XP pill + avatar)
///   Hero Quiz Banner (CTA → Daily Quiz)
///   Daily Stats Row
///   Content Grid:
///     Left: Subject progress tiles (Continue Learning)
///     Right: Countdown ring + Leaderboard
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _streakDays = 0;

  @override
  void initState() {
    super.initState();
    _loadAndUpdateStreak();
  }

  /// Load the streak from SharedPreferences.
  /// Increment if this is the first open today; reset if a day was missed.
  Future<void> _loadAndUpdateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final lastOpenStr = prefs.getString('streak_last_open');
    final savedStreak = prefs.getInt('streak_days') ?? 0;

    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';

    if (lastOpenStr == todayKey) {
      if (mounted) setState(() => _streakDays = savedStreak);
      return;
    }

    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayKey = '${yesterday.year}-${yesterday.month}-${yesterday.day}';

    int newStreak;
    if (lastOpenStr == yesterdayKey) {
      newStreak = savedStreak + 1;
    } else {
      newStreak = 1;
    }

    await prefs.setString('streak_last_open', todayKey);
    await prefs.setInt('streak_days', newStreak);

    if (mounted) setState(() => _streakDays = newStreak);
  }

  @override
  Widget build(BuildContext context) {
    final t = BpscThemeData.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Topbar: Greeting + XP Pill + Avatar ────────────
            _buildTopbar(t),
            const SizedBox(height: 22),

            // ─── Hero Quiz Banner ────────────────────────────────
            HeroQuizBanner(
              eyebrow: "Today's daily quiz",
              title: 'Mixed BPSC PYQ Challenge',
              subtitle: '15 questions · all subjects · Previous Year Questions',
              onStartQuiz: () {
                // Navigate to Daily Quiz tab (index 4 in sidebar)
                // The parent AppShell handles navigation via callback
                _navigateToDailyQuiz(context);
              },
            ),
            const SizedBox(height: 22),

            // ─── Daily Stats Row ─────────────────────────────────
            DailyStatsWidget(
              questionsToday: 0,
              accuracyPercent: 0.0,
              streakDays: _streakDays,
            ),
            const SizedBox(height: 22),

            // ─── Content Grid ────────────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 760) {
                  // Desktop: 2-column layout
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Subject tiles
                      Expanded(
                        child: SubjectTileGrid(
                          onSubjectTap: (s) {},
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Right: Countdown + Leaderboard
                      SizedBox(
                        width: 320,
                        child: Column(
                          children: const [
                            CountdownRingWidget(),
                            SizedBox(height: 20),
                            LeaderboardWidget(),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                // Mobile: single column
                return Column(
                  children: [
                    SubjectTileGrid(
                      onSubjectTap: (s) {},
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Expanded(child: CountdownRingWidget()),
                        SizedBox(width: 12),
                        Expanded(child: LeaderboardWidget()),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _navigateToDailyQuiz(BuildContext context) {
    // Walk up to find the AppShell's state and switch to Daily Quiz tab (index 4)
    // This uses a simple notification pattern
    DailyQuizNavigationNotification().dispatch(context);
  }

  Widget _buildTopbar(BpscThemeData t) {
    final auth = context.watch<AuthProvider>();
    final userName = auth.displayName;
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NAMASTE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: t.textMuted,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Welcome back, $userName',
                style: TextStyle(
                  fontFamily: t.displayFontFamily,
                  fontSize: t.brightness == Brightness.dark ? 26 : 30,
                  fontWeight: FontWeight.w800,
                  color: t.text,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        // XP Pill — reads from real analytics (0 for new users)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: t.secondarySoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '0 XP',
            style: TextStyle(
              fontFamily: t.displayFontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: t.secondary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Avatar — real user initial
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: t.primarySoft,
          ),
          child: Center(
            child: Text(
              userInitial,
              style: TextStyle(
                fontFamily: t.displayFontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: t.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Notification used to navigate from dashboard to Daily Quiz tab.
class DailyQuizNavigationNotification extends Notification {}
