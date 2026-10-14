class SessionStatistics {
  final int messages;
  final int participants;
  final int feedback;
  final double averageRating;

  const SessionStatistics({
    required this.messages,
    required this.participants,
    required this.feedback,
    required this.averageRating,
  });

  factory SessionStatistics.fromRecords(
    Iterable<Map<String, dynamic>> chat,
    Iterable<Map<String, dynamic>> feedback,
  ) {
    final active = chat.where((m) => m['deletedForEveryone'] != true).toList();
    final participants =
        active
            .map((m) => (m['senderId'] ?? '').toString().trim())
            .where((id) => id.isNotEmpty)
            .toSet();
    final responses = feedback.toList();
    final ratings =
        responses
            .map((f) => f['rating'])
            .whereType<num>()
            .where((r) => r.isFinite && r >= 1 && r <= 5)
            .toList();
    return SessionStatistics(
      messages: active.length,
      participants: participants.length,
      feedback: responses.length,
      averageRating:
          ratings.isEmpty
              ? 0
              : ratings.fold<double>(0, (sum, r) => sum + r) / ratings.length,
    );
  }
}
