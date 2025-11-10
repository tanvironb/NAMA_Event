// lib/features/directories/presentation/speaker_directory_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/directories/screen/widgets/user_list_tile.dart';

class SpeakerDirectoryScreen extends ConsumerStatefulWidget {
  const SpeakerDirectoryScreen({super.key});

  @override
  ConsumerState<SpeakerDirectoryScreen> createState() => _SpeakerDirectoryScreenState();
}

class _SpeakerDirectoryScreenState extends ConsumerState<SpeakerDirectoryScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Filter speakers by search query (name, email, company, title)
  List<AppUser> _applySearch(List<AppUser> speakers) {
    if (_searchQuery.isEmpty) return speakers;
    final query = _searchQuery.toLowerCase();
    return speakers.where((user) {
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
    final speakersAsync = ref.watch(speakersFutureProvider);
    
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search speakers...',
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
        
        // Speakers list
        Expanded(
          child: speakersAsync.when(
            data: (speakers) {
              if (speakers.isEmpty) {
                return const Center(child: Text('No speakers to display.'));
              }

              // Apply search filter
              final filteredSpeakers = _applySearch(speakers);

              if (filteredSpeakers.isEmpty) {
                return const Center(
                  child: Text(
                    'No speakers match your search.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }
              
              return ListView.builder(
                itemCount: filteredSpeakers.length,
                itemBuilder: (context, index) => UserListTile(user: filteredSpeakers[index]),
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