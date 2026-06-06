import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../routes/app_routes.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'hungry':
      return AppColors.orange;
    case 'injured':
      return const Color(0xFFE53935);
    case 'rescued':
      return const Color(0xFF43A047);
    default:
      return const Color(0xFF9E9E9E);
  }
}

String _firstStatus(dynamic raw) {
  if (raw is List && raw.isNotEmpty) return raw.first.toString();
  if (raw is String && raw.isNotEmpty) return raw;
  return 'Unknown';
}

String _timeAgo(dynamic raw) {
  if (raw == null) return '';
  final ts = raw is Timestamp ? raw.toDate() : DateTime.now();
  final diff = DateTime.now().difference(ts);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _totalReports = 0;
  int _rescuedCount = 0;
  int _volunteerCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection('dog_reports').count().get(),
        db.collection('dog_reports')
            .where('status', arrayContains: 'Rescued')
            .count()
            .get(),
        db.collection('users').count().get(),
      ]);
      if (!mounted) return;
      setState(() {
        _totalReports = results[0].count ?? 0;
        _rescuedCount = results[1].count ?? 0;
        _volunteerCount = results[2].count ?? 0;
      });
    } catch (_) {}
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _userName {
    final name = FirebaseAuth.instance.currentUser?.displayName;
    if (name == null || name.isEmpty) return '';
    return ', ${name.split(' ').first}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: _HomeAppBar(greeting: '$_greeting$_userName'),
      body: RefreshIndicator(
        color: AppColors.orange,
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 24, bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatsStrip(
                totalReports: _totalReports,
                rescuedCount: _rescuedCount,
                volunteerCount: _volunteerCount,
              ),
              const SizedBox(height: 28),
              _SectionHeader(
                title: 'Nearby Dogs',
                onSeeAll: () => Navigator.pushNamed(context, AppRoutes.map),
              ),
              const SizedBox(height: 12),
              const _NearbyDogsList(),
              const SizedBox(height: 28),
              _SectionHeader(
                title: 'Urgent Cases',
                onSeeAll: () => Navigator.pushNamed(context, AppRoutes.map),
              ),
              const SizedBox(height: 12),
              const _UrgentCasesList(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.report),
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Report a Dog',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ─── App Bar ─────────────────────────────────────────────────────────────────

class _HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _HomeAppBar({required this.greeting});
  final String greeting;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.card,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(greeting, style: AppTextStyles.labelSmall),
          const SizedBox(height: 1),
          Text('PawTrack', style: AppTextStyles.headlineMedium),
        ],
      ),
      actions: [
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_rounded, color: AppColors.ink, size: 22),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.card, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }
}

// ─── Stats Strip ─────────────────────────────────────────────────────────────

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({
    required this.totalReports,
    required this.rescuedCount,
    required this.volunteerCount,
  });

  final int totalReports;
  final int rescuedCount;
  final int volunteerCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              value: '$totalReports',
              label: 'Dogs\nReported',
              icon: Icons.pets_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              value: '$rescuedCount',
              label: 'Total\nRescued',
              icon: Icons.favorite_rounded,
              highlight: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              value: '$volunteerCount',
              label: 'Active\nMembers',
              icon: Icons.people_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    this.highlight = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? AppColors.orange : AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withOpacity(highlight ? 0.28 : 0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: highlight ? Colors.white : AppColors.orange),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.headlineMedium.copyWith(
              fontSize: 24,
              color: highlight ? Colors.white : AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: highlight ? Colors.white70 : AppColors.muted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSeeAll});
  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTextStyles.headlineMedium.copyWith(fontSize: 18)),
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'See all',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.orange),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Nearby Dogs ─────────────────────────────────────────────────────────────

class _NearbyDogsList extends StatelessWidget {
  const _NearbyDogsList();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 172,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('dog_reports')
            .orderBy('timestamp', descending: true)
            .limit(10)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.orange, strokeWidth: 2),
            );
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Text(
                'No reports yet — be the first!',
                style: AppTextStyles.bodyMedium,
              ),
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _NearbyDogCard(doc: docs[i]),
          );
        },
      ),
    );
  }
}

class _NearbyDogCard extends StatelessWidget {
  const _NearbyDogCard({required this.doc});
  final QueryDocumentSnapshot doc;

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['dogName'] as String?)?.isNotEmpty == true
        ? data['dogName'] as String
        : 'Unknown';
    final status = _firstStatus(data['status']);
    final photoUrl = data['photoUrl'] as String?;
    final time = _timeAgo(data['timestamp']);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.dogDetail, arguments: doc.id),
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.orange.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: 90,
                width: double.infinity,
                child: photoUrl != null && photoUrl.isNotEmpty
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _PawPlaceholder(),
                      )
                    : _PawPlaceholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.titleMedium.copyWith(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _statusColor(status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          status,
                          style: AppTextStyles.labelSmall.copyWith(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (time.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      time,
                      style: AppTextStyles.labelSmall.copyWith(
                        fontSize: 10,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PawPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cream,
      child: Center(
        child: Icon(Icons.pets_rounded, size: 38, color: AppColors.orange.withOpacity(0.4)),
      ),
    );
  }
}

// ─── Urgent Cases ─────────────────────────────────────────────────────────────

class _UrgentCasesList extends StatelessWidget {
  const _UrgentCasesList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('dog_reports')
          .where('urgency', whereIn: ['high', 'medium'])
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.orange, strokeWidth: 2),
            ),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              child: Text('No urgent cases right now.', style: AppTextStyles.bodyMedium),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: docs
                .map((doc) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _UrgentCaseCard(doc: doc),
                    ))
                .toList(),
          ),
        );
      },
    );
  }
}

class _UrgentCaseCard extends StatelessWidget {
  const _UrgentCaseCard({required this.doc});
  final QueryDocumentSnapshot doc;

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final urgency = (data['urgency'] as String? ?? 'medium').toLowerCase();
    final isHigh = urgency == 'high';
    final notes = (data['notes'] as String?)?.isNotEmpty == true
        ? data['notes'] as String
        : 'No description provided.';
    final time = _timeAgo(data['timestamp']);
    final status = _firstStatus(data['status']);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.dogDetail, arguments: doc.id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isHigh ? const Color(0xFFFFF0E4) : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isHigh ? AppColors.orangeDeep.withOpacity(0.25) : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.orange.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isHigh ? AppColors.orangeDeep : AppColors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isHigh ? Icons.warning_rounded : Icons.info_rounded,
                color: isHigh ? Colors.white : AppColors.orange,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isHigh ? AppColors.orangeDeep : AppColors.orange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          urgency.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status,
                        style: AppTextStyles.labelSmall.copyWith(fontSize: 11),
                      ),
                      const Spacer(),
                      Text(
                        time,
                        style: AppTextStyles.labelSmall.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notes,
                    style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
