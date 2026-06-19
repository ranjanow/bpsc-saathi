import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';

/// Full-featured Profile screen with backend integration.
///
/// Features:
/// - Displays user info (name, bio, target exam, language pref)
/// - Shows stats (XP, streak, quizzes taken, accuracy)
/// - Allows editing profile fields
/// - Connects to GET /api/v1/profile, PUT /api/v1/profile, GET /api/v1/profile/stats
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  String? _error;

  // Profile fields
  String _name = '';
  String _email = '';
  String _bio = '';
  String _targetExam = '';
  String _preferredLanguage = 'both';
  String _joinedAt = '';

  // Stats
  int _totalXp = 0;
  int _streakDays = 0;
  int _quizzesTaken = 0;
  double _accuracy = 0.0;

  bool _isEditing = false;

  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _targetExamController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _targetExamController = TextEditingController();
    _fetchProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _targetExamController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profileRes = await http.get(
        Uri.parse('http://localhost:8080/api/v1/profile'),
        headers: {'Content-Type': 'application/json'},
      );

      if (profileRes.statusCode == 200) {
        final data = json.decode(profileRes.body);
        if (mounted) {
          setState(() {
            _name = data['name'] ?? '';
            _email = data['email'] ?? '';
            _bio = data['bio'] ?? '';
            _targetExam = data['targetExam'] ?? '';
            _preferredLanguage = data['preferredLanguage'] ?? 'both';
            _joinedAt = data['joinedAt'] ?? '';
            _totalXp = data['totalXp'] ?? 0;
            _streakDays = data['streakDays'] ?? 0;
            _quizzesTaken = data['quizzesTaken'] ?? 0;
            _accuracy = (data['accuracy'] ?? 0.0).toDouble();
            _isLoading = false;

            _nameController.text = _name;
            _bioController.text = _bio;
            _targetExamController.text = _targetExam;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load profile (${profileRes.statusCode})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Connection error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    final updates = <String, dynamic>{};
    if (_nameController.text != _name) updates['name'] = _nameController.text;
    if (_bioController.text != _bio) updates['bio'] = _bioController.text;
    if (_targetExamController.text != _targetExam) {
      updates['targetExam'] = _targetExamController.text;
    }
    updates['preferredLanguage'] = _preferredLanguage;

    if (updates.isEmpty) {
      setState(() => _isEditing = false);
      return;
    }

    try {
      final res = await http.put(
        Uri.parse('http://localhost:8080/api/v1/profile'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updates),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _name = data['name'] ?? _name;
            _bio = data['bio'] ?? _bio;
            _targetExam = data['targetExam'] ?? _targetExam;
            _preferredLanguage = data['preferredLanguage'] ?? _preferredLanguage;
            _isEditing = false;
          });
        }
      }
    } catch (e) {
      // Silently fail — user can retry
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = BpscThemeData.of(context);
    final isDark = t.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: t.bg,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: t.primary))
          : _error != null
              ? _buildError(t)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Text(
                        'PROFILE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: t.textMuted,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your Account',
                        style: TextStyle(
                          fontFamily: t.displayFontFamily,
                          fontSize: isDark ? 24 : 28,
                          fontWeight: FontWeight.w800,
                          color: t.text,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Stats Cards
                      _buildStatsRow(t, isDark),
                      const SizedBox(height: 24),

                      // Profile Card
                      _buildProfileCard(t, isDark),
                      const SizedBox(height: 20),

                      // Preferences Card
                      _buildPreferencesCard(t, isDark),
                      const SizedBox(height: 24),

                      // Logout button
                      _buildLogoutButton(t, isDark),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError(BpscThemeData t) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: t.primary),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: t.textMuted, fontSize: 14)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _fetchProfile,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: t.primary,
              foregroundColor: t.brightness == Brightness.dark ? t.bg : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BpscThemeData t, bool isDark) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 600;
      final stats = [
        _StatTile(
          icon: Icons.star_rounded,
          label: 'Total XP',
          value: '$_totalXp',
          color: t.primary,
          t: t,
        ),
        _StatTile(
          icon: Icons.local_fire_department_rounded,
          label: 'Streak',
          value: '$_streakDays days',
          color: Colors.orange.shade600,
          t: t,
        ),
        _StatTile(
          icon: Icons.quiz_rounded,
          label: 'Quizzes',
          value: '$_quizzesTaken',
          color: t.secondary,
          t: t,
        ),
        _StatTile(
          icon: Icons.gps_fixed,
          label: 'Accuracy',
          value: '${_accuracy.toStringAsFixed(1)}%',
          color: Colors.green.shade600,
          t: t,
        ),
      ];

      if (isWide) {
        return Row(
          children: stats
              .map((s) => Expanded(child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: s,
                  )))
              .toList(),
        );
      }

      return Column(
        children: [
          Row(children: [
            Expanded(child: stats[0]),
            const SizedBox(width: 12),
            Expanded(child: stats[1]),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: stats[2]),
            const SizedBox(width: 12),
            Expanded(child: stats[3]),
          ]),
        ],
      );
    });
  }

  Widget _buildProfileCard(BpscThemeData t, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: t.cardSurface,
        borderRadius: BorderRadius.circular(t.radius),
        border: Border.all(color: t.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.primarySoft,
                ),
                child: Center(
                  child: Text(
                    _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontFamily: t.displayFontFamily,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: t.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isEditing)
                      _buildEditField(_nameController, 'Name', t)
                    else
                      Text(
                        _name,
                        style: TextStyle(
                          fontFamily: t.displayFontFamily,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: t.text,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      _email,
                      style: TextStyle(fontSize: 13, color: t.textMuted),
                    ),
                  ],
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    if (_isEditing) {
                      _saveProfile();
                    } else {
                      setState(() => _isEditing = true);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isEditing ? t.primary : t.surfaceAlt,
                      borderRadius: BorderRadius.circular(t.radius),
                    ),
                    child: Text(
                      _isEditing ? 'Save' : 'Edit',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isEditing
                            ? (isDark ? t.bg : Colors.white)
                            : t.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bio
          _buildFieldRow('Bio', _isEditing ? null : _bio, t,
              editWidget:
                  _isEditing ? _buildEditField(_bioController, 'Bio', t) : null),
          const SizedBox(height: 12),

          // Target Exam
          _buildFieldRow(
              'Target Exam', _isEditing ? null : _targetExam, t,
              editWidget: _isEditing
                  ? _buildEditField(_targetExamController, 'Target Exam', t)
                  : null),
          const SizedBox(height: 12),

          // Joined
          _buildFieldRow('Member Since', _formatDate(_joinedAt), t),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard(BpscThemeData t, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: t.cardSurface,
        borderRadius: BorderRadius.circular(t.radius),
        border: Border.all(color: t.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferences',
            style: TextStyle(
              fontFamily: t.displayFontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: t.text,
            ),
          ),
          const SizedBox(height: 16),

          // Language preference
          Text(
            'Preferred Language',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: t.textMuted,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _PrefChip(
                label: 'English',
                isActive: _preferredLanguage == 'en',
                onTap: () => setState(() => _preferredLanguage = 'en'),
                t: t,
              ),
              const SizedBox(width: 8),
              _PrefChip(
                label: 'हिंदी',
                isActive: _preferredLanguage == 'hi',
                onTap: () => setState(() => _preferredLanguage = 'hi'),
                t: t,
              ),
              const SizedBox(width: 8),
              _PrefChip(
                label: 'Both',
                isActive: _preferredLanguage == 'both',
                onTap: () => setState(() => _preferredLanguage = 'both'),
                t: t,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BpscThemeData t, bool isDark) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: t.cardSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(t.radius),
              ),
              title: Text('Logout', style: TextStyle(color: t.text)),
              content: Text(
                'Are you sure you want to logout?',
                style: TextStyle(color: t.textMuted),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancel', style: TextStyle(color: t.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.read<AuthProvider>().logout();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Logout'),
                ),
              ],
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(t.radius),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, size: 20, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldRow(String label, String? value, BpscThemeData t,
      {Widget? editWidget}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: t.textMuted,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        editWidget ??
            Text(
              value ?? '—',
              style: TextStyle(fontSize: 14, color: t.text),
            ),
      ],
    );
  }

  Widget _buildEditField(
      TextEditingController controller, String hint, BpscThemeData t) {
    return Container(
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(t.radius),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(fontSize: 14, color: t.text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: t.textMuted),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '—';
    try {
      final dt = DateTime.parse(isoDate);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final BpscThemeData t;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.cardSurface,
        borderRadius: BorderRadius.circular(t.radius),
        border: Border.all(color: t.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontFamily: t.displayFontFamily,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: t.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: t.textMuted),
          ),
        ],
      ),
    );
  }
}

class _PrefChip extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final BpscThemeData t;

  const _PrefChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.t,
  });

  @override
  State<_PrefChip> createState() => _PrefChipState();
}

class _PrefChipState extends State<_PrefChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: widget.isActive ? widget.t.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: widget.isActive
                  ? widget.t.primary
                  : _hovered
                      ? widget.t.primary.withValues(alpha: 0.4)
                      : widget.t.borderColor,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: widget.isActive
                  ? (widget.t.brightness == Brightness.dark
                      ? widget.t.bg
                      : Colors.white)
                  : widget.t.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
