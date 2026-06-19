import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'widgets/app_sidebar.dart';
import 'screens/dashboard_screen.dart';
import 'screens/syllabus_screen.dart';
import 'screens/prelims_arena_screen.dart';
import 'screens/mains_writing_screen.dart';
import 'screens/daily_quiz_screen.dart';
import 'screens/stub_screens.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const BpscEngineApp());
}

/// Root application widget.
///
/// Uses the BPSC Saathi 3-theme system (Vibrant / Professional / Dark Tech).
/// Wraps the widget tree with [BpscThemeInherited] for themed access
/// and adapts layout between mobile (BottomNavigationBar) and desktop (custom sidebar).
class BpscEngineApp extends StatefulWidget {
  const BpscEngineApp({super.key});

  @override
  State<BpscEngineApp> createState() => _BpscEngineAppState();
}

class _BpscEngineAppState extends State<BpscEngineApp> {
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  void initState() {
    super.initState();
    _themeProvider.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_onThemeChanged);
    _themeProvider.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {}); // Rebuild when theme changes
  }

  @override
  Widget build(BuildContext context) {
    final bpscTheme = _themeProvider.bpscTheme;
    final materialTheme = _themeProvider.materialTheme;

    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..init(),
      child: BpscThemeInherited(
        themeData: bpscTheme,
        child: MaterialApp(
          title: 'BPSC Saathi',
          debugShowCheckedModeBanner: false,
          theme: materialTheme,
          home: _AuthGate(themeProvider: _themeProvider),
        ),
      ),
    );
  }
}

/// Auth gate — shows LoginScreen or AppShell based on auth state.
class _AuthGate extends StatelessWidget {
  final ThemeProvider themeProvider;
  const _AuthGate({required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) {
      final t = BpscThemeData.of(context);
      return Scaffold(
        backgroundColor: t.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: t.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(color: t.textMuted, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }

    return AppShell(themeProvider: themeProvider);
  }
}

/// The main scaffold with adaptive navigation.
///
/// Sidebar order:
///   0 = Home
///   1 = Syllabus
///   2 = Prelims
///   3 = Mains
///   4 = Daily Quiz
///   5 = Profile
class AppShell extends StatefulWidget {
  final ThemeProvider themeProvider;

  const AppShell({super.key, required this.themeProvider});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    DashboardScreen(),       // 0 = Home
    SyllabusScreen(),        // 1 = Syllabus
    PrelimsArenaScreen(),    // 2 = Prelims
    MainsWritingScreen(),    // 3 = Mains
    DailyQuizScreen(),       // 4 = Daily Quiz
    ProfileScreen(),         // 5 = Profile
  ];

  // Mobile bottom nav (condensed to 5 — Syllabus is accessible from sidebar only)
  static const List<NavigationDestination> _mobileDestinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.quiz_outlined),
      selectedIcon: Icon(Icons.quiz_rounded),
      label: 'Prelims',
    ),
    NavigationDestination(
      icon: Icon(Icons.bolt_outlined),
      selectedIcon: Icon(Icons.bolt_rounded),
      label: 'Daily Quiz',
    ),
    NavigationDestination(
      icon: Icon(Icons.edit_document),
      selectedIcon: Icon(Icons.edit_document),
      label: 'Mains',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = BpscThemeData.of(context);

    return NotificationListener<DailyQuizNavigationNotification>(
      onNotification: (_) {
        _onDestinationSelected(4); // Navigate to Daily Quiz
        return true;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth >= 800;

          if (isWideScreen) {
            // ─── Desktop Layout: Custom Sidebar + Content ─────────
            return Scaffold(
              backgroundColor: t.bg,
              body: Row(
                children: [
                  AppSidebar(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _onDestinationSelected,
                    streakDays: 12, // TODO: wire to real streak
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        // Theme switcher bar
                        _ThemeSwitcherBar(
                          themeProvider: widget.themeProvider,
                        ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _screens[_selectedIndex],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // ─── Mobile Layout: Bottom Nav ────────────────────────────
          final mobileIndex = _mapToMobileIndex(_selectedIndex);
          return Scaffold(
            backgroundColor: t.bg,
            body: _screens[_selectedIndex],
            bottomNavigationBar: NavigationBar(
              selectedIndex: mobileIndex,
              onDestinationSelected: (i) {
                _onDestinationSelected(_mapFromMobileIndex(i));
              },
              destinations: _mobileDestinations,
            ),
          );
        },
      ),
    );
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Desktop has 6 items, mobile has 5 (no Syllabus in mobile bottom bar).
  // Desktop: 0=Home, 1=Syllabus, 2=Prelims, 3=Mains, 4=DailyQuiz, 5=Profile
  // Mobile:  0=Home, 1=Prelims, 2=DailyQuiz, 3=Mains, 4=Profile
  int _mapToMobileIndex(int desktopIndex) {
    switch (desktopIndex) {
      case 0: return 0; // Home
      case 1: return 0; // Syllabus → Home (no mobile equiv)
      case 2: return 1; // Prelims
      case 3: return 3; // Mains
      case 4: return 2; // Daily Quiz
      case 5: return 4; // Profile
      default: return 0;
    }
  }

  int _mapFromMobileIndex(int mobileIndex) {
    switch (mobileIndex) {
      case 0: return 0; // Home
      case 1: return 2; // Prelims
      case 2: return 4; // Daily Quiz
      case 3: return 3; // Mains
      case 4: return 5; // Profile
      default: return 0;
    }
  }
}

/// Compact theme switcher bar — sits above the main content on desktop.
class _ThemeSwitcherBar extends StatelessWidget {
  final ThemeProvider themeProvider;

  const _ThemeSwitcherBar({required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    final t = BpscThemeData.of(context);
    final currentMode = themeProvider.mode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(bottom: BorderSide(color: t.borderColor, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Theme:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: t.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          for (final mode in AppThemeMode.values)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: _ThemeChip(
                label: _label(mode),
                isActive: currentMode == mode,
                onTap: () => themeProvider.setTheme(mode),
              ),
            ),
        ],
      ),
    );
  }

  String _label(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.vibrant:
        return 'Vibrant';
      case AppThemeMode.professional:
        return 'Professional';
      case AppThemeMode.darkTech:
        return 'Dark Tech';
    }
  }
}

/// Individual theme selection chip.
class _ThemeChip extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_ThemeChip> createState() => _ThemeChipState();
}

class _ThemeChipState extends State<_ThemeChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final t = BpscThemeData.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: widget.isActive ? t.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: widget.isActive
                  ? t.primary
                  : _isHovered
                      ? t.primary.withValues(alpha: 0.4)
                      : t.borderColor,
              width: 1.5,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: widget.isActive
                  ? (t.brightness == Brightness.dark ? t.bg : Colors.white)
                  : t.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
