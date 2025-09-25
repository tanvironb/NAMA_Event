import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:events_app_trueattempt/features/agenda/screen/session_detail_screen.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';

// SessionListTile is a reusable widget to display a summary of a session in lists.
class SessionListTile extends StatelessWidget {
  final Session session;
  const SessionListTile({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final formattedTime = DateFormat('h:mm a').format(session.startTime);

    return Hero(
      tag: 'session_title_${session.id}', // Unique tag
      child: Material(
        type: MaterialType.transparency,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8), // Match card theme margin
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            title: Text(
              session.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text(
                '$formattedTime - ${session.location}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.secondary),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SessionDetailScreen(session: session),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}