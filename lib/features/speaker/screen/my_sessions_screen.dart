import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/speaker/screen/widget/speaker_session_detail_screen.dart';
import 'package:events_app_trueattempt/features/speaker/widgets/session_card_widget.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

class MySessionsScreen extends ConsumerWidget {
  const MySessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allSessionsAsync = ref.watch(sessionsStreamProvider);
    final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: Column(
          children: [
            // Custom header without AppBar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: AppColors.namaNavyBlue,
                      size: 22,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'My Sessions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.namaNavyBlue,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: allSessionsAsync.when(
                data: (allSessions) {
                  final mySessions = allSessions
                      .where((s) => s.speakerIds.contains(userId))
                      .toList();

                  if (mySessions.isEmpty) {
                    return Center(
                      child: Text(
                        'You are not assigned to any sessions.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                    itemCount: mySessions.length,
                    itemBuilder: (context, index) {
                      final session = mySessions[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Transform.scale(
                            scale: 0.96, // Bigger card + bigger content
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.94,
                              child: SessionCardWidget(
                                key: ValueKey(session.id),
                                session: session,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          SpeakerSessionDetailScreen(
                                        session: session,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const LoadingIndicator(),
                error: (err, stack) => Center(
                  child: Text(
                    'Error: $err',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          color: Colors.red,
                        ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}