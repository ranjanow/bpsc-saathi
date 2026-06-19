/// BPSC/UPSC Examination Intelligence System — Dart Models
///
/// These models STRICTLY mirror the Go backend JSON schema defined in:
///   backend/models/ecosystem.go
///
/// Any changes to the backend schema MUST be reflected here.
library;

/// Represents a single AI-generated examination question.
class GeneratedQuestion {
  final String id;
  final String questionEn;
  final String questionHi;
  final List<String> optionsEn;
  final List<String> optionsHi;
  final int correctOptionIndex;
  final String explanationEn;
  final String explanationHi;
  final String difficulty;
  final String subject;
  final String pyqYear;

  const GeneratedQuestion({
    required this.id,
    required this.questionEn,
    required this.questionHi,
    required this.optionsEn,
    required this.optionsHi,
    required this.correctOptionIndex,
    required this.explanationEn,
    required this.explanationHi,
    required this.difficulty,
    required this.subject,
    this.pyqYear = '',
  });

  factory GeneratedQuestion.fromJson(Map<String, dynamic> json) {
    return GeneratedQuestion(
      id: json['id'] as String? ?? '',
      questionEn: json['question_en'] as String? ?? '',
      questionHi: json['question_hi'] as String? ?? '',
      optionsEn: (json['options_en'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      optionsHi: (json['options_hi'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      correctOptionIndex: json['correctOptionIndex'] as int? ?? 0,
      explanationEn: json['explanation_en'] as String? ?? '',
      explanationHi: json['explanation_hi'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? 'medium',
      subject: json['subject'] as String? ?? '',
      pyqYear: json['pyqYear'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_en': questionEn,
      'question_hi': questionHi,
      'options_en': optionsEn,
      'options_hi': optionsHi,
      'correctOptionIndex': correctOptionIndex,
      'explanation_en': explanationEn,
      'explanation_hi': explanationHi,
      'difficulty': difficulty,
      'subject': subject,
      'pyqYear': pyqYear,
    };
  }
}

/// The primary AI output model.
/// Maps a core topic → connected concepts → generated questions.
class EcosystemResponse {
  final String coreTopic;
  final List<String> connectedStaticConcepts;
  final List<GeneratedQuestion> generatedQuestions;

  const EcosystemResponse({
    required this.coreTopic,
    required this.connectedStaticConcepts,
    required this.generatedQuestions,
  });

  factory EcosystemResponse.fromJson(Map<String, dynamic> json) {
    return EcosystemResponse(
      coreTopic: json['coreTopic'] as String? ?? '',
      connectedStaticConcepts:
          (json['connectedStaticConcepts'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              [],
      generatedQuestions: (json['generatedQuestions'] as List<dynamic>?)
              ?.map((e) =>
                  GeneratedQuestion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'coreTopic': coreTopic,
      'connectedStaticConcepts': connectedStaticConcepts,
      'generatedQuestions':
          generatedQuestions.map((q) => q.toJson()).toList(),
    };
  }
}

/// The request payload sent to /api/v1/generate-ecosystem.
class EcosystemRequest {
  final String topic;
  final String? difficulty;
  final int? limit;
  final bool? pyqStrictMode;

  const EcosystemRequest({
    required this.topic,
    this.difficulty,
    this.limit,
    this.pyqStrictMode,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{'topic': topic};
    if (difficulty != null) data['difficulty'] = difficulty;
    if (limit != null) data['limit'] = limit;
    if (pyqStrictMode != null) data['pyq_strict_mode'] = pyqStrictMode;
    return data;
  }
}

/// Represents a saved bookmark from the backend.
class Bookmark {
  final String id;
  final String userId;
  final String questionId;
  final String conceptTag;
  final GeneratedQuestion question;
  final DateTime createdAt;

  const Bookmark({
    required this.id,
    required this.userId,
    required this.questionId,
    required this.conceptTag,
    required this.question,
    required this.createdAt,
  });

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      questionId: json['questionId'] as String? ?? '',
      conceptTag: json['conceptTag'] as String? ?? '',
      question: GeneratedQuestion.fromJson(json['question'] as Map<String, dynamic>),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String) 
          : DateTime.now(),
    );
  }
}
