import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';
import '../models/ecosystem_model.dart';
import '../env.dart';

/// Daily Quiz screen — serves 15 mixed-subject BPSC PYQ questions daily.
///
/// Features:
/// - Daily availability check (one quiz per day)
/// - 15 mixed PYQ questions from all BPSC subjects
/// - Bilingual display (Hindi + English)
/// - Progress tracking and scoring
class DailyQuizScreen extends StatefulWidget {
  const DailyQuizScreen({super.key});

  @override
  State<DailyQuizScreen> createState() => _DailyQuizScreenState();
}

class _DailyQuizScreenState extends State<DailyQuizScreen> {
  bool _isLoading = false;
  bool _quizCompleted = false;
  bool _quizStarted = false;
  String? _error;
  List<GeneratedQuestion> _questions = [];
  int _currentQuestion = 0;
  int? _selectedOption;
  bool _hasAnswered = false;
  int _correctCount = 0;
  int _answeredCount = 0;

  @override
  void initState() {
    super.initState();
    _checkDailyQuizStatus();
  }

  Future<void> _checkDailyQuizStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    final lastCompleted = prefs.getString('daily_quiz_last_completed');

    if (lastCompleted == todayKey) {
      if (mounted) {
        setState(() {
          _quizCompleted = true;
          _correctCount = prefs.getInt('daily_quiz_last_score') ?? 0;
        });
      }
    }
  }

  Future<void> _fetchDailyQuiz() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${Environment.apiUrl}/api/v1/daily-quiz'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final ecosystem = EcosystemResponse.fromJson(data);

        if (mounted) {
          setState(() {
            _questions = ecosystem.generatedQuestions;
            _isLoading = false;
            _quizStarted = true;
            _currentQuestion = 0;
            _selectedOption = null;
            _hasAnswered = false;
            _correctCount = 0;
            _answeredCount = 0;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load quiz (${response.statusCode}). Please try again.';
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

  void _selectOption(int index) {
    if (_hasAnswered) return;
    setState(() {
      _selectedOption = index;
      _hasAnswered = true;
      _answeredCount++;
      if (index == _questions[_currentQuestion].correctOptionIndex) {
        _correctCount++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestion < _questions.length - 1) {
      setState(() {
        _currentQuestion++;
        _selectedOption = null;
        _hasAnswered = false;
      });
    } else {
      _completeQuiz();
    }
  }

  Future<void> _completeQuiz() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    await prefs.setString('daily_quiz_last_completed', todayKey);
    await prefs.setInt('daily_quiz_last_score', _correctCount);

    if (mounted) {
      setState(() {
        _quizCompleted = true;
        _quizStarted = false;
      });
    }
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
            // Header
            Text(
              'DAILY QUIZ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: t.textMuted,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'BPSC Previous Year Questions',
              style: TextStyle(
                fontFamily: t.displayFontFamily,
                fontSize: t.brightness == Brightness.dark ? 24 : 28,
                fontWeight: FontWeight.w800,
                color: t.text,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '15 mixed-subject PYQs · One quiz per day · All subjects',
              style: TextStyle(fontSize: 14, color: t.textMuted),
            ),
            const SizedBox(height: 24),

            if (_isLoading) _buildLoading(t),
            if (_error != null) _buildError(t),
            if (_quizCompleted && !_quizStarted) _buildCompleted(t),
            if (!_isLoading && !_quizCompleted && !_quizStarted && _error == null)
              _buildStartCard(t),
            if (_quizStarted && _questions.isNotEmpty) _buildQuiz(t),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading(BpscThemeData t) {
    return Container(
      padding: const EdgeInsets.all(60),
      decoration: BoxDecoration(
        color: t.cardSurface,
        borderRadius: BorderRadius.circular(t.radius),
        border: Border.all(color: t.borderColor),
      ),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: t.primary),
            const SizedBox(height: 20),
            Text(
              'Generating your daily quiz...',
              style: TextStyle(
                fontFamily: t.bodyFontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: t.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fetching 15 real BPSC PYQs from our question bank',
              style: TextStyle(fontSize: 13, color: t.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BpscThemeData t) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: t.cardSurface,
        borderRadius: BorderRadius.circular(t.radius),
        border: Border.all(color: t.borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: t.primary),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: t.textMuted),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _fetchDailyQuiz,
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

  Widget _buildStartCard(BpscThemeData t) {
    final isDark = t.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: t.cardSurface,
        borderRadius: BorderRadius.circular(t.radius),
        border: Border.all(color: t.borderColor),
        gradient: isDark
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.centerRight,
                colors: [t.primarySoft, t.cardSurface],
                stops: const [0, 0.65],
              ),
      ),
      child: Column(
        children: [
          Icon(Icons.bolt_rounded, size: 64, color: t.primary),
          const SizedBox(height: 20),
          Text(
            "Today's Quiz is Ready!",
            style: TextStyle(
              fontFamily: t.displayFontFamily,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: t.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '15 real BPSC Previous Year Questions\nMixed subjects · Hindi & English',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: t.textMuted, height: 1.5),
          ),
          const SizedBox(height: 24),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _fetchDailyQuiz,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: t.primary,
                  borderRadius: BorderRadius.circular(t.radius),
                  boxShadow: isDark
                      ? [BoxShadow(color: t.primary.withValues(alpha: 0.4), blurRadius: 16)]
                      : [],
                ),
                child: Text(
                  'Start Daily Quiz',
                  style: TextStyle(
                    fontFamily: t.bodyFontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? t.bg : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleted(BpscThemeData t) {
    final accuracy = _answeredCount > 0
        ? (_correctCount / _answeredCount * 100).toStringAsFixed(1)
        : '0.0';

    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: t.cardSurface,
        borderRadius: BorderRadius.circular(t.radius),
        border: Border.all(color: t.borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_rounded, size: 64, color: t.secondary),
          const SizedBox(height: 20),
          Text(
            "Today's Quiz Complete! 🎉",
            style: TextStyle(
              fontFamily: t.displayFontFamily,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: t.text,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatPill(label: 'Score', value: '$_correctCount/15', color: t.primary, t: t),
              const SizedBox(width: 12),
              _StatPill(label: 'Accuracy', value: '$accuracy%', color: t.secondary, t: t),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Come back tomorrow for a new set of PYQs!',
            style: TextStyle(fontSize: 14, color: t.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildQuiz(BpscThemeData t) {
    final q = _questions[_currentQuestion];
    final isDark = t.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: t.cardSurface,
            borderRadius: BorderRadius.circular(t.radius),
            border: Border.all(color: t.borderColor),
          ),
          child: Row(
            children: [
              Text(
                'Question ${_currentQuestion + 1} of ${_questions.length}',
                style: TextStyle(
                  fontFamily: t.bodyFontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: t.text,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _difficultyColor(q.difficulty).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  q.difficulty.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _difficultyColor(q.difficulty),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: t.primarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  q.subject,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: t.primary,
                  ),
                ),
              ),
              if (q.pyqYear.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: t.secondarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    q.pyqYear,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: t.secondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Progress linear
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (_currentQuestion + 1) / _questions.length,
            backgroundColor: t.surfaceAlt,
            color: t.primary,
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 20),

        // Question card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: t.cardSurface,
            borderRadius: BorderRadius.circular(t.radius),
            border: Border.all(color: t.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // English question
              Text(
                q.questionEn,
                style: TextStyle(
                  fontFamily: t.bodyFontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: t.text,
                  height: 1.5,
                ),
              ),
              // Hindi question
              if (q.questionHi.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  q.questionHi,
                  style: TextStyle(
                    fontSize: 15,
                    color: t.textMuted,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Options
              for (int i = 0; i < q.optionsEn.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MouseRegion(
                    cursor: _hasAnswered ? SystemMouseCursors.basic : SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => _selectOption(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _optionBgColor(i, q, t, isDark),
                          borderRadius: BorderRadius.circular(t.radius),
                          border: Border.all(
                            color: _optionBorderColor(i, q, t),
                            width: _selectedOption == i ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _optionCircleColor(i, q, t),
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(65 + i),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _hasAnswered && i == q.correctOptionIndex
                                        ? Colors.white
                                        : t.textMuted,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    q.optionsEn[i],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: t.text,
                                    ),
                                  ),
                                  if (i < q.optionsHi.length && q.optionsHi[i].isNotEmpty)
                                    Text(
                                      q.optionsHi[i],
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: t.textMuted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (_hasAnswered && i == q.correctOptionIndex)
                              Icon(Icons.check_circle, color: Colors.green.shade600, size: 22),
                            if (_hasAnswered && i == _selectedOption && i != q.correctOptionIndex)
                              Icon(Icons.cancel, color: Colors.red.shade600, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Explanation (shown after answering)
              if (_hasAnswered) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: t.surfaceAlt,
                    borderRadius: BorderRadius.circular(t.radius),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📖 Explanation',
                        style: TextStyle(
                          fontFamily: t.displayFontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: t.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        q.explanationEn,
                        style: TextStyle(fontSize: 14, color: t.text, height: 1.5),
                      ),
                      if (q.explanationHi.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          q.explanationHi,
                          style: TextStyle(fontSize: 13, color: t.textMuted, height: 1.5),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _nextQuestion,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: t.primary,
                          borderRadius: BorderRadius.circular(t.radius),
                        ),
                        child: Text(
                          _currentQuestion < _questions.length - 1
                              ? 'Next Question →'
                              : 'Finish Quiz ✓',
                          style: TextStyle(
                            fontFamily: t.bodyFontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? t.bg : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Color _difficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green.shade600;
      case 'medium':
        return Colors.orange.shade700;
      case 'hard':
        return Colors.red.shade600;
      default:
        return Colors.grey;
    }
  }

  Color _optionBgColor(int i, GeneratedQuestion q, BpscThemeData t, bool isDark) {
    if (!_hasAnswered) {
      return _selectedOption == i ? t.primarySoft : t.cardSurface;
    }
    if (i == q.correctOptionIndex) {
      return Colors.green.shade50;
    }
    if (i == _selectedOption) {
      return Colors.red.shade50;
    }
    return t.cardSurface;
  }

  Color _optionBorderColor(int i, GeneratedQuestion q, BpscThemeData t) {
    if (!_hasAnswered) {
      return _selectedOption == i ? t.primary : t.borderColor;
    }
    if (i == q.correctOptionIndex) {
      return Colors.green.shade600;
    }
    if (i == _selectedOption) {
      return Colors.red.shade600;
    }
    return t.borderColor;
  }

  Color _optionCircleColor(int i, GeneratedQuestion q, BpscThemeData t) {
    if (_hasAnswered && i == q.correctOptionIndex) {
      return Colors.green.shade600;
    }
    return t.surfaceAlt;
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final BpscThemeData t;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(t.radius),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: t.displayFontFamily,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: t.textMuted),
          ),
        ],
      ),
    );
  }
}
