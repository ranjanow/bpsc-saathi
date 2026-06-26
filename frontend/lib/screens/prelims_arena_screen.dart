import 'dart:async';

import 'package:flutter/material.dart';

import '../models/ecosystem_model.dart';
import '../services/api_service.dart';
import '../services/prelims_pdf_exporter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BPSC Official Marking Constants
// ─────────────────────────────────────────────────────────────────────────────
const double _kCorrectMark = 1.00;
const double _kIncorrectPenalty = -0.33;
const double _kSkippedMark = 0.00;

/// Seconds allocated per question in Exam Mode.
const int _kSecondsPerQuestion = 60;

// ─────────────────────────────────────────────────────────────────────────────
// Screen lifecycle state machine.
// ─────────────────────────────────────────────────────────────────────────────
enum _ScreenState { idle, loading, success, error }

// ─────────────────────────────────────────────────────────────────────────────
// Per-question answer result after the user locks in.
// ─────────────────────────────────────────────────────────────────────────────
enum _QuestionResult { correct, incorrect, skipped }

// ─────────────────────────────────────────────────────────────────────────────
// QuestionLedgerEntry — immutable snapshot of a single question's contribution
// to the session score.
// ─────────────────────────────────────────────────────────────────────────────
class _QuestionLedgerEntry {
  final String questionId;
  final String subject;
  final _QuestionResult result;
  final double mark; // +1.00 | -0.33 | 0.00
  final bool isGuessworkAttempt;

