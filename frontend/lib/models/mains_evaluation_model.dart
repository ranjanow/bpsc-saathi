class MainsEvaluationResponse {
  final double introductionScore;
  final double factsScore;
  final double structureScore;
  final double conclusionScore;
  final double overallScore;
  final List<String> feedback;

  MainsEvaluationResponse({
    required this.introductionScore,
    required this.factsScore,
    required this.structureScore,
    required this.conclusionScore,
    required this.overallScore,
    required this.feedback,
  });

  factory MainsEvaluationResponse.fromJson(Map<String, dynamic> json) {
    return MainsEvaluationResponse(
      introductionScore: (json['introduction_score'] as num?)?.toDouble() ?? 0.0,
      factsScore: (json['fact_based_score'] as num?)?.toDouble() ?? 0.0,
      structureScore: (json['structure_score'] as num?)?.toDouble() ?? 0.0,
      conclusionScore: (json['conclusion_score'] as num?)?.toDouble() ?? 0.0,
      overallScore: (json['overall_score'] as num?)?.toDouble() ?? 0.0,
      feedback: (json['feedback'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
