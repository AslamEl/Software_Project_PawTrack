import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../routes/app_routes.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

Color _urgencyColor(String urgency) {
  switch (urgency) {
    case 'high':
      return const Color(0xFFE53935);
    case 'medium':
      return AppColors.orange;
    default:
      return const Color(0xFF43A047);
  }
}

Color _urgencyBg(String urgency) {
  switch (urgency) {
    case 'high':
      return const Color(0xFFFFEBEB);
    case 'medium':
      return const Color(0xFFFFF3E8);
    default:
      return const Color(0xFFEDF7ED);
  }
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'hungry':
      return AppColors.orange;
    case 'injured':
    case 'needs rescue':
      return const Color(0xFFE53935);
    case 'rescued':
      return const Color(0xFF43A047);
    case 'stray':
      return const Color(0xFF9E9E9E);
    case 'friendly':
      return const Color(0xFF2196F3);
    default:
      return const Color(0xFF9E9E9E);
  }
}

String _timeAgo(dynamic raw) {
  if (raw == null) return '';
  final ts = raw is Timestamp ? raw.toDate() : DateTime.now();
  final diff = DateTime.now().difference(ts);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class DogDetailScreen extends StatefulWidget {
  const DogDetailScreen({super.key});

  @override
  State<DogDetailScreen> createState() => _DogDetailScreenState();
}

class _DogDetailScreenState extends State<DogDetailScreen> {
  String? _address;
  bool _addressLoading = true;
  Map<String, dynamic>? _reporterData;

  Future<void> _fetchAddress(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json',
      );
      final res = await http.get(uri, headers: {
        'User-Agent': 'PawTrack/1.0 (pawtrack.app)',
      });
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final address = json['address'] as Map<String, dynamic>?;
        final parts = <String>[
          if (address?['road'] != null) address!['road'] as String,
          if (address?['suburb'] != null) address!['suburb'] as String,
          if (address?['city'] != null)
            address!['city'] as String
          else if (address?['town'] != null)
            address!['town'] as String,
        ];
        if (mounted) {
          setState(() {
            _address = parts.isNotEmpty ? parts.join(', ') : json['display_name'] as String?;
            _addressLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _addressLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _addressLoading = false);
    }
  }

  Future<void> _fetchReporter(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() => _reporterData = doc.data());
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final docId = ModalRoute.of(context)!.settings.arguments as String;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('dog_reports').doc(docId).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.cream,
            body: Center(child: CircularProgressIndicator(color: AppColors.orange)),
          );
        }
        if (!snap.hasData || !snap.data!.exists) {
          return Scaffold(
            backgroundColor: AppColors.cream,
            appBar: AppBar(
              backgroundColor: AppColors.card,
              elevation: 0,
              leading: const BackButton(color: AppColors.ink),
              title: Text('Dog Detail', style: AppTextStyles.headlineMedium),
            ),
            body: const Center(child: Text('Report not found.')),
          );
        }

        final data = snap.data!.data() as Map<String, dynamic>;
        final dogName = (data['dogName'] as String?)?.isNotEmpty == true
            ? data['dogName'] as String
            : 'Unnamed Dog';
        final urgency = (data['urgency'] as String? ?? 'low').toLowerCase();
        final statuses = data['status'] is List
            ? List<String>.from(data['status'] as List)
            : <String>[];
        final photoUrl = data['photoUrl'] as String?;
        final notes = data['notes'] as String?;
        final reportedBy = data['reportedBy'] as String?;
        final timestamp = data['timestamp'];
        final location = data['location'] as GeoPoint?;
        final isActive = data['isActive'] as bool? ?? true;

        // Kick off side-effects once we have the data
        if (_addressLoading && location != null) {
          _fetchAddress(location.latitude, location.longitude);
        }
        if (_reporterData == null && reportedBy != null) {
          _fetchReporter(reportedBy);
        }

        final canUpdate = currentUid != null &&
            (currentUid == reportedBy ||
                (_reporterData?['role'] as String?)?.toLowerCase() == 'ngo' ||
                (_reporterData?['role'] as String?)?.toLowerCase() == 'admin');

        return Scaffold(
          backgroundColor: AppColors.cream,
          body: CustomScrollView(
            slivers: [
              // ── Hero Photo AppBar ────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: AppColors.card,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.9),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: _HeroPhoto(photoUrl: photoUrl),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Name + Urgency + Active badge ──────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              dogName,
                              style: AppTextStyles.headlineMedium,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _UrgencyBadge(urgency: urgency),
                              if (!isActive) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDF7ED),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Rescued',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF43A047),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Status chips ───────────────────────────────────────
                      if (statuses.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: statuses.map((s) => _StatusChip(label: s)).toList(),
                        ),
                      const SizedBox(height: 20),

                      // ── Location ───────────────────────────────────────────
                      _InfoRow(
                        icon: Icons.location_on_rounded,
                        iconColor: AppColors.orange,
                        child: _addressLoading
                            ? const SizedBox(
                                height: 14,
                                width: 160,
                                child: LinearProgressIndicator(
                                  backgroundColor: AppColors.border,
                                  color: AppColors.orange,
                                ),
                              )
                            : Text(
                                _address ?? 'Location unavailable',
                                style: AppTextStyles.bodyMedium,
                              ),
                      ),
                      const SizedBox(height: 12),

                      // ── Reporter info ──────────────────────────────────────
                      _ReporterRow(
                        reporterData: _reporterData,
                        timestamp: timestamp,
                      ),
                      const SizedBox(height: 12),

                      // ── Help offers count ──────────────────────────────────
                      _HelpOffersCount(docId: docId),
                      const SizedBox(height: 8),

                      // ── Notes ──────────────────────────────────────────────
                      if (notes != null && notes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Notes',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(notes, style: AppTextStyles.bodyMedium),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // ── Action Buttons ─────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            AppRoutes.offerHelp,
                            arguments: docId,
                          ),
                          icon: const Icon(Icons.volunteer_activism_rounded),
                          label: const Text(
                            'Offer Help',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      if (canUpdate) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRoutes.updateStatus,
                              arguments: docId,
                            ),
                            icon: const Icon(Icons.edit_rounded),
                            label: const Text(
                              'Update Status',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.ink,
                              side: const BorderSide(color: AppColors.border, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),

                      // ── Status Timeline ────────────────────────────────────
                      _StatusTimeline(docId: docId),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _HeroPhoto extends StatelessWidget {
  const _HeroPhoto({required this.photoUrl});
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: photoUrl != null
          ? CachedNetworkImage(
              imageUrl: photoUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (_, __) => Container(color: AppColors.border),
              errorWidget: (_, __, ___) => _PhotoPlaceholder(),
            )
          : _PhotoPlaceholder(),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEEE5DC),
      child: const Center(
        child: Icon(Icons.pets_rounded, size: 64, color: AppColors.border),
      ),
    );
  }
}

