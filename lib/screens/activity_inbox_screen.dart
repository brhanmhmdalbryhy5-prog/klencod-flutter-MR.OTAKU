import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/colors.dart';
import '../core/helpers.dart';
import '../core/theme_manager.dart';
import '../data/app_data.dart';
import 'social_screens.dart';

class ActivityInboxScreen extends StatefulWidget {
  final AppData data;
  const ActivityInboxScreen({super.key, required this.data});

  @override
  State<ActivityInboxScreen> createState() => _ActivityInboxScreenState();
}

class _ActivityInboxScreenState extends State<ActivityInboxScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;

  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _likers = [];
  List<Map<String, dynamic>> _savers = [];
  List<Map<String, dynamic>> _repliers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    final myId = widget.data.currentAccountId;
    if (myId == null) return;
    
    try {
      // 1. جلب كل الإشعارات الموجهة لي (target_account_id = myId)
      final notifications = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('target_account_id', myId)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> followers = [];
      final List<Map<String, dynamic>> likers = [];
      final List<Map<String, dynamic>> savers = [];
      final List<Map<String, dynamic>> repliers = [];

      // 2. تصنيف الإشعارات بناءً على النص
      for (final notif in notifications) {
        final title = clean(notif['title']);
        final senderId = notif['sender_account_id'];
        
        if (senderId == null) continue;

        // البحث عن بيانات المرسل
        Map<String, dynamic>? sender;
        for (final p in widget.data.players) {
          if (parseInt(p['account_id']) == parseInt(senderId)) {
            sender = p;
            break;
          }
        }
        if (sender == null) continue;

        final item = {
          'player': sender,
          'title': title,
          'body': clean(notif['body']),
        };

        if (title.contains('متابع')) {
          followers.add(item);
        } else if (title.contains('إعجاب')) {
          likers.add(item);
        } else if (title.contains('حفظ')) {
          savers.add(item);
        } else if (title.contains('رد')) {
          repliers.add(item);
        }
      }

      if (mounted) {
        setState(() {
          _followers = followers;
          _likers = likers;
          _savers = savers;
          _repliers = repliers;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Activity inbox error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = ThemeManager.instance.primaryColor;
    return Scaffold(
      appBar: AppBar(
        title: const Text('صندوق التفاعلات'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primary,
          labelColor: primary,
          unselectedLabelColor: Colors.grey,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.favorite, size: 20), text: 'إعجابات'),
            Tab(icon: Icon(Icons.person_add, size: 20), text: 'متابعات'),
            Tab(icon: Icon(Icons.bookmark, size: 20), text: 'حفظ'),
            Tab(icon: Icon(Icons.reply, size: 20), text: 'ردود'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_likers, 'أعجب بمنشورك', Icons.favorite, Colors.red),
                _buildList(_followers, 'بدأ بمتابعتك', Icons.person_add, Colors.green),
                _buildList(_savers, 'حفظ منشورك', Icons.bookmark, Colors.amber),
                _buildList(_repliers, 'رد على تعليقك', Icons.reply, Colors.blue),
              ],
            ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, String action, IconData icon, Color color) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey.shade700),
            const SizedBox(height: 16),
            Text('لا توجد $action بعد', style: const TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          final player = item['player'] as Map<String, dynamic>;
          final name = widget.data.displayNameForAccount(player['account_id']);
          final avatar = clean(player['avatar_url']);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.2),
                backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                child: avatar.isEmpty ? Icon(Icons.person, color: color) : null,
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(action, style: TextStyle(fontSize: 12, color: color)),
              trailing: IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.gold),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => UserProfilePage(data: widget.data, accountId: parseInt(player['account_id']), userName: name),
                  ));
                },
              ),
            ),
          );
        },
      ),
    );
  }
}