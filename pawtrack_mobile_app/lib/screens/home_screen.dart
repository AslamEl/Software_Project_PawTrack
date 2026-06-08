import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../routes/app_routes.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'hungry':      return AppColors.orange;
    case 'injured':     return const Color(0xFFE53935);
    case 'rescued':     return const Color(0xFF43A047);
    case 'needs rescue': return const Color(0xFFE53935);
    case 'stray':       return const Color(0xFF9E9E9E);
    case 'friendly':    return const Color(0xFF2196F3);
    default:            return const Color(0xFF9E9E9E);
  }
}

Color _urgencyColor(String urgency) {
  switch (urgency) {
    case 'high':   return const Color(0xFFE53935);
    case 'medium': return AppColors.orange;
    default:       return const Color(0xFF43A047);
  }
}

Color _urgencyBg(String urgency) {
  switch (urgency) {
    case 'high':   return const Color(0xFFFFEBEB);
    case 'medium': return const Color(0xFFFFF3E8);
    default:       return const Color(0xFFEDF7ED);
  }
}

IconData _urgencyIcon(String urgency) {
  switch (urgency) {
    case 'high':   return Icons.warning_rounded;
    case 'medium': return Icons.info_rounded;
    default:       return Icons.check_circle_rounded;
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
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

int _urgencyOrder(String urgency) {
  switch (urgency) {
    case 'high':   return 0;
    case 'medium': return 1;
    default:       return 2;
  }
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

  String get _firstName {
    final name = FirebaseAuth.instance.currentUser?.displayName ?? '';
    return name.isEmpty ? '' : ', ${name.split(' ').first}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: _HomeAppBar(greeting: '$_greeting$_firstName'),
      body: RefreshIndicator(
        color: AppColors.orange,
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Stats strip
              _StatsStrip(
                totalReports: _totalReports,
                rescuedCount: _rescuedCount,
                volunteerCount: _volunteerCount,
              ),
              const SizedBox(height: 24),
              // Quick actions
              _SectionHeader(
                title: 'Quick Actions',
                showSeeAll: false,
              ),
              const SizedBox(height: 12),
              const _QuickActions(),
              const SizedBox(height: 28),
              // Nearby Dogs
              _SectionHeader(
                title: 'Nearby Dogs',
                onSeeAll: () => Navigator.pushNamed(context, AppRoutes.map),
              ),
              const SizedBox(height: 12),
              const _NearbyDogsList(),
              const SizedBox(height: 28),
              // Urgent Cases
              _SectionHeader(
                title: 'Urgent Cases',
                onSeeAll: () => Navigator.pushNamed(context, AppRoutes.map),
              ),
              const SizedBox(height: 12),
              const _UrgentCasesList(),
              const SizedBox(height: 28),
              // My Reports
              _SectionHeader(
                title: 'My Reports',
                onSeeAll: () =>
                    Navigator.pushNamed(context, AppRoutes.userProfile),
              ),
              const SizedBox(height: 12),
              const _MyReportsList(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── App Bar ─────────────────────────────────────────────────────────────────

class _HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _HomeAppBar({required this.greeting});
  final String greeting;

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return AppBar(
      backgroundColor: AppColors.card,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 68,
      title: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.userProfile),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.orange.withOpacity(0.15),
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? Text(
                      (user?.displayName?.isNotEmpty == true
                              ? user!.displayName![0]
                              : 'P')
                          .toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.orange,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(greeting, style: AppTextStyles.labelSmall),
              const SizedBox(height: 1),
              Text('PawTrack', style: AppTextStyles.headlineMedium),
            ],
          ),
        ],
      ),
      actions: [
        GestureDetector(
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.notifications),
          child: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_rounded,
                    color: AppColors.ink, size: 22),
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
        const SizedBox(width: 8),
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
              label: 'Reported',
              icon: Icons.pets_rounded,
              iconColor: AppColors.orange,
              bgColor: AppColors.orange.withOpacity(0.10),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              value: '$rescuedCount',
              label: 'Rescued',
              icon: Icons.favorite_rounded,
              iconColor: Colors.white,
              bgColor: AppColors.orange,
              highlight: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              value: '$volunteerCount',
              label: 'Members',
              icon: Icons.people_rounded,
              iconColor: const Color(0xFF2196F3),
              bgColor: const Color(0xFF2196F3).withOpacity(0.10),
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
    required this.iconColor,
    required this.bgColor,
    this.highlight = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: highlight ? AppColors.orange : AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: highlight
                ? AppColors.orange.withOpacity(0.30)
                : Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: highlight ? Colors.white.withOpacity(0.2) : bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTextStyles.headlineMedium.copyWith(
              fontSize: 22,
              color: highlight ? Colors.white : AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 11,
              color: highlight ? Colors.white70 : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Actions ────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  static const _actions = [
    _ActionItem(
      icon: Icons.add_circle_rounded,
      label: 'Report\nDog',
      color: AppColors.orange,
      route: AppRoutes.report,
    ),
    _ActionItem(
      icon: Icons.map_rounded,
      label: 'Live\nMap',
      color: Color(0xFF2196F3),
      route: AppRoutes.map,
    ),
    _ActionItem(
      icon: Icons.forum_rounded,
      label: 'Community',
      color: Color(0xFF4CAF50),
      route: AppRoutes.communityFeed,
    ),
    _ActionItem(
      icon: Icons.history_rounded,
      label: 'My\nReports',
      color: Color(0xFF9C27B0),
      route: AppRoutes.userProfile,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: _actions
            .map(
              (a) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: a == _actions.last ? 0 : 10,
                  ),
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, a.route),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: a.color.withOpacity(0.12),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: a.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child:
                                Icon(a.icon, color: a.color, size: 24),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            a.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final String route;
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
  });
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.onSeeAll,
    this.showSeeAll = true,
  });

  final String title;
  final VoidCallback? onSeeAll;
  final bool showSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppTextStyles.headlineMedium.copyWith(fontSize: 18),
          ),
          if (showSeeAll && onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.orange,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'See all →',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.orange, fontSize: 12),
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
      height: 190,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('dog_reports')
            .orderBy('timestamp', descending: true)
            .limit(10)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.orange, strokeWidth: 2),
            );
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return _EmptyState(
              icon: Icons.pets_rounded,
              text: 'No reports yet — be the first!',
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
    final urgency = (data['urgency'] as String? ?? 'low').toLowerCase();
    final photoUrl = data['photoUrl'] as String?;
    final time = _timeAgo(data['timestamp']);

    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, AppRoutes.dogDetail, arguments: doc.id),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: SizedBox(
                    height: 100,
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
                // Urgency dot
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _urgencyColor(urgency),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.titleMedium.copyWith(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _statusColor(status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          status,
                          style:
                              AppTextStyles.labelSmall.copyWith(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (time.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 10, color: AppColors.muted),
                        const SizedBox(width: 3),
                        Text(
                          time,
                          style: AppTextStyles.labelSmall.copyWith(
                              fontSize: 10, color: AppColors.muted),
                        ),
                      ],
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
        child: Icon(Icons.pets_rounded,
            size: 36, color: AppColors.orange.withOpacity(0.4)),
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
          .where('urgency', whereIn: ['high', 'medium', 'low'])
          .limit(15)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(
                  color: AppColors.orange, strokeWidth: 2),
            ),
          );
        }
        final rawDocs = snapshot.data?.docs ?? [];
        if (rawDocs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _EmptyState(
              icon: Icons.check_circle_rounded,
              text: 'No urgent cases right now. Great news!',
            ),
          );
        }

        // Sort client-side: high → medium → low, then newest first
        final docs = [...rawDocs];
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aU = _urgencyOrder(aData['urgency'] as String? ?? 'low');
          final bU = _urgencyOrder(bData['urgency'] as String? ?? 'low');
          if (aU != bU) return aU.compareTo(bU);
          final aTs = aData['timestamp'] as Timestamp?;
          final bTs = bData['timestamp'] as Timestamp?;
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: docs
                .map(
                  (doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _UrgentCaseCard(doc: doc),
                  ),
                )
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
    final name = (data['dogName'] as String?)?.isNotEmpty == true
        ? data['dogName'] as String
        : 'Unknown Dog';
    final notes = (data['notes'] as String?)?.isNotEmpty == true
        ? data['notes'] as String
        : 'No description provided.';
    final time = _timeAgo(data['timestamp']);
    final status = _firstStatus(data['status']);
    final photoUrl = data['photoUrl'] as String?;
    final urgencyColor = _urgencyColor(urgency);
    final urgencyBg = _urgencyBg(urgency);

    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, AppRoutes.dogDetail, arguments: doc.id),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: urgencyColor.withOpacity(0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: urgencyColor.withOpacity(0.10),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left urgency bar
            Container(
              width: 5,
              height: 90,
              decoration: BoxDecoration(
                color: urgencyColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(20),
                ),
              ),
            ),
            // Photo
            if (photoUrl != null && photoUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.zero,
                child: SizedBox(
                  width: 72,
                  height: 90,
                  child: Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: urgencyBg,
                      child: Icon(_urgencyIcon(urgency),
                          color: urgencyColor, size: 28),
                    ),
                  ),
                ),
              )
            else
              Container(
                width: 72,
                height: 90,
                color: urgencyBg,
                child: Icon(_urgencyIcon(urgency),
                    color: urgencyColor, size: 28),
              ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Urgency badge + time
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: urgencyColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            urgency.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: _statusColor(status),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (time.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded,
                                  size: 10, color: AppColors.muted),
                              const SizedBox(width: 3),
                              Text(
                                time,
                                style: AppTextStyles.labelSmall
                                    .copyWith(fontSize: 10),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      style: AppTextStyles.titleMedium
                          .copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notes,
                      style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            // Arrow
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppColors.muted.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── My Reports ───────────────────────────────────────────────────────────────

class _MyReportsList extends StatelessWidget {
  const _MyReportsList();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('dog_reports')
          .where('reportedBy', isEqualTo: uid)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(
                  color: AppColors.orange, strokeWidth: 2),
            ),
          );
        }

        final rawDocs = snapshot.data?.docs ?? [];
        if (rawDocs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _EmptyMyReports(),
          );
        }

        // Sort newest first client-side
        final docs = [...rawDocs];
        docs.sort((a, b) {
          final aTs =
              (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          final bTs =
              (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: docs
                .map(
                  (doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MyReportCard(doc: doc),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _MyReportCard extends StatelessWidget {
  const _MyReportCard({required this.doc});
  final QueryDocumentSnapshot doc;

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['dogName'] as String?)?.isNotEmpty == true
        ? data['dogName'] as String
        : 'Unknown Dog';
    final status = _firstStatus(data['status']);
    final urgency = (data['urgency'] as String? ?? 'low').toLowerCase();
    final photoUrl = data['photoUrl'] as String?;
    final time = _timeAgo(data['timestamp']);
    final isActive = data['isActive'] as bool? ?? true;

    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, AppRoutes.dogDetail, arguments: doc.id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Photo thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 56,
                height: 56,
                child: photoUrl != null && photoUrl.isNotEmpty
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.cream,
                          child: const Icon(Icons.pets_rounded,
                              color: AppColors.orange, size: 24),
                        ),
                      )
                    : Container(
                        color: AppColors.cream,
                        child: const Icon(Icons.pets_rounded,
                            color: AppColors.orange, size: 24),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style:
                              AppTextStyles.titleMedium.copyWith(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFFEDF7ED)
                              : AppColors.cream,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isActive ? 'Active' : 'Closed',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? const Color(0xFF43A047)
                                : AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _statusColor(status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        status,
                        style: AppTextStyles.labelSmall.copyWith(fontSize: 11),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _urgencyColor(urgency).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          urgency,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _urgencyColor(urgency),
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (time.isNotEmpty)
                        Text(
                          time,
                          style: AppTextStyles.labelSmall
                              .copyWith(fontSize: 10),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 13, color: AppColors.muted.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

class _EmptyMyReports extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.pets_rounded,
              size: 40, color: AppColors.orange.withOpacity(0.4)),
          const SizedBox(height: 10),
          Text(
            "You haven't reported any dogs yet.",
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.report),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Report a Dog',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Generic Empty State ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: AppColors.orange.withOpacity(0.35)),
          const SizedBox(height: 8),
          Text(text, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
