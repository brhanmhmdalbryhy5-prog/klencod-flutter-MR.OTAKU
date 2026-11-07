import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/colors.dart';
import '../core/helpers.dart';
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
      // 1. من تابعني
      final followData = await Supabase.instance.client
          .from('follows')
          .select('follower_id')
          .eq('following_id', myId);
      final followerIds = followData.map((e) => parseInt(e['follower_id'])).toList();
      _followers = widget.data.players.where((p) => followerIds.contains(parseInt(p['account_id']))).toList();

      // 2. منشوراتي
      final myPostsData = await Supabase.instance.client.from('posts').select('id').eq('account_id', myId);
      final myPostIds = myPostsData.map((e) => e['id'].toString()).toList();

      // 3. من أعجب بمنشوراتي
      if (myPostIds.isNotEmpty) {
        final likesData = await Supabase.instance.client
            .from('post_likes')
            .select('account_id')
            .inFilter('post_id', myPostIds);
        final likerIds = likesData.map((e) => parseInt(e['account_id'])).toSet().toList();
        _likers = widget.data.players.where((p) => likerIds.contains(parseInt(p['account_id']))).toList();

        // 4. من حفظ منشوراتي
        final savesData = await Supabase.instance.client
            .from('saved_posts')
            .select('account_id')
            .inFilter('post_id', myPostIds);
        final saverIds = savesData.map((e) => parseInt(e['account_id'])).toSet().toList();
        _savers = widget.data.players.where((p) => saverIds.contains(parseInt(p['account_id']))).toList();
      }

      // 5. من رد على تعليقاتي
      try {
        final myComments = await Supabase.instance.client
            .from('post_comments')
            .select('id')
            .eq('account_id', myId);
        final myCommentIds = myComments.map((e) => e['id'].toString()).toList();

        if (myCommentIds.isNotEmpty) {
          final replies = await Supabase.instance.client
              .from('post_comments')
              .select('account_id')
              .inFilter('reply_to_id', myCommentIds);
          final replierIds = replies.map((e) => parseInt(e['account_id'])).toSet().toList();
          _repliers = widget.data.players.where((p) => replierIds.contains(parseInt(p['account_id']))).toList();
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Activity inbox error: $e');
    }
    if (mounted) setState(() => _loading = false);
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
            Tab(icon: Icon(Icons.person_add, size: 20), text: 'متابعات'),
            Tab(icon: Icon(Icons.favorite, size: 20), text: 'إعجابات'),
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
                _buildList(_followers, 'بدأ بمتابعتك', Icons.person_add, Colors.green),
                _buildList(_likers, 'أعجب بمنشورك', Icons.favorite, Colors.red),
                _buildList(_savers, 'حفظ منشورك', Icons.bookmark, Colors.amber),
                _buildList(_repliers, 'رد على تعليقك', Icons.reply, Colors.blue),
              ],
            ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> users, String action, IconData icon, Color color) {
    if (users.isEmpty) {
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
        itemCount: users.length,
        itemBuilder: (context, i) {
          final user = users[i];
          final name = widget.data.displayNameForAccount(user['account_id']);
          final avatar = clean(user['avatar_url']);
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
                    builder: (_) => UserProfilePage(data: widget.data, accountId: parseInt(user['account_id']), userName: name),
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