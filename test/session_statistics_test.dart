import 'package:flutter_test/flutter_test.dart';
import 'package:events_app_trueattempt/core/models/session_statistics.dart';

void main() {
  test('clearing chat resets participants without deleting feedback', () {
    final stats = SessionStatistics.fromRecords([], [{'rating': 4}]);
    expect(stats.messages, 0);
    expect(stats.participants, 0);
    expect(stats.feedback, 1);
    expect(stats.averageRating, 4);
  });
  test('empty collections clear all counts and rating', () {
    final stats = SessionStatistics.fromRecords([], []);
    expect(
      [stats.messages, stats.participants, stats.feedback, stats.averageRating],
      [0, 0, 0, 0],
    );
  });
  test(
    'deletion removes messages and participants with no remaining messages',
    () {
      final chat = [
        {'senderId': 'a'},
        {'senderId': 'a'},
        {'senderId': 'b', 'deletedForEveryone': true},
      ];
      final before = SessionStatistics.fromRecords(chat, [
        {'rating': 5},
        {'rating': 3},
      ]);
      expect(before.messages, 2);
      expect(before.participants, 1);
      expect(before.averageRating, 4);
      final after = SessionStatistics.fromRecords(chat.take(1), [
        {'rating': 3},
      ]);
      expect(after.messages, 1);
      expect(after.feedback, 1);
      expect(after.averageRating, 3);
    },
  );
  test('invalid ratings and missing sender IDs do not inflate aggregates', () {
    final stats = SessionStatistics.fromRecords(
      [
        {},
        {'senderId': ''},
      ],
      [
        {'rating': 5},
        {'rating': 0},
        {'rating': 'bad'},
      ],
    );
    expect(stats.participants, 0);
    expect(stats.feedback, 3);
    expect(stats.averageRating, 5);
  });
}
