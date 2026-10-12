import 'package:flutter/material.dart';

import '../session_monitoring_repository.dart';

const monitorInk = Color(0xFF101239);
const monitorMuted = Color(0xFF687297);

// Keep this name because the other monitoring files already reference it.
const monitorPurple = Color(0xFF0B0B83);

class MonitorPanel extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final IconData? icon;

  const MonitorPanel({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final padding = compact ? 12.0 : 16.0;

        final heading = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: monitorPurple,
                size: 23,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: monitorInk,
                  fontSize: compact ? 14 : 16,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
          ],
        );

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.94),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFF0F1F9),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFBFC5E8).withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (compact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    heading,
                    if (trailing != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: trailing!,
                      ),
                    ],
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: heading),
                    if (trailing != null) ...[
                      const SizedBox(width: 12),
                      trailing!,
                    ],
                  ],
                ),
              SizedBox(height: compact ? 12 : 16),
              child,
            ],
          ),
        );
      },
    );
  }
}

Widget monitorPill(
  String text, {
  Color color = const Color(0xFF00AA66),
}) {
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 8,
    ),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      softWrap: true,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 13,
        height: 1.3,
      ),
    ),
  );
}

Widget monitorEmpty(String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 28,
    ),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        softWrap: true,
        style: const TextStyle(
          color: monitorMuted,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    ),
  );
}

Future<void> monitorAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Action failed: $error'),
      ),
    );
  }
}

class MonitorRecords extends StatelessWidget {
  final SessionMonitoringRepository repository;
  final String path;
  final Widget Function(List<Map<String, dynamic>>) builder;

  const MonitorRecords({
    super.key,
    required this.repository,
    required this.path,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: repository.watch(path),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return monitorEmpty(
            'Unable to load records: ${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(
                color: monitorPurple,
                strokeWidth: 3,
              ),
            ),
          );
        }

        final records = snapshot.data!.docs.map((document) {
          return <String, dynamic>{
            ...document.data(),
            '_id': document.id,
          };
        }).toList();

        return builder(records);
      },
    );
  }
}