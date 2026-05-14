import 'package:events_app_trueattempt/core/models/notification_model.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';

class NotificationRepository {
  final FirestoreService _firestoreService;

  NotificationRepository(this._firestoreService);

  Stream<List<AppNotification>> getNotificationsStream({
    required String userId,
    required String eventId,
  }) {
    return _firestoreService
        .getNotificationsCollectionStream(
          userId: userId,
          eventId: eventId,
        )
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppNotification.fromFirestore(doc))
          .toList();
    });
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    await _firestoreService.updateNotificationDocument(
      userId,
      notificationId,
      {'isRead': true},
    );
  }
}