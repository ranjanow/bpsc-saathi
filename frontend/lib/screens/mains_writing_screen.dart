import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/mains_evaluation_model.dart';
import '../theme/app_theme.dart';

class MainsWritingScreen extends StatefulWidget {
  const MainsWritingScreen({Key? key}) : super(key: key);

  @override
  State<MainsWritingScreen> createState() => _MainsWritingScreenState();
}

class _MainsWritingScreenState extends State<MainsWritingScreen> {
  final TextEditingController _essayController = TextEditingController();
  final ApiService _apiService = ApiService();

  int _wordCount = 0;
  bool _isEvaluating = false;
  String _selectedTopic = 'Revolt of 1857';

  final List<String> _topics = [
    'Revolt of 1857',
    'Pala Art',
    'Role of Governor in Bihar',
  ];

  static final _whitespaceRegex = RegExp(r'\s+');

  @override
  void initState() {
    super.initState();
    _essayController.addListener(_updateWordCount);
  }

  @override
  void dispose() {
    _essayController.removeListener(_updateWordCount);
    _essayController.dispose();
    super.dispose();
  }

  void _updateWordCount() {
    final text = _essayController.text.trim();
    if (text.isEmpty) {
      if (_wordCount != 0) {
        setState(() => _wordCount = 0);
      }
      return;
    }
    final words = text.split(_whitespaceRegex);
    if (_wordCount != words.length) {
      setState(() => _wordCount = words.length);
    }
  }

  Future<void> _submitForEvaluation() async {
    final essayText = _essayController.text.trim();
    if (essayText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write an essay before submitting.')),
      );
      return;
    }

    setState(() => _isEvaluating = true);

    try {
      final response = await _apiService.evaluateMainsEssay(_selectedTopic, essayText);

      if (mounted) {
        setState(() => _isEvaluating = false);
        _showScorecard(response);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isEvaluating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Evaluation failed: $e')),
        );
      }
    }
  }

  void _showScorecard(MainsEvaluationResponse response) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const Center(
                    child: Text(
                      'Evaluation Scorecard',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${response.overallScore.toStringAsFixed(1)}/10',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Pillars', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildScoreRow('Introduction', response.introductionScore),
                  const SizedBox(height: 12),
                  _buildScoreRow('Fact-based Evidence', response.factsScore),
                  const SizedBox(height: 12),
                  _buildScoreRow('Structure/Flow', response.structureScore),
                  const SizedBox(height: 12),
                  _buildScoreRow('Conclusion', response.conclusionScore),
                  const SizedBox(height: 32),
                  const Text('Feedback', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ...response.feedback.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Expanded(child: Text(f, style: const TextStyle(fontSize: 16))),
                      ],
                    ),
                  )),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildScoreRow(String label, double score) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
            Text('${score.toStringAsFixed(1)}/10', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: score / 10.0,
          backgroundColor: AppColors.borderLight,
          valueColor: AlwaysStoppedAnimation<Color>(
            score >= 8.0 ? AppColors.success : score >= 5.0 ? AppColors.warning : AppColors.error,
          ),
          minHeight: 10,
          borderRadius: BorderRadius.circular(5),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mains Writing Lab'),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedTopic,
                  decoration: const InputDecoration(
                    labelText: 'Essay Topic',
                    border: OutlineInputBorder(),
                  ),
                  items: _topics.map((String topic) {
                    return DropdownMenuItem<String>(
                      value: topic,
                      child: Text(topic),
                    );
                  }).toList(),
                  onChanged: _isEvaluating
                      ? null
                      : (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedTopic = newValue;
                            });
                          }
                        },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _essayController,
                      maxLines: null,
                      expands: true,
                      enabled: !_isEvaluating,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        hintText: 'Start writing your essay here...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Words: $_wordCount',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isEvaluating ? null : _submitForEvaluation,
                      icon: const Icon(Icons.analytics),
                      label: Text(_isEvaluating ? 'Evaluating...' : 'Submit for Evaluation'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ─── Loading Overlay ──────────────────────────────────
          if (_isEvaluating)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 20),
                        Text(
                          'Evaluating your essay...\nThis may take a minute.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
