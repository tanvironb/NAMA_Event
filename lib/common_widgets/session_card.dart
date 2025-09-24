import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:events_app_trueattempt/features/agenda/session_detail_screen.dart';

class SessionCard extends StatelessWidget {
  final DocumentSnapshot sessionDoc;
  const SessionCard({super.key, required this.sessionDoc});

  @override
  Widget build(BuildContext context) {
    final session = sessionDoc.data() as Map<String, dynamic>;
    final startTime = (session['startTime'] as Timestamp).toDate();
    final formattedTime = DateFormat('h:mm a').format(startTime);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        title: Text(session['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text('$formattedTime in ${session['location']}'),
        ),
        trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.secondary),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => SessionDetailScreen(sessionDoc: sessionDoc),
          ));
        },
      ),
    );
  }
}