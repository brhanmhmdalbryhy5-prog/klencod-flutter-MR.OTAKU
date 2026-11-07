import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/colors.dart';
import '../core/helpers.dart';
import '../data/app_data.dart';
import 'social_screens.dart';

class PostInfoSheet extends StatefulWidget {
  final AppData data;
  final Map<String, dynamic> post;
  const PostInfoSheet({super.key, required this.data, required this.post});

  @override
  State<PostInfoSheet> createState() => _PostInfoSheetState();
}

class _PostInfoSheetState extends State<PostInfoSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _likers = [];
  List<Map<String, dynamic>> _savers = [];
  int _views = 0;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final postId = widget.post['id'];
    try {
      // 1. جلب من أعجبوا (من جدول post_likes)
      final likes = await Supabase.instance.client
          .from('post_likes')
          .select('account_id')
          .eq('post_id', postId);

      // 2. جلب من حفظوا (من جدول saved_posts)
      final saves = await Supabase.instance.client
          .from('saved_posts')
          .select('account_id')
          .eq('post_id', postId);

      // 3. المشاهدات (إذا كان العمود views_count موجوداً)
      int views = 0;
      try {
        final postData = await Supabase.instance.client
            .from('posts')
            .select('views_count')
            .eq('id', postId)
            .maybeSingle();
        views = parseInt(postData?['views_count']);
      } catch (_) {}

      // تحويل الـ IDs إلى بيانات لاعبين
      final likerIds = likes.map((e) => parseInt(e['account_id'])).toList();
      final saverIds = saves.map((e) => parseInt(e['account_id'])).toList();

      _likers = widget.data.players.where((p) => likerIds.contains(parseInt(p['account_id']))).toList();
      _savers = widget.data.players.where((p) => saverIds.contains(parseInt(p['account_id']))).toList();
      _views = views;
    } catch (e) {
      debugPrint('Post info error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = ThemeManager.instance.primaryColor;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.cardBlack,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // شريط السحب
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            width: 50, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.gold),
                const SizedBox(width: 8),
                const Text('معلومات المنشور', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.gold)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // صف الإحصائيات السريعة
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statCard(Icons.favorite, Colors.red, '${_likers.length}', 'إعجاب'),
                          _statCard(Icons.bookmark, Colors.amber, '${_savers.length}', 'حفظ'),
                          _statCard(Icons.visibility, Colors.blue, '$_views', 'مشاهدة'),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // مخطط سهمي بسيط
                      const Text('نمو التفاعل 📈', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildMiniChart(),

                      const SizedBox(height: 24),
                      const Divider(),

                      // قائمة المعجبين
                      _buildSectionHeader('الأشخاص الذين أعجبوا', Icons.favorite, Colors.red),
                      if (_likers.isEmpty)
                        const Padding(padding: EdgeInsets.all(16), child: Text('لا يوجد أحد أعجب بعد', style: TextStyle(color: Colors.grey)))
                      else
                        ..._likers.map((p) => _buildUserTile(p, 'أعجب بمنشورك', Colors.red)),

                      const SizedBox(height: 16),
                      const Divider(),

                      // قائمة من حفظوا
                      _buildSectionHeader('الأشخاص الذين حفظوا', Icons.bookmark, Colors.amber),
                      if (_savers.isEmpty)
                        const Padding(padding: EdgeInsets.all(16), child: Text('لا يوجد أحد حفظ بعد', style: TextStyle(color: Colors.grey)))
                      else
                        ..._savers.map((p) => _buildUserTile(p, 'حفظ منشورك', Colors.amber)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, Color color, String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> player, String action, Color color) {
    final name = widget.data.displayNameForAccount(player['account_id']);
    final avatar = clean(player['avatar_url']);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.gold,
          backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
          child: avatar.isEmpty ? const Icon(Icons.person, color: Colors.black) : null,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(action, style: TextStyle(fontSize: 12, color: color)),
        trailing: IconButton(
          icon: const Icon(Icons.person_outline, color: AppColors.gold),
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => UserProfilePage(data: widget.data, accountId: parseInt(player['account_id']), userName: name),
            ));
          },
        ),
      ),
    );
  }

  // مخطط سهمي بسيط يعتمد على قيم الإعجابات والحفظ
  Widget _buildMiniChart() {
    final totalLikes = _likers.length;
    final totalSaves = _savers.length;
    final maxValue = totalLikes > totalSaves ? totalLikes : totalSaves;
    return SizedBox(
      height: 100,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _chartBar('إعجاب', totalLikes, maxValue, Colors.red),
          _chartBar('حفظ', totalSaves, maxValue, Colors.amber),
          _chartBar('مشاهدة', _views, maxValue > _views ? maxValue : _views, Colors.blue),
        ],
      ),
    );
  }

  Widget _chartBar(String label, int value, int maxValue, Color color) {
    final height = maxValue > 0 ? (value / maxValue) * 80.0 : 0.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 40,
          height: height.clamp(4.0, 80.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.4)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ),
        const SizedBox(height: 4),
        Text('$value', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}