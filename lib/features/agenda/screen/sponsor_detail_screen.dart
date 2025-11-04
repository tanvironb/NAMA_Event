import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/common_widgets/session_list_tile.dart';

class SponsorDetailScreen extends ConsumerStatefulWidget {
  final String partnerId;
  final String partnerName;
  final String? partnerLogo;
  final String? partnerDescription;

  const SponsorDetailScreen({
    super.key,
    required this.partnerId,
    required this.partnerName,
    this.partnerLogo,
    this.partnerDescription,
  });

  @override
  ConsumerState<SponsorDetailScreen> createState() => _SponsorDetailScreenState();
}

class _SponsorDetailScreenState extends ConsumerState<SponsorDetailScreen> {
  bool _isProcessing = false;
  Set<String> _selectedSessionIds = {};

  @override
  Widget build(BuildContext context) {
    final partnerSessionsAsync = ref.watch(partnerSessionsProvider(widget.partnerId));
    final userProfileAsync = ref.watch(userAppProfileStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.partnerName),
        actions: [
          if (!_isProcessing && _selectedSessionIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.bookmark_add),
              onPressed: _bookmarkSelectedSessions,
              tooltip: 'Bookmark Selected Sessions',
            ),
        ],
      ),
      body: partnerSessionsAsync.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No sessions found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.partnerName} has no scheduled sessions',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return userProfileAsync.when(
            data: (appUser) {
              final bookmarkedIds = appUser?.bookmarkedSessions.toSet() ?? <String>{};
              final unbookmarkedSessions = sessions.where((s) => !bookmarkedIds.contains(s.id)).toList();

              return Column(
                children: [
                  // Partner info header
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primaryContainer,
                          Theme.of(context).colorScheme.primaryContainer.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (widget.partnerLogo != null)
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: NetworkImage(widget.partnerLogo!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.business,
                                  size: 32,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.partnerName,
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${sessions.length} session${sessions.length != 1 ? 's' : ''}',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (widget.partnerDescription != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            widget.partnerDescription!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Bulk action section
                  if (unbookmarkedSessions.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.bookmark_add_outlined,
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bulk Bookmark Sessions',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Select sessions below to bookmark multiple at once',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: _selectedSessionIds.isEmpty
                                    ? () => _selectAllSessions(unbookmarkedSessions)
                                    : _clearSelection,
                                child: Text(
                                  _selectedSessionIds.isEmpty ? 'Select All' : 'Clear',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                              if (_selectedSessionIds.isNotEmpty && !_isProcessing)
                                ElevatedButton.icon(
                                  onPressed: _bookmarkSelectedSessions,
                                  icon: const Icon(Icons.bookmark_add, size: 16),
                                  label: Text('Bookmark (${_selectedSessionIds.length})'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              if (_isProcessing)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Sessions list
                  Expanded(
                    child: AnimationLimiter(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          final isBookmarked = bookmarkedIds.contains(session.id);
                          final isSelected = _selectedSessionIds.contains(session.id);

                          return AnimationConfiguration.staggeredList(
                            position: index,
                            duration: const Duration(milliseconds: 375),
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Stack(
                                    children: [
                                      SessionListTile(session: session),
                                      
                                      // Selection overlay for unbookmarked sessions
                                      if (!isBookmarked)
                                        Positioned.fill(
                                          child: Material(
                                            color: isSelected
                                                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(12),
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(12),
                                              onTap: () => _toggleSessionSelection(session.id),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: isSelected
                                                      ? Border.all(
                                                          color: Theme.of(context).colorScheme.primary,
                                                          width: 2,
                                                        )
                                                      : null,
                                                ),
                                                child: Align(
                                                  alignment: Alignment.topRight,
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(8),
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: isSelected
                                                            ? Theme.of(context).colorScheme.primary
                                                            : Theme.of(context).colorScheme.surface.withOpacity(0.9),
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Theme.of(context).colorScheme.shadow.withOpacity(0.2),
                                                            blurRadius: 4,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      padding: const EdgeInsets.all(4),
                                                      child: Icon(
                                                        isSelected ? Icons.check : Icons.add,
                                                        size: 16,
                                                        color: isSelected
                                                            ? Theme.of(context).colorScheme.onPrimary
                                                            : Theme.of(context).colorScheme.onSurface,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      
                                      // Bookmarked indicator
                                      if (isBookmarked)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.primary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.bookmark,
                                              size: 16,
                                              color: Theme.of(context).colorScheme.onPrimary,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const LoadingIndicator(),
            error: (err, stack) => Center(
              child: Text(
                'Error loading bookmarks: $err',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          );
        },
        loading: () => const LoadingIndicator(),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading sessions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                err.toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSessionSelection(String sessionId) {
    setState(() {
      if (_selectedSessionIds.contains(sessionId)) {
        _selectedSessionIds.remove(sessionId);
      } else {
        _selectedSessionIds.add(sessionId);
      }
    });
  }

  void _selectAllSessions(List<Session> unbookmarkedSessions) {
    setState(() {
      _selectedSessionIds = unbookmarkedSessions.map((s) => s.id).toSet();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedSessionIds.clear();
    });
  }

  Future<void> _bookmarkSelectedSessions() async {
    if (_selectedSessionIds.isEmpty || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final profileRepo = ref.read(userProfileRepositoryProvider);
      final currentUserId = ref.read(firebaseAuthProvider).currentUser?.uid;
      
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      // Use existing updateUserBookmarks method for each session
      for (final sessionId in _selectedSessionIds) {
        await profileRepo.updateUserBookmarks(currentUserId, sessionId, true);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully bookmarked ${_selectedSessionIds.length} sessions!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _selectedSessionIds.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to bookmark sessions: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}