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

class _ActivityInboxScreenState extends State<ActivityInboxScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;

  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _likers = [];
  List<Map<String, dynamic>> _savers = [];
  List<Map<String, dynamic>> _replies = [];

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
      // ✅ تأكد من تحميل اللاعبين أولاً
      if (widget.data.players.isEmpty) {
        await widget.data.loadPlayers();
      }

      // 1. المتابعات
      final followData = await Supabase.instance.client
          .from('follows')
          .select('follower_id')
          .eq('following_id', myId);
      final followerIds =
          followData.map((e) => parseInt(e['follower_id'])).toList();
      _followers = widget.data.players
          .where((p) => followerIds.contains(parseInt(p['account_id'])))
          .toList();

      // 2. منشوراتي
      final myPostsData = await Supabase.instance.client
          .from('posts')
          .select('id')
          .eq('account_id', myId);
      final myPostIds = myPostsData.map((e) => e['id']).toList();

      if (myPostIds.isNotEmpty) {
        // 3. الإعجابات
        final likesData = await Supabase.instance.client
            .from('post_likes')
            .select('account_id')
            .inFilter('post_id', myPostIds);
        final likerIds =
            likesData.map((e) => parseInt(e['account_id'])).toSet().toList();
        _likers = widget.data.players
            .where((p) => likerIds.contains(parseInt(p['account_id'])))
            .toList();

        // 4. الحفظ
        final savesData = await Supabase.instance.client
            .from('saved_posts')
            .select('account_id')
            .inFilter('post_id', myPostIds);
        final saverIds =
            savesData.map((e) => parseInt(e['account_id'])).toSet().toList();
        _savers = widget.data.players
            .where((p) => saverIds.contains(parseInt(p['account_id'])))
            .toList();
      }

      // 5. الردود
      try {
        final myComments = await Supabase.instance.client
            .from('post_comments')
            .select('id, comment_text')
            .eq('account_id', myId);

        final myCommentIds = myComments
            .map((e) => parseInt(e['id']))
            .where((id) => id > 0)
            .toList();

        if (myCommentIds.isNotEmpty) {
          final repliesData = await Supabase.instance.client
              .from('post_comments')
              .select()
              .inFilter('reply_to_id', myCommentIds)
              .order('created_at', ascending: false);
          _replies = List<Map<String, dynamic>>.from(repliesData);
        } else {
          _replies = [];
        }
      } catch (e) {
        debugPrint('Replies fetch error: $e');
        _replies = [];
      }
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
                _buildUsersList(_likers, 'أعجب بمنشورك', Icons.favorite, Colors.red),
                _buildUsersList(_followers, 'بدأ بمتابعتك', Icons.person_add, Colors.green),
                _buildUsersList(_savers, 'حفظ منشورك', Icons.bookmark, Colors.amber),
                _buildRepliesList(),
              ],
            ),
    );
  }

  Widget _buildUsersList(List<Map<String, dynamic>> users, String action, IconData icon, Color color) {
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

  Widget _buildRepliesList() {
    if (_replies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.reply, size: 80, color: Colors.grey.shade700),
            const SizedBox(height: 16),
            const Text('لا توجد ردود على تعليقك بعد', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _replies.length,
        itemBuilder: (context, i) {
          final reply = _replies[i];
          final replierName = widget.data.displayNameForAccount(reply['account_id']);
          final avatar = widget.data.avatarForAccount(reply['account_id']);
          final text = clean(reply['comment_text']);
          final replyTo = clean(reply['reply_to']);
          final createdAt = clean(reply['created_at']);

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.withOpacity(0.2),
                backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                child: avatar.isEmpty ? const Icon(Icons.person, color: Colors.blue) : null,
              ),
              title: Text(replierName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (replyTo.isNotEmpty)
                    Text('رداً على تعليقك', style: TextStyle(fontSize: 11, color: AppColors.gold, fontStyle: FontStyle.italic)),
                  Text(text, style: const TextStyle(fontSize: 13)),
                  Text(timeAgo(createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.gold),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => UserProfilePage(data: widget.data, accountId: parseInt(reply['account_id']), userName: replierName),
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