  const _QuestionLedgerEntry({
    required this.questionId,
    required this.subject,
    required this.result,
    required this.mark,
    required this.isGuessworkAttempt,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SessionScoreNotifier — single source of truth for all scoring.
// ─────────────────────────────────────────────────────────────────────────────
class SessionScoreNotifier extends ChangeNotifier {
  final Map<String, _QuestionLedgerEntry> _ledger = {};
  int totalQuestions = 0;

  // ── Derived metrics ────────────────────────────────────────────────────────

  double get netScore =>
      _ledger.values.fold(0.0, (sum, e) => sum + e.mark);

  int get answeredCount => _ledger.values
      .where((e) => e.result != _QuestionResult.skipped)
      .length;

  int get correctCount =>
      _ledger.values.where((e) => e.result == _QuestionResult.correct).length;

  int get incorrectCount =>
      _ledger.values.where((e) => e.result == _QuestionResult.incorrect).length;

  int get skippedCount =>
      _ledger.values.where((e) => e.result == _QuestionResult.skipped).length;

  double get accuracyPercent {
    if (answeredCount == 0) return 0.0;
    return (correctCount / answeredCount) * 100.0;
  }

  double get penaltiesAccrued => incorrectCount * _kIncorrectPenalty.abs();

  Map<String, double> get subjectScores {
    final Map<String, double> scores = {};
    for (final entry in _ledger.values) {
      scores[entry.subject] = (scores[entry.subject] ?? 0.0) + entry.mark;
    }
    return scores;
  }

  // ── Ledger mutation ────────────────────────────────────────────────────────

  void recordAnswer({
    required String questionId,
    required String subject,
    required int? selectedOption,
    required int correctIndex,
    required bool isGuesswork,
  }) {
    final _QuestionResult result;
    final double mark;

    if (selectedOption == null) {
      result = _QuestionResult.skipped;
      mark = _kSkippedMark;
    } else if (selectedOption == correctIndex) {
      result = _QuestionResult.correct;
      mark = _kCorrectMark;
    } else {
      result = _QuestionResult.incorrect;
      mark = _kIncorrectPenalty;
    }

    _ledger[questionId] = _QuestionLedgerEntry(
      questionId: questionId,
      subject: subject,
      result: result,
      mark: mark,
      isGuessworkAttempt: isGuesswork,
    );

    notifyListeners();
  }

  void clearAnswer(String questionId) {
    if (_ledger.remove(questionId) != null) notifyListeners();
  }

  void resetSession(int questionCount) {
    _ledger.clear();
    totalQuestions = questionCount;
    notifyListeners();
  }

  // ── Risk Profile Compiler ──────────────────────────────────────────────────

  String compileRiskProfile() {
    if (_ledger.isEmpty) {
      return 'No questions answered yet. Complete the session to see your risk profile.';
    }

    final guessEntries =
        _ledger.values.where((e) => e.isGuessworkAttempt).toList();
    final guessCorrect =
        guessEntries.where((e) => e.result == _QuestionResult.correct).length;
    final guessIncorrect =
        guessEntries.where((e) => e.result == _QuestionResult.incorrect).length;
    final guessTotal = guessEntries.length;
    final guessMarkImpact =
        guessEntries.fold(0.0, (sum, e) => sum + e.mark);

    final buffer = StringBuffer();
    buffer.writeln('── Session Risk Analysis ──');
    buffer.writeln(
        'Net Score: ${netScore.toStringAsFixed(2)} / ${totalQuestions.toDouble().toStringAsFixed(2)}');
    buffer.writeln(
        'Accuracy:  ${accuracyPercent.toStringAsFixed(1)}%  '
        '(${correctCount}✓  ${incorrectCount}✗  ${skippedCount}–)');
    buffer.writeln('');

    if (guessTotal == 0) {
      buffer.writeln('Guesswork Attempts: None detected.');
      buffer.writeln(
          'You answered every question with confidence. Maintain this discipline.');
      return buffer.toString();
    }

    buffer.writeln(
        'Guesswork Attempts: $guessTotal  '
        '($guessCorrect paid off / $guessIncorrect backfired)');

    final markSign = guessMarkImpact >= 0 ? '+' : '';
    buffer.writeln(
        'Net mark impact from guesswork: $markSign${guessMarkImpact.toStringAsFixed(2)}');
    buffer.writeln('');

    if (guessMarkImpact < -0.5) {
      final lostMarks = guessMarkImpact.abs().toStringAsFixed(2);
      buffer.writeln(
          '⚠  Guesswork cost you $lostMarks marks. '
          'On BPSC, a wrong guess at −0.33 is almost always worse than a skip. '
          'Reduce low-confidence selections — skip if certainty < 60%.');
    } else if (guessMarkImpact > 0.5) {
      buffer.writeln(
          '✓  Your guesswork paid off (+${guessMarkImpact.toStringAsFixed(2)} marks). '
          'Educated elimination is working for you. Continue building domain knowledge '
          'to convert more guesses into confident answers.');
    } else {
      buffer.writeln(
          '≈  Guesswork had near-zero impact (${markSign}${guessMarkImpact.toStringAsFixed(2)} marks). '
          'Exercise caution — this balance can tip negative with more incorrect guesses.');
    }

    const double cutoffThreshold = 60.0;
    if (netScore < cutoffThreshold &&
        guessMarkImpact < 0 &&
        (netScore - guessMarkImpact) >= cutoffThreshold) {
      buffer.writeln('');
      buffer.writeln(
          '🚨  Without guesswork penalties you would have crossed the ~$cutoffThreshold-mark '
          'estimated threshold. Reduce uncertain attempts to protect your score.');
    }

    return buffer.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ExamTimerNotifier — owns the countdown clock and the submission gate.
// ─────────────────────────────────────────────────────────────────────────────
class ExamTimerNotifier extends ChangeNotifier {
  Timer? _ticker;

  int secondsRemaining = 0;
  bool isRunning = false;
  bool isSubmitted = false;

  final Map<String, int?> _cardSelections = {};

  void start(int questionCount) {
    _ticker?.cancel();
    secondsRemaining = questionCount * _kSecondsPerQuestion;
    isRunning = true;
    isSubmitted = false;
    _cardSelections.clear();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (secondsRemaining <= 0) {
        _finalise(autoSubmit: true);
      } else {
        secondsRemaining--;
        notifyListeners();
      }
    });

    notifyListeners();
  }

  void updateSelection(String questionId, int? selectedOption) {
    _cardSelections[questionId] = selectedOption;
  }

  void submitExam({
    required List<GeneratedQuestion> questions,
    required SessionScoreNotifier scoreNotifier,
  }) {
    _finalise(
      autoSubmit: false,
      questions: questions,
      scoreNotifier: scoreNotifier,
    );
  }

  void _finalise({
    required bool autoSubmit,
    List<GeneratedQuestion>? questions,
    SessionScoreNotifier? scoreNotifier,
  }) {
    _ticker?.cancel();
    _ticker = null;
    isRunning = false;
    isSubmitted = true;

    if (questions != null && scoreNotifier != null) {
      for (final q in questions) {
        final id = q.id.isNotEmpty ? q.id : 'q_${questions.indexOf(q)}';
        final selected = _cardSelections[id];
        scoreNotifier.recordAnswer(
          questionId: id,
          subject: q.subject,
          selectedOption: selected,
          correctIndex: q.correctOptionIndex,
          isGuesswork: false,
        );
      }
    }

    notifyListeners();
  }

  void reset() {
    _ticker?.cancel();
    _ticker = null;
    secondsRemaining = 0;
    isRunning = false;
    isSubmitted = false;
    _cardSelections.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String get formattedTime {
    final m = (secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final s = (secondsRemaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get isExpired => secondsRemaining == 0 && isSubmitted;
  bool get isUrgent => isRunning && secondsRemaining <= 30;
}

// ─────────────────────────────────────────────────────────────────────────────
// PrelimsArenaScreen
// ─────────────────────────────────────────────────────────────────────────────
class PrelimsArenaScreen extends StatefulWidget {
  const PrelimsArenaScreen({super.key});

  @override
  State<PrelimsArenaScreen> createState() => _PrelimsArenaScreenState();
}

class _PrelimsArenaScreenState extends State<PrelimsArenaScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final TextEditingController _topicController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  _ScreenState _screenState = _ScreenState.idle;
  EcosystemResponse? _ecosystem;
  String _errorMessage = '';

  final SessionScoreNotifier _scoreNotifier = SessionScoreNotifier();
  bool _isExamMode = false;
  final ExamTimerNotifier _timerNotifier = ExamTimerNotifier();

  bool _isHindi = false;
  bool _isPyqStrictMode = false;
  Key _questionListKey = UniqueKey();
  bool _showRiskProfile = false;

  static const String _kAllConceptsFilter = 'All';
  String _selectedConceptFilter = _kAllConceptsFilter;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _timerNotifier.addListener(_onTimerChanged);
  }

  void _onTimerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timerNotifier.removeListener(_onTimerChanged);
    _topicController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    _scoreNotifier.dispose();
    _timerNotifier.dispose();
    super.dispose();
  }

  void _toggleExamMode(bool value) {
    final questions = _ecosystem?.generatedQuestions ?? [];
    if (questions.isEmpty) return;

    setState(() {
      _isExamMode = value;
      _questionListKey = UniqueKey(); 
      _showRiskProfile = false;
      _selectedConceptFilter = _kAllConceptsFilter;
    });

    _scoreNotifier.resetSession(questions.length);

    if (value) {
      _timerNotifier.start(questions.length);
    } else {
      _timerNotifier.reset();
    }
  }

  void _submitExam() {
    final questions = _ecosystem?.generatedQuestions;
    if (questions == null) return;

    _timerNotifier.submitExam(
      questions: questions,
      scoreNotifier: _scoreNotifier,
    );

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _onAnalyze() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a topic first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _timerNotifier.reset();
    setState(() {
      _screenState = _ScreenState.loading;
      _ecosystem = null;
      _errorMessage = '';
      _isExamMode = false;
      _showRiskProfile = false;
      _questionListKey = UniqueKey();
      _selectedConceptFilter = _kAllConceptsFilter;
    });
    _fadeController.reset();

    try {
      final result = await _api.generateEcosystem(
        EcosystemRequest(
          topic: topic,
          limit: 12,
          pyqStrictMode: _isPyqStrictMode,
        ),
      );
      _scoreNotifier.resetSession(result.generatedQuestions.length);
      setState(() {
        _ecosystem = result;
        _screenState = _ScreenState.success;
      });
      _fadeController.forward();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = 'Server error ${e.statusCode}: ${e.message}';
        _screenState = _ScreenState.error;
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            'Could not reach the server. Is the backend running?\n\nDetails: $e';
        _screenState = _ScreenState.error;
      });
    }
  }

  Future<void> _onTopicRefresher() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final summary = await _api.getTopicRefresher(topic);
      if (mounted) {
        Navigator.of(context).pop(); // dismiss loader
        _showSummaryModal(topic, summary);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load refresher: $e')),
        );
      }
    }
  }

  void _showSummaryModal(String topic, String summary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            final theme = Theme.of(context);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      topic,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: Text(
                          summary,
                          style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Got it! Take me to the questions',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExamSubmitted =
        _isExamMode && _timerNotifier.isSubmitted;

    return _ScoreScope(
      notifier: _scoreNotifier,
      child: Scaffold(
        bottomNavigationBar: (_isExamMode && !_timerNotifier.isSubmitted &&
                _screenState == _ScreenState.success)
            ? _SubmitExamBar(onSubmit: _submitExam)
            : null,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(context)),
                  SliverToBoxAdapter(child: _buildInputCard(context)),
                  if (_screenState == _ScreenState.success)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _PerformanceBannerDelegate(
                        notifier: _scoreNotifier,
                        onShowProfile: () => setState(
                            () => _showRiskProfile = !_showRiskProfile),
                        showingProfile: _showRiskProfile,
                      ),
                    ),
                  if (_screenState == _ScreenState.success && _showRiskProfile)
                    SliverToBoxAdapter(
                      child: _RiskProfilePanel(notifier: _scoreNotifier),
                    ),
                  if (isExamSubmitted)
                    SliverToBoxAdapter(
                      child: _ExamResultBanner(
                        scoreNotifier: _scoreNotifier,
                        onExitExamMode: () => _toggleExamMode(false),
                      ),
                    ),
                  SliverToBoxAdapter(child: _buildBody(context)),
                  SliverToBoxAdapter(
                    child: SizedBox(
                        height: (_isExamMode && !_timerNotifier.isSubmitted)
                            ? 80
                            : 56),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final hasQuestions = (_ecosystem?.generatedQuestions.isNotEmpty ?? false) &&
        _screenState == _ScreenState.success;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.quiz,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prelims Arena',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'AI-powered topic ecosystem explorer',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasQuestions) ...[
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(value: false, label: Text('EN')),
                    ButtonSegment<bool>(value: true, label: Text('HI')),
                  ],
                  selected: {_isHindi},
                  onSelectionChanged: (Set<bool> newSelection) {
                    setState(() {
                      _isHindi = newSelection.first;
                    });
                  },
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  icon: const Icon(Icons.picture_as_pdf, size: 20),
                  tooltip: 'Export as PDF',
                  onPressed: () async {
                    await PrelimsPdfExporter.exportEcosystem(
                      topic: _ecosystem!.coreTopic,
                      questions: _ecosystem!.generatedQuestions,
                      isHindi: _isHindi,
                    );
                  },
                ),
                const SizedBox(width: 12),
                if (_isExamMode)
                  AnimatedBuilder(
                    animation: _timerNotifier,
                    builder: (context, _) => _TimerDisplay(
                      timerNotifier: _timerNotifier,
                    ),
                  ),
                const SizedBox(width: 12),
                _ExamModeToggle(
                  value: _isExamMode,
                  onChanged: _timerNotifier.isSubmitted
                      ? null
                      : _toggleExamMode,
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInputCard(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = _screenState == _ScreenState.loading;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seed Topic',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _topicController,
                enabled: !isLoading,
                onSubmitted: (_) => _onAnalyze(),
                decoration: InputDecoration(
                  hintText:
                      'e.g., Revolt of 1857, Fundamental Rights, Panchayati Raj…',
                  prefixIcon: const Icon(Icons.lightbulb_outline),
                  suffixIcon: _topicController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _topicController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('BPSC PYQ Strict Mode (Option E Format)'),
                subtitle: const Text('Forces 5 options with complex stems.'),
                value: _isPyqStrictMode,
                onChanged: isLoading
                    ? null
                    : (val) {
                        setState(() {
                          _isPyqStrictMode = val;
                        });
                      },
                contentPadding: EdgeInsets.zero,
                activeColor: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: FilledButton.icon(
                      onPressed: isLoading ? null : _onAnalyze,
                      icon: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        isLoading
                            ? 'Consulting…'
                            : 'Analyse Syllabus',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: _topicController.text.trim().isEmpty || isLoading
                          ? null
                          : _onTopicRefresher,
                      icon: const Icon(Icons.menu_book),
                      label: const Text('Topic Refresher', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return switch (_screenState) {
      _ScreenState.idle => _buildIdleState(context),
      _ScreenState.loading => _buildLoadingState(context),
      _ScreenState.error => _buildErrorState(context),
      _ScreenState.success => _buildSuccessState(context),
    };
  }

  Widget _buildIdleState(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.account_balance_outlined,
                size: 72, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'Enter any BPSC / UPSC topic above',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'The AI will map its conceptual ecosystem and generate\nexam-grade practice questions.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outlineVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'The professor is thinking…',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'Consulting 40 years of BPSC expertise',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outlineVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        color: theme.colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline,
                      color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 10),
                  Text(
                    'Something went wrong',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onErrorContainer),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                  onPressed: _onAnalyze,
                  child: const Text('Try Again')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessState(BuildContext context) {
    final eco = _ecosystem!;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 28),
            _buildCoreTopicHeader(context, eco.coreTopic),
            const SizedBox(height: 20),
            _buildConceptFilterBar(context, eco.connectedStaticConcepts),
            const SizedBox(height: 28),
            _buildQuestionsSection(context, eco.generatedQuestions),
          ],
        ),
      ),
    );
  }

  Widget _buildCoreTopicHeader(BuildContext context, String topic) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOPIC ECOSYSTEM',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimary.withAlpha(180),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            topic,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConceptFilterBar(
      BuildContext context, List<String> concepts) {
    if (concepts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    final allChips = [_kAllConceptsFilter, ...concepts];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Filter by Concept',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _selectedConceptFilter != _kAllConceptsFilter
                  ? Container(
                      key: const ValueKey('badge-active'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '1 active',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('badge-none')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: allChips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final label = allChips[i];
              final isAll = label == _kAllConceptsFilter;
              final isSelected = _selectedConceptFilter == label;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: FilterChip(
                  label: Text(label),
                  avatar: isAll
                      ? Icon(
                          Icons.layers_outlined,
                          size: 15,
                          color: isSelected
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        )
                      : null,
                  selected: isSelected,
                  showCheckmark: !isAll,
                  onSelected: (_) => setState(() {
                    _selectedConceptFilter =
                        isSelected && !isAll ? _kAllConceptsFilter : label;
                  }),
                  selectedColor: isAll
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.secondaryContainer,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                  labelStyle: theme.textTheme.labelLarge?.copyWith(
                    color: isSelected
                        ? (isAll
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSecondaryContainer)
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? (isAll
                            ? theme.colorScheme.primary.withAlpha(120)
                            : theme.colorScheme.secondary.withAlpha(120))
                        : theme.colorScheme.outlineVariant.withAlpha(80),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionsSection(
      BuildContext context, List<GeneratedQuestion> allQuestions) {
    final theme = Theme.of(context);
    if (allQuestions.isEmpty) return const SizedBox.shrink();

    final bool forceReveal = _isExamMode && _timerNotifier.isSubmitted;
    final bool isFiltered = _selectedConceptFilter != _kAllConceptsFilter;
    final List<GeneratedQuestion> visibleQuestions = isFiltered
        ? allQuestions
            .where((q) => q.subject == _selectedConceptFilter)
            .toList()
        : allQuestions;

    final bool filterHasNoResults =
        isFiltered && visibleQuestions.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _isExamMode ? 'Exam Questions' : 'Practice Questions',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Container(
                key: ValueKey(visibleQuestions.length),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isFiltered
                      ? theme.colorScheme.secondaryContainer
                      : (_isExamMode
                          ? theme.colorScheme.errorContainer
                          : theme.colorScheme.primaryContainer),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isFiltered
                      ? '${visibleQuestions.length} / ${allQuestions.length}'
                      : '${allQuestions.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isFiltered
                        ? theme.colorScheme.onSecondaryContainer
                        : (_isExamMode
                            ? theme.colorScheme.onErrorContainer
                            : theme.colorScheme.onPrimaryContainer),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (isFiltered) ...[
              const SizedBox(width: 8),
              Text(
                '— filtered by "$_selectedConceptFilter"',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (filterHasNoResults)
          _buildFilterEmptyState(context)
        else
          KeyedSubtree(
            key: _questionListKey,
            child: Column(
              children: [
                for (int i = 0; i < allQuestions.length; i++) ...[
                  _FilteredCardWrapper(
                    visible: visibleQuestions.contains(allQuestions[i]),
                    child: _QuestionCard(
                      key: ValueKey(
                          '${_questionListKey}_${allQuestions[i].id}'),
                      question: allQuestions[i],
                      index: i,
                      scoreNotifier: _scoreNotifier,
                      timerNotifier: _timerNotifier,
                      examMode: _isExamMode,
                      forceReveal: forceReveal,
                      isHindi: _isHindi,
                    ),
                  ),
                  if (i < allQuestions.length - 1 &&
                      visibleQuestions.contains(allQuestions[i]) &&
                      visibleQuestions.contains(allQuestions[i + 1]))
                    const SizedBox(height: 12),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFilterEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withAlpha(60)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.filter_list_off_rounded,
                size: 40, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'No questions tagged "$_selectedConceptFilter"',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() {
                _selectedConceptFilter = _kAllConceptsFilter;
              }),
              icon: const Icon(Icons.close, size: 14),
              label: const Text('Clear filter'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FilteredCardWrapper
// ─────────────────────────────────────────────────────────────────────────────
class _FilteredCardWrapper extends StatefulWidget {
  final bool visible;
  final Widget child;

  const _FilteredCardWrapper({
    required this.visible,
    required this.child,
  });

  @override
  State<_FilteredCardWrapper> createState() => _FilteredCardWrapperState();
}

class _FilteredCardWrapperState extends State<_FilteredCardWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: widget.visible ? 1.0 : 0.0,
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(_FilteredCardWrapper old) {
    super.didUpdateWidget(old);
    if (widget.visible != old.visible) {
      widget.visible ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slide,
          child: IgnorePointer(
            ignoring: !widget.visible,
            child: widget.visible
                ? widget.child
                : SizedBox(
                    height: 0,
                    child: OverflowBox(
                      maxHeight: double.infinity,
                      alignment: Alignment.topCenter,
                      child: widget.child,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ScoreScope
// ─────────────────────────────────────────────────────────────────────────────
class _ScoreScope extends InheritedNotifier<SessionScoreNotifier> {
  const _ScoreScope({
    required SessionScoreNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static SessionScoreNotifier of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ScoreScope>()!
        .notifier!;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ExamModeToggle
// ─────────────────────────────────────────────────────────────────────────────
class _ExamModeToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _ExamModeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: value
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: value
              ? theme.colorScheme.error.withAlpha(120)
              : theme.colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            value ? Icons.timer : Icons.timer_outlined,
            size: 16,
            color: value
                ? theme.colorScheme.onErrorContainer
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            'Exam Mode',
            style: theme.textTheme.labelMedium?.copyWith(
              color: value
                  ? theme.colorScheme.onErrorContainer
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TimerDisplay
// ─────────────────────────────────────────────────────────────────────────────
class _TimerDisplay extends StatefulWidget {
  final ExamTimerNotifier timerNotifier;
  const _TimerDisplay({required this.timerNotifier});

  @override
  State<_TimerDisplay> createState() => _TimerDisplayState();
}

class _TimerDisplayState extends State<_TimerDisplay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifier = widget.timerNotifier;
    final isUrgent = notifier.isUrgent;

    Widget display = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isUrgent
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isUrgent
              ? theme.colorScheme.error
              : theme.colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUrgent ? Icons.timer_off_outlined : Icons.hourglass_top_rounded,
            size: 16,
            color: isUrgent
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            notifier.formattedTime,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: isUrgent
                ? theme.colorScheme.error
                : theme.colorScheme.onSurface,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );

    if (isUrgent) {
      display = ScaleTransition(scale: _pulseAnim, child: display);
    }

    return display;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SubmitExamBar
// ─────────────────────────────────────────────────────────────────────────────
class _SubmitExamBar extends StatelessWidget {
  final VoidCallback onSubmit;
  const _SubmitExamBar({required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          onPressed: onSubmit,
          icon: const Icon(Icons.send_rounded, size: 20),
          label: const Text('Submit Exam'),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ExamResultBanner
// ─────────────────────────────────────────────────────────────────────────────
class _ExamResultBanner extends StatelessWidget {
  final SessionScoreNotifier scoreNotifier;
  final VoidCallback onExitExamMode;

  const _ExamResultBanner({
    required this.scoreNotifier,
    required this.onExitExamMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: scoreNotifier,
      builder: (context, _) {
        final score = scoreNotifier.netScore;
        final total = scoreNotifier.totalQuestions.toDouble();
        final pct = total > 0 ? (score / total * 100).clamp(0.0, 100.0) : 0.0;

        final (bg, fg, icon, verdict) = switch (pct) {
          >= 75 => (
              Colors.green.shade700,
              Colors.white,
              Icons.emoji_events_rounded,
              'Excellent Performance!'
            ),
          >= 50 => (
              theme.colorScheme.primary,
              theme.colorScheme.onPrimary,
              Icons.thumb_up_rounded,
              'Good Attempt'
            ),
          _ => (
              theme.colorScheme.error,
              theme.colorScheme.onError,
              Icons.warning_amber_rounded,
              'Needs Improvement'
            ),
        };

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(icon, color: fg, size: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        verdict,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Score: ${score.toStringAsFixed(2)} / ${total.toStringAsFixed(0)}  '
                        '(${pct.toStringAsFixed(1)}%)',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: fg.withAlpha(220),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: fg),
                  onPressed: onExitExamMode,
                  child: const Text('Exit Exam'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PerformanceBannerDelegate
// ─────────────────────────────────────────────────────────────────────────────
class _PerformanceBannerDelegate extends SliverPersistentHeaderDelegate {
  final SessionScoreNotifier notifier;
  final VoidCallback onShowProfile;
  final bool showingProfile;

  const _PerformanceBannerDelegate({
    required this.notifier,
    required this.onShowProfile,
    required this.showingProfile,
  });

  static const double _height = 80.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_PerformanceBannerDelegate oldDelegate) =>
      oldDelegate.showingProfile != showingProfile;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return AnimatedBuilder(
      animation: notifier,
      builder: (context, _) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final bannerColor = isDark
            ? theme.colorScheme.surfaceContainerHigh
            : theme.colorScheme.surfaceContainerHighest;

        return Container(
          height: _height,
          margin: const EdgeInsets.fromLTRB(24, 8, 24, 4),
          decoration: BoxDecoration(
            color: bannerColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: overlapsContent
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(30),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            children: [
              const SizedBox(width: 4),
              Expanded(
                child: _BannerMetric(
                  label: 'NET SCORE',
                  value: notifier.netScore.toStringAsFixed(2),
                  valueColor: notifier.netScore >= 0
                      ? Colors.green.shade600
                      : theme.colorScheme.error,
                  icon: Icons.scoreboard_outlined,
                ),
              ),
              _divider(theme),
              Expanded(
                child: _BannerMetric(
                  label: 'ACCURACY',
                  value: '${notifier.accuracyPercent.toStringAsFixed(1)}%',
                  valueColor: theme.colorScheme.primary,
                  icon: Icons.track_changes_outlined,
                ),
              ),
              _divider(theme),
              Expanded(
                child: _BannerMetric(
                  label: 'CORRECT (+1s)',
                  value: '+${notifier.correctCount}',
                  valueColor: Colors.green.shade600,
                  icon: Icons.check_circle_outline,
                ),
              ),
              _divider(theme),
              Expanded(
                child: _BannerMetric(
                  label: 'PENALTIES',
                  value: notifier.penaltiesAccrued > 0
                      ? '−${notifier.penaltiesAccrued.toStringAsFixed(2)}'
                      : '0.00',
                  valueColor: notifier.penaltiesAccrued > 0
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                  icon: Icons.warning_amber_outlined,
                ),
              ),
              IconButton(
                tooltip: showingProfile
                    ? 'Hide risk profile'
                    : 'Show risk profile',
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    showingProfile
                        ? Icons.analytics
                        : Icons.analytics_outlined,
                    key: ValueKey(showingProfile),
                    color: theme.colorScheme.primary,
                  ),
                ),
                onPressed: onShowProfile,
              ),
              const SizedBox(width: 4),
            ],
          ),
        );
      },
    );
  }

  Widget _divider(ThemeData theme) => Container(
        width: 1,
        height: 36,
        color: theme.colorScheme.outlineVariant.withAlpha(80),
      );
}

class _BannerMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final IconData icon;

  const _BannerMetric({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 11,
                  color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 3),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 9,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: theme.textTheme.titleMedium!.copyWith(
              color: valueColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RiskProfilePanel
// ─────────────────────────────────────────────────────────────────────────────
class _RiskProfilePanel extends StatelessWidget {
  final SessionScoreNotifier notifier;
  const _RiskProfilePanel({required this.notifier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: notifier,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
          child: Card(
            color: theme.colorScheme.tertiaryContainer.withAlpha(200),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.analytics,
                          size: 18, color: theme.colorScheme.tertiary),
                      const SizedBox(width: 8),
                      Text(
                        'Post-Session Risk Profile',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    notifier.compileRiskProfile(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                      height: 1.6,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _QuestionCard 
// ─────────────────────────────────────────────────────────────────────────────
class _QuestionCard extends StatefulWidget {
  final GeneratedQuestion question;
  final int index;
  final SessionScoreNotifier scoreNotifier;
  final ExamTimerNotifier timerNotifier;
  final bool examMode;
  final bool forceReveal;
  final bool isHindi;

  const _QuestionCard({
    super.key,
    required this.question,
    required this.index,
    required this.scoreNotifier,
    required this.timerNotifier,
    required this.examMode,
    required this.forceReveal,
    required this.isHindi,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  bool _isBookmarking = false;
  bool _isBookmarked = false;

  int? _selectedOption;
  bool _revealed = false;
  bool _isDoubtful = false;
  int _optionChanges = 0;

  @override
  void initState() {
    super.initState();
    _checkInitialBookmarkStatus();
  }

  Future<void> _checkInitialBookmarkStatus() async {
    try {
      final result = await ApiService().isBookmarked(_questionId);
      if (mounted) {
        setState(() => _isBookmarked = result);
      }
    } catch (e) {
      // Ignore errors for initial check to avoid interrupting the user
    }
  }

  bool get _isGuesswork => _isDoubtful || _optionChanges >= 1;

  String get _questionId => widget.question.id.isNotEmpty
      ? widget.question.id
      : 'q_${widget.index}';

  bool get _effectivelyRevealed => _revealed || widget.forceReveal;

  Future<void> _toggleBookmark() async {
    if (_isBookmarking) return; 
    setState(() => _isBookmarking = true);

    try {
      if (_isBookmarked) {
        await ApiService().deleteBookmark(_questionId);
        if (mounted) {
          setState(() {
            _isBookmarking = false;
            _isBookmarked = false; 
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Bookmark removed'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        await ApiService().saveBookmark(
          topic: widget.question.subject.isNotEmpty ? widget.question.subject : 'General',
          questionId: _questionId,
          question: widget.question,
        );
        if (mounted) {
          setState(() {
            _isBookmarking = false;
            _isBookmarked = true; 
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Question saved to Bookmarks'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBookmarking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _selectOption(int i) {
    if (_effectivelyRevealed) return;
    setState(() {
      if (_selectedOption != null && _selectedOption != i) {
        _optionChanges++;
      }
      _selectedOption = i;
    });

    if (widget.examMode) {
      widget.timerNotifier.updateSelection(_questionId, i);
    }
  }

  void _checkAnswer() {
    setState(() => _revealed = true);
    widget.scoreNotifier.recordAnswer(
      questionId: _questionId,
      subject: widget.question.subject,
      selectedOption: _selectedOption,
      correctIndex: widget.question.correctOptionIndex,
      isGuesswork: _isGuesswork,
    );
  }

  void _skip() {
    setState(() => _revealed = true);
    widget.scoreNotifier.recordAnswer(
      questionId: _questionId,
      subject: widget.question.subject,
      selectedOption: null,
      correctIndex: widget.question.correctOptionIndex,
      isGuesswork: false,
    );
  }

  void _reset() {
    widget.scoreNotifier.clearAnswer(_questionId);
    setState(() {
      _selectedOption = null;
      _revealed = false;
      _isDoubtful = false;
      _optionChanges = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = widget.question;
    final revealed = _effectivelyRevealed;
    final examMode = widget.examMode;
    final isDark = theme.brightness == Brightness.dark;

    final bool hasPendingSelection = _selectedOption != null && !revealed;
    final List<BoxShadow> cardShadow = hasPendingSelection
        ? [
            BoxShadow(
              color: theme.colorScheme.primary.withAlpha(40),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 40 : 18),
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: cardShadow,
        border: Border.all(
          color: hasPendingSelection
              ? theme.colorScheme.primary.withAlpha(80)
              : theme.colorScheme.outlineVariant.withAlpha(60),
          width: hasPendingSelection ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: examMode
                        ? theme.colorScheme.errorContainer.withAlpha(80)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Q${widget.index + 1}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: examMode
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _DifficultyBadge(difficulty: q.difficulty),
                if (q.pyqYear.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _PyqYearBadge(year: q.pyqYear),
                ],
                const Spacer(),
                if (q.subject.isNotEmpty)
                  Text(
                    q.subject,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isBookmarking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                          size: 20,
                          color: _isBookmarked
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                  onPressed: _isBookmarking ? null : _toggleBookmark,
                  tooltip: _isBookmarked ? 'Saved' : 'Save Question',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
                if (!examMode && !revealed) ...[
                  const SizedBox(width: 8),
                  _DoubtfulToggle(
                    isDoubtful: _isDoubtful,
                    onToggle: () =>
                        setState(() => _isDoubtful = !_isDoubtful),
                  ),
                ],
                if (revealed) ...[
                  const SizedBox(width: 8),
                  _ScoreChip(
                    selectedOption: _selectedOption,
                    correctIndex: q.correctOptionIndex,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Text(
              widget.isHindi ? q.questionHi : q.questionEn,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                height: 1.55,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(
              widget.isHindi ? q.optionsHi.length : q.optionsEn.length,
              (i) {
              final isSelected = _selectedOption == i;
              final isCorrect = i == q.correctOptionIndex;
              final optionText = widget.isHindi ? q.optionsHi[i] : q.optionsEn[i];

              final Color tileBg;
              final Color borderColor;
              final double borderWidth;
              final Color labelColor;
              IconData? trailingIcon;
              Color? trailingIconColor;

              if (revealed) {
                if (isCorrect) {
                  tileBg = isDark
                      ? const Color(0xFF1B3A2A)  
                      : Colors.green.shade50;
                  borderColor = Colors.green.shade400;
                  borderWidth = 1.5;
                  labelColor = isDark
                      ? Colors.green.shade300
                      : Colors.green.shade800;
                  trailingIcon = Icons.check_circle_rounded;
                  trailingIconColor = Colors.green.shade600;
                } else if (isSelected && !isCorrect) {
                  tileBg = isDark
                      ? const Color(0xFF3A1B1B)  
                      : Colors.red.shade50;
                  borderColor = Colors.red.shade400;
                  borderWidth = 1.5;
                  labelColor = isDark
                      ? Colors.red.shade300
                      : Colors.red.shade800;
                  trailingIcon = Icons.cancel_rounded;
                  trailingIconColor = Colors.red.shade500;
                } else {
                  tileBg = isDark
                      ? theme.colorScheme.surfaceContainerLowest
                      : theme.colorScheme.surfaceContainerLowest
                          .withAlpha(200);
                  borderColor = theme.colorScheme.outlineVariant.withAlpha(50);
                  borderWidth = 1.0;
                  labelColor = theme.colorScheme.onSurface.withAlpha(120);
                }
              } else if (isSelected) {
                tileBg = isDark
                    ? theme.colorScheme.primaryContainer.withAlpha(60)
                    : theme.colorScheme.primary.withAlpha(12);
                borderColor = theme.colorScheme.primary;
                borderWidth = 1.8;
                labelColor = theme.colorScheme.onSurface;
              } else {
                tileBg = Colors.transparent;
                borderColor = theme.colorScheme.outlineVariant.withAlpha(90);
                borderWidth = 1.0;
                labelColor = theme.colorScheme.onSurface;
              }

              final Color letterBg = isSelected
                  ? (revealed
                      ? (isCorrect ? Colors.green.shade500 : Colors.red.shade500)
                      : theme.colorScheme.primary)
                  : theme.colorScheme.surfaceContainerHighest;
              final Color letterFg =
                  isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant;

              return GestureDetector(
                onTap: revealed ? null : () => _selectOption(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: tileBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: borderColor,
                      width: borderWidth,
                    ),
                    boxShadow: isSelected && !revealed
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.primary.withAlpha(25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: letterBg,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          String.fromCharCode(65 + i),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: letterFg,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          optionText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: labelColor,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            height: 1.4,
                          ),
                        ),
                      ),
                      if (trailingIcon != null) ...[
                        const SizedBox(width: 8),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: Icon(
                            trailingIcon,
                            key: ValueKey(trailingIcon),
                            color: trailingIconColor,
                            size: 20,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 12),

            if (!examMode)
              Row(
                children: [
                  if (!revealed) ...[
                    FilledButton.tonal(
                      onPressed:
                          _selectedOption == null ? null : _checkAnswer,
                      child: const Text('Check Answer'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _skip,
                      child: const Text('Skip'),
                    ),
                  ] else
                    TextButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reset'),
                    ),
                ],
              ),

            if (examMode && !revealed && _selectedOption == null) ...[
              Row(
                children: [
                  Icon(Icons.radio_button_unchecked,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant
                          .withAlpha(120)),
                  const SizedBox(width: 4),
                  Text(
                    'Not answered — will be counted as skipped (0 marks)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant
                          .withAlpha(120),
                    ),
                  ),
                ],
              ),
            ],

            if (!examMode && revealed && _isGuesswork) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.psychology_outlined,
                      size: 14, color: theme.colorScheme.tertiary),
                  const SizedBox(width: 4),
                  Text(
                    'Counted as guesswork attempt',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
            ],

            _ExplanationPanel(
              explanation: widget.isHindi ? q.explanationHi : q.explanationEn,
              visible: revealed,
              questionText: widget.isHindi ? q.questionHi : q.questionEn,
              correctAnswer: widget.isHindi ? q.optionsHi[q.correctOptionIndex] : q.optionsEn[q.correctOptionIndex],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ExplanationPanel
// ─────────────────────────────────────────────────────────────────────────────
class _ExplanationPanel extends StatefulWidget {
  final String explanation;
  final bool visible;
  final String questionText;
  final String correctAnswer;

  const _ExplanationPanel({
    required this.explanation,
    required this.visible,
    required this.questionText,
    required this.correctAnswer,
  });

  @override
  State<_ExplanationPanel> createState() => _ExplanationPanelState();
}

class _ExplanationPanelState extends State<_ExplanationPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  bool _isChatExpanded = false;
  bool _isTutorLoading = false;
  String? _tutorResponse;
  final TextEditingController _doubtController = TextEditingController();
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    if (widget.visible) _fadeCtrl.forward();
  }

  @override
  void didUpdateWidget(_ExplanationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _fadeCtrl.forward();
    } else if (!widget.visible && oldWidget.visible) {
      _fadeCtrl.reverse();
    }
  }

  Future<void> _askTutor() async {
    final query = _doubtController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isTutorLoading = true;
      _tutorResponse = null;
    });

    try {
      final response = await _api.askTutor(
        questionText: widget.questionText,
        correctAnswer: widget.correctAnswer,
        originalExplanation: widget.explanation,
        doubtQuery: query,
      );
      if (mounted) {
        setState(() {
          _tutorResponse = response;
          _isTutorLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _tutorResponse = 'Failed to reach tutor. Is the backend running?';
          _isTutorLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _doubtController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.explanation.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final panelBg = isDark
        ? theme.colorScheme.surfaceContainerHighest.withAlpha(180)
        : Colors.grey.shade50;
    final borderColor = isDark
        ? theme.colorScheme.outlineVariant.withAlpha(60)
        : Colors.grey.shade200;

    return AnimatedSize(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: widget.visible
          ? FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    decoration: BoxDecoration(
                      color: panelBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer
                                    .withAlpha(isDark ? 80 : 160),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.school_rounded,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Explanation',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 1,
                          color: borderColor,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.explanation,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? theme.colorScheme.onSurface.withAlpha(220)
                                : const Color(0xFF2D3142),
                            height: 1.65,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        if (!_isChatExpanded)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: theme.colorScheme.primary,
                            ),
                            onPressed: () => setState(() => _isChatExpanded = true),
                            icon: const Icon(Icons.psychology_alt, size: 16),
                            label: const Text('Ask a follow-up doubt'),
                          )
                        else ...[
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _doubtController,
                                  decoration: InputDecoration(
                                    hintText: 'e.g., Why is option B incorrect?',
                                    hintStyle: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                                    ),
                                  ),
                                  style: theme.textTheme.bodySmall,
                                  maxLines: null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                onPressed: _isTutorLoading ? null : _askTutor,
                                icon: _isTutorLoading 
                                  ? const SizedBox(
                                      width: 16, height: 16, 
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                                    )
                                  : const Icon(Icons.send, size: 16),
                              ),
                            ],
                          ),
                          
                          if (_tutorResponse != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer.withAlpha(isDark ? 50 : 150),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: theme.colorScheme.primary.withAlpha(80)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.auto_awesome, size: 16, color: theme.colorScheme.primary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _tutorResponse!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DoubtfulToggle
// ─────────────────────────────────────────────────────────────────────────────
class _DoubtfulToggle extends StatelessWidget {
  final bool isDoubtful;
  final VoidCallback onToggle;

  const _DoubtfulToggle({required this.isDoubtful, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isDoubtful
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDoubtful
              ? theme.colorScheme.tertiary
              : theme.colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDoubtful ? Icons.psychology : Icons.psychology_outlined,
                size: 13,
                color: isDoubtful
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'Doubtful',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDoubtful
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight:
                      isDoubtful ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ScoreChip
// ─────────────────────────────────────────────────────────────────────────────
class _ScoreChip extends StatelessWidget {
  final int? selectedOption;
  final int correctIndex;

  const _ScoreChip({
    required this.selectedOption,
    required this.correctIndex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final String label;
    final Color bg;
    final Color fg;
    final IconData icon;

    if (selectedOption == null) {
      label = '0.00';
      bg = theme.colorScheme.surfaceContainerHighest;
      fg = theme.colorScheme.onSurfaceVariant;
      icon = Icons.remove_circle_outline;
    } else if (selectedOption == correctIndex) {
      label = '+${_kCorrectMark.toStringAsFixed(2)}';
      bg = Colors.green.withAlpha(30);
      fg = Colors.green.shade700;
      icon = Icons.add_circle_outline;
    } else {
      label = _kIncorrectPenalty.toStringAsFixed(2);
      bg = theme.colorScheme.errorContainer;
      fg = theme.colorScheme.onErrorContainer;
      icon = Icons.remove_circle_outline;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: fg, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DifficultyBadge
// ─────────────────────────────────────────────────────────────────────────────
class _DifficultyBadge extends StatelessWidget {
  final String difficulty;
  const _DifficultyBadge({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (difficulty.toLowerCase()) {
      'easy' => (Colors.green, Icons.signal_cellular_alt_1_bar),
      'hard' => (Colors.red, Icons.signal_cellular_alt),
      _ => (Colors.orange, Icons.signal_cellular_alt_2_bar),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            difficulty.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PyqYearBadge — displays PYQ year tag for questions matching past papers
// ─────────────────────────────────────────────────────────────────────────────
class _PyqYearBadge extends StatelessWidget {
  final String year;
  const _PyqYearBadge({required this.year});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.deepPurple.withAlpha(60),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_edu_rounded, size: 11, color: Colors.deepPurple.shade400),
          const SizedBox(width: 4),
          Text(
            year,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.deepPurple.shade600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}