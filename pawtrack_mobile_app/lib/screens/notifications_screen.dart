import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../routes/app_routes.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _timeAgo(dynamic raw) {
  if (raw == null) return '';
  final ts = raw is Timestamp ? raw.toDate() : DateTime.now();
  final diff = DateTime.now().difference(ts);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

String _groupLabel(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff <= 7) return 'This Week';
  return 'Earlier';
}

IconData _notifIcon(String? type) {
  switch (type) {
    case 'emergency':    return Icons.warning_rounded;
    case 'help_offer':   return Icons.volunteer_activism_rounded;
    case 'status_update': return Icons.update_rounded;
    case 'new_report':   return Icons.pets_rounded;
    default:             return Icons.notifications_rounded;
  }
}

Color _notifColor(String? type) {
  switch (type) {
    case 'emergency':    return const Color(0xFFE53935);
    case 'help_offer':   return const Color(0xFF43A047);
    case 'status_update': return AppColors.orange;
    case 'new_report':   return const Color(0xFF2196F3);
    default:             return AppColors.muted;
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<QuerySnapshot> get _stream => FirebaseFirestore.instance
      .collection('notifications')
      .doc(_uid)
      .collection('items')
      .orderBy('timestamp', descending: true)
      .snapshots();

  Future<void> _markRead(String docId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(_uid)
        .collection('items')
        .doc(docId)
        .update({'isRead': true});
  }

  Future<void> _markAllRead(List<QueryDocumentSnapshot> docs) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final d in docs) {
      if (d['isRead'] != true) {
        batch.update(d.reference, {'isRead': true});
      }
    }
    await batch.commit();
  }

  void _onTap(Map<String, dynamic> data, String docId) {
    _markRead(docId);
    final type = data['type'] as String?;
    final relatedId = data['relatedDocId'] as String?;
    if (type == 'emergency' && relatedId != null) {
      Navigator.pushNamed(context, AppRoutes.emergencyAlert,
          arguments: relatedId);
    } else if (relatedId != null) {
      Navigator.pushNamed(context, AppRoutes.dogDetail, arguments: relatedId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: Text('Notifications', style: AppTextStyles.headlineLarge.copyWith(fontSize: 20)),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.ink, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: _stream,
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              final hasUnread = docs.any((d) => d['isRead'] != true);
              if (!hasUnread) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => _markAllRead(docs),
                child: Text(
                  'Mark all read',
                  style: TextStyle(
                    color: AppColors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppColors.ink, size: 22),
            tooltip: 'Alert settings',
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.alertSettings),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.orange));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _EmptyState();
          }

          // Group by Today / This Week / Earlier
          final Map<String, List<QueryDocumentSnapshot>> groups = {
            'Today': [],
            'This Week': [],
            'Earlier': [],
          };
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final ts = data['timestamp'];
            final dt = ts is Timestamp ? ts.toDate() : DateTime.now();
            groups[_groupLabel(dt)]!.add(doc);
          }

          final sections = groups.entries
              .where((e) => e.value.isNotEmpty)
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: sections.fold<int>(
                0, (sum, e) => sum + 1 + e.value.length),
            itemBuilder: (context, i) {
              // Build a flat index from sections
              int cursor = 0;
              for (final section in sections) {
                if (i == cursor) {
                  return _SectionHeader(label: section.key);
                }
                cursor++;
                if (i < cursor + section.value.length) {
                  final doc = section.value[i - cursor];
                  return _NotifTile(
                    doc: doc,
                    onTap: () => _onTap(
                        doc.data() as Map<String, dynamic>, doc.id),
                  );
                }
                cursor += section.value.length;
              }
              return const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.muted,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─── Notification Tile ────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.doc, required this.onTap});

  final QueryDocumentSnapshot doc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final type = data['type'] as String?;
    final title = data['title'] as String? ?? 'Notification';
    final body = data['body'] as String? ?? '';
    final isRead = data['isRead'] == true;
    final ts = data['timestamp'];
    final color = _notifColor(type);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isRead ? AppColors.card : AppColors.orange.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead ? AppColors.border : AppColors.orange.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon badge
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_notifIcon(type), color: color, size: 22),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                              color: AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: const BoxDecoration(
                              color: AppColors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _timeAgo(ts),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.muted.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.orange.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 40,
              color: AppColors.orange.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No notifications yet',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You'll be notified when dogs nearby\nneed urgent help.",
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