class _UrgencyBadge extends StatelessWidget {
  const _UrgencyBadge({required this.urgency});
  final String urgency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _urgencyBg(urgency),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        urgency[0].toUpperCase() + urgency.substring(1),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _urgencyColor(urgency),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.iconColor, required this.child});
  final IconData icon;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }
}

class _ReporterRow extends StatelessWidget {
  const _ReporterRow({required this.reporterData, required this.timestamp});
  final Map<String, dynamic>? reporterData;
  final dynamic timestamp;

  @override
  Widget build(BuildContext context) {
    final name = (reporterData?['fullName'] as String?) ??
        (reporterData?['displayName'] as String?) ??
        'Anonymous';
    final avatarUrl = reporterData?['photoUrl'] as String?;
    final ago = _timeAgo(timestamp);

    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.border,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.orange,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTextStyles.bodyMedium,
              children: [
                TextSpan(
                  text: name,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink),
                ),
                TextSpan(text: ago.isNotEmpty ? '  ·  $ago' : ''),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HelpOffersCount extends StatelessWidget {
  const _HelpOffersCount({required this.docId});
  final String docId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('dog_reports')
          .doc(docId)
          .collection('help_offers')
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return _InfoRow(
          icon: Icons.favorite_rounded,
          iconColor: const Color(0xFFE53935),
          child: Text(
            count == 0
                ? 'No help offers yet — be the first!'
                : '$count ${count == 1 ? 'person has' : 'people have'} offered to help',
            style: AppTextStyles.bodyMedium,
          ),
        );
      },
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.docId});
  final String docId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('dog_reports')
          .doc(docId)
          .collection('status_updates')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status History',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            ...docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return _TimelineItem(data: d);
            }),
          ],
        );
      },
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final newStatus = data['newStatus'] as String? ?? '';
    final message = data['message'] as String?;
    final photoUrl = data['photoUrl'] as String?;
    final timestamp = data['timestamp'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              Container(width: 2, height: 40, color: AppColors.border),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (newStatus.isNotEmpty) _StatusChip(label: newStatus),
                      const Spacer(),
                      Text(_timeAgo(timestamp), style: AppTextStyles.labelSmall),
                    ],
                  ),
                  if (message != null && message.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(message, style: AppTextStyles.bodyMedium),
                  ],
                  if (photoUrl != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: photoUrl,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
