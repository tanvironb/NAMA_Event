import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:events_app_trueattempt/features/agenda/screen/sponsor_detail_screen.dart';

class PartnerCarousel extends ConsumerWidget {
  const PartnerCarousel({super.key});

  static const Color primaryBlue = Color(0xFF0D1496);
  static const Color lightGrey = Color(0xFFEFEFEF);

 @override
Widget build(BuildContext context, WidgetRef ref) {
  final sponsorsAsync = ref.watch(sponsorsStreamProvider);

  return sponsorsAsync.when(
    data: (sponsors) {
      if (sponsors.isEmpty) {
        return const SizedBox(
          height: 120,
          child: Center(child: Text('No partners yet')),
        );
      }

      // 🔥 Split into rows of 3
      List<List<dynamic>> rows = [];
      for (int i = 0; i < sponsors.length; i += 3) {
        rows.add(
          sponsors.sublist(
            i,
            i + 3 > sponsors.length ? sponsors.length : i + 3,
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: rows.map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 26),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center, // 🔥 CENTER ROW
                children: row.map((sponsor) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _partnerItem(context, sponsor),
                  );
                }).toList(),
              ),
            );
          }).toList(),
        ),
      );
    },
    loading: () => const SizedBox(
      height: 120,
      child: Center(child: LoadingIndicator()),
    ),
    error: (err, stack) => SizedBox(
      height: 120,
      child: Center(
        child: Text(
          'Error loading partners',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    ),
  );
}

  Widget _partnerItem(BuildContext context, dynamic sponsor) {
    final logoUrl = _safeString(sponsor.logoUrl);
    final name = _safeString(sponsor.name);

    return GestureDetector(
      onTap: () => _showPartnerOptions(context, sponsor),
      child: SizedBox(
        width: 95, // 🔥 bigger width (3 per row)
        child: Column(
          children: [
            Container(
              width: 90,   // 🔥 bigger logo
              height: 90,  // 🔥 bigger logo
              decoration: BoxDecoration(
                color: lightGrey,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipOval(
                child: logoUrl.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(12), // 🔥 prevents crop
                        child: Image.network(
                          logoUrl,
                          fit: BoxFit.contain, // 🔥 FIX (no crop)
                          errorBuilder: (context, error, stackTrace) =>
                              _fallback(),
                        ),
                      )
                    : _fallback(),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              name.isNotEmpty ? name : 'Partner',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() {
    return const Center(
      child: Icon(Icons.business, color: primaryBlue, size: 34),
    );
  }

  void _showPartnerOptions(BuildContext context, dynamic sponsor) {
    final name = _safeString(sponsor.name);
    final logoUrl = _safeString(sponsor.logoUrl);
    final website = _safeString(sponsor.website);
    final description = _safeString(sponsor.description);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ClipOval(
                  child: Container(
                    width: 50,
                    height: 50,
                    color: lightGrey,
                    child: logoUrl.isNotEmpty
                        ? Image.network(logoUrl, fit: BoxFit.cover)
                        : const Icon(Icons.business, color: primaryBlue),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            ListTile(
              leading: const Icon(Icons.event_note, color: primaryBlue),
              title: const Text('View Sessions'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SponsorDetailScreen(
                      partnerId: sponsor.id,
                      partnerName: name,
                      partnerLogo: logoUrl.isNotEmpty ? logoUrl : null,
                      partnerDescription: description,
                    ),
                  ),
                );
              },
            ),

            if (website.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.open_in_new, color: primaryBlue),
                title: const Text('Visit Website'),
                onTap: () {
                  Navigator.pop(context);
                  _openWebsite(context, website);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWebsite(BuildContext context, String website) async {
    String url = website;
    if (!url.startsWith('http')) {
      url = 'https://$url';
    }

    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _safeString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }
}