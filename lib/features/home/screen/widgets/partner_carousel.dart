import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:events_app_trueattempt/features/agenda/screen/sponsor_detail_screen.dart';

class PartnerCarousel extends ConsumerWidget {
  const PartnerCarousel({super.key});

  static const Color primaryBlue = Color(0xFF0D1496);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sponsorsAsync = ref.watch(sponsorsStreamProvider);

    return sponsorsAsync.when(
      data: (sponsors) {
        if (sponsors.isEmpty) {
          return SizedBox(
            height: 170,
            child: Center(
              child: Text(
                'No partners yet.',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.55),
                  fontSize: 13,
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Wrap(
            spacing: 26,
            runSpacing: 28,
            alignment: WrapAlignment.center,
            children: sponsors.map<Widget>((sponsor) {
              return _partnerCircle(context, sponsor);
            }).toList(),
          ),
        );
      },
      loading: () => const SizedBox(
        height: 170,
        child: Center(child: LoadingIndicator()),
      ),
      error: (err, stack) => SizedBox(
        height: 170,
        child: Center(
          child: Text(
            'Unable to load partners',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );
  }

  Widget _partnerCircle(BuildContext context, dynamic sponsor) {
    return GestureDetector(
      onTap: () => _showPartnerOptions(context, sponsor),
      child: SizedBox(
        width: 82,
        child: Column(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: const BoxDecoration(
                color: Color(0xFFEFEFEF),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: sponsor.logoUrl.isNotEmpty
                    ? Image.network(
                        sponsor.logoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _logoFallback(),
                      )
                    : _logoFallback(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoFallback() {
    return const Icon(
      Icons.business,
      color: primaryBlue,
      size: 34,
    );
  }

  void _showPartnerOptions(BuildContext context, dynamic sponsor) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ClipOval(
                  child: Container(
                    width: 46,
                    height: 46,
                    color: const Color(0xFFEFEFEF),
                    child: sponsor.logoUrl.isNotEmpty
                        ? Image.network(
                            sponsor.logoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.business, color: primaryBlue),
                          )
                        : const Icon(Icons.business, color: primaryBlue),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    sponsor.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            ListTile(
              leading: const Icon(Icons.event_note, color: primaryBlue),
              title: const Text('View Sessions'),
              subtitle: const Text('See all sessions by this partner'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SponsorDetailScreen(
                      partnerId: sponsor.id,
                      partnerName: sponsor.name,
                      partnerLogo:
                          sponsor.logoUrl.isNotEmpty ? sponsor.logoUrl : null,
                      partnerDescription: sponsor.description,
                    ),
                  ),
                );
              },
            ),

            if (sponsor.website.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.open_in_new, color: primaryBlue),
                title: const Text('Visit Website'),
                subtitle: Text('Open ${sponsor.name} website'),
                onTap: () {
                  Navigator.pop(context);
                  _openPartnerWebsite(context, sponsor);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPartnerWebsite(BuildContext context, dynamic sponsor) async {
    final website = sponsor.website as String;

    if (website.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${sponsor.name} website not available')),
      );
      return;
    }

    String url = website;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}