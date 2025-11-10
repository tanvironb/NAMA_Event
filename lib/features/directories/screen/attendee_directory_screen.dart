// lib/features/directories/presentation/attendee_directory_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/directories/screen/widgets/user_list_tile.dart';

class AttendeeDirectoryScreen extends ConsumerStatefulWidget {
  const AttendeeDirectoryScreen({super.key});

  @override
  ConsumerState<AttendeeDirectoryScreen> createState() => _AttendeeDirectoryScreenState();
}

class _AttendeeDirectoryScreenState extends ConsumerState<AttendeeDirectoryScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Filter attendees by search query (name, email, company, title)
  List<AppUser> _applySearch(List<AppUser> attendees) {
    if (_searchQuery.isEmpty) return attendees;
    final query = _searchQuery.toLowerCase();
    return attendees.where((user) {
      final name = user.name.toLowerCase();
      final email = user.email.toLowerCase();
      final company = user.company.toLowerCase();
      final title = user.title.toLowerCase();
      return name.contains(query) || 
             email.contains(query) || 
             company.contains(query) || 
             title.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final attendeesAsync = ref.watch(attendeesFutureProvider);
    
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search attendees...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        
        // Attendees list
        Expanded(
          child: attendeesAsync.when(
            data: (attendees) {
              if (attendees.isEmpty) {
                return const Center(child: Text('No attendees to display.'));
              }

              // Apply search filter
              final filteredAttendees = _applySearch(attendees);

              if (filteredAttendees.isEmpty) {
                return const Center(
                  child: Text(
                    'No attendees match your search.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }
              
              return ListView.builder(
                itemCount: filteredAttendees.length,
                itemBuilder: (context, index) => UserListTile(user: filteredAttendees[index]),
              );
            },
            loading: () => const LoadingIndicator(),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }
}