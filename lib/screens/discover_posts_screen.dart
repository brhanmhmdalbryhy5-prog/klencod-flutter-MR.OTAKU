import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../core/colors.dart';
import '../core/helpers.dart';
import '../core/theme_manager.dart';
import '../data/app_data.dart';
import 'social_screens.dart';
import 'post_info_sheet.dart';

class DiscoverPostsScreen extends StatefulWidget {
  final AppData data;
  const DiscoverPostsScreen({super.key, required this.data});

  @override
  State<DiscoverPostsScreen> createState() => _DiscoverPostsScreenState();
}

class _DiscoverPostsScreenState extends State<DiscoverPostsScreen> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.data.loadViewedPosts();
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: widget.data,
        builder: (context, _) {
          if (widget.data.loading && widget.data.posts.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          
          final posts = widget.data.unviewedPosts;
          
          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.done_all, color: AppColors.gold, size: 80),
                  const SizedBox(height: 16),
                  const Text('لقد شاهدت جميع المنشورات!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('عد لاحقاً لرؤية منشورات جديدة.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await widget.data.clearViewedPosts();
                      await widget.data.loadViewedPosts();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة تعيين'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
                  ),
                ],
              ),
            );
          }
          
          return PageView.builder(
            controller: _controller,
            scrollDirection: Axis.vertical,
            itemCount: posts.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              widget.data.incrementPostView(posts[index]['id']);
              widget.data.markPostViewed(posts[index]['id']);
            },
            itemBuilder: (context, index) {
              return TikTokPost(
                data: widget.data, 
                post: posts[index],
                isActive: index == _currentIndex,
              );
            },
          );
        },
      ),
    );
  }
}

// =======================================================
// بطاقة المنشور بنمط تيك توك
// =======================================================
class TikTokPost extends StatefulWidget {
  final AppData data;
  final Map<String, dynamic> post;
  final bool isActive;
  const TikTokPost({super.key, required this.data, required this.post, required this.isActive});

  @override
  State<TikTokPost> createState() => _TikTokPostState();
}

class _TikTokPostState extends State<TikTokPost> {
  bool _showHeart = false;
  String? _rankBadge;

  @override
  void initState() {
    super.initState();
    _loadRank();
  }

  Future<void> _loadRank() async {
    final badge = await widget.data.getUserRankBadge(parseInt(widget.post['account_id']));
    if (mounted) setState(() => _rankBadge = badge);
  }

  void _handleDoubleTap() async {
    final liked = widget.data.likedPosts.contains(widget.post['id'].toString());
    if (!liked) {
      await widget.data.togglePostLike(widget.post['id']);
    }
    setState(() => _showHeart = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _showHeart = false);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final post = widget.post;
    final name = data.displayNameForAccount(post['account_id']);
    final avatar = data.avatarForAccount(post['account_id']);
    final img = clean(post['image_url']);
    final vid = clean(post['video_url']);
    final content = clean(post['content']);
    final postId = post['id'];
    final liked = data.likedPosts.contains(postId.toString());
    final saved = data.isPostSaved(postId);
    final isVerified = data.isPlayerAdmin(post['account_id']);

    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // الخلفية (صورة أو فيديو)
          if (vid.isNotEmpty)
            Center(child: TikTokVideo(url: vid, isActive: widget.isActive))
          else if (img.isNotEmpty)
            Center(
              child: CachedNetworkImage(
                imageUrl: img, 
                fit: BoxFit.contain,
                width: double.infinity,
              ),
            )
          else
            Container(
              color: AppColors.cardBlack,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Text(content, style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
              ),
            ),

          // تعتيم سفلي
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
            ),
          ),

          // قلب كبير متحرك
          if (_showHeart)
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.5, end: 1.2),
              duration: const Duration(milliseconds: 300),
              builder: (context, double scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Center(
                    child: Icon(
                      Icons.favorite,
                      size: 150,
                      color: Colors.white.withOpacity(0.9),
                      shadows: [
                        Shadow(color: Colors.red.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 0)),
                      ],
                    ),
                  ),
                );
              },
            ),

          // ✅ زر الرجوع فقط (بدون كلمة استكشف)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),

          // معلومات المنشور (الأسفل يسار)
          Positioned(
            bottom: 20,
            left: 16,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => UserProfilePage(data: data, accountId: parseInt(post['account_id']), userName: name),
                      )),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.gold,
                        backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                        child: avatar.isEmpty ? const Icon(Icons.person, color: Colors.black) : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                          if (isVerified) ...[const SizedBox(width: 4), const Icon(Icons.verified, color: Colors.blue, size: 16)],
                          if (_rankBadge != null) ...[const SizedBox(width: 4), Text(_rankBadge!, style: const TextStyle(fontSize: 14))],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (content.isNotEmpty && (img.isNotEmpty || vid.isNotEmpty))
                  Text(content, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),

          // أزرار التفاعل (الأسفل يمين)
          Positioned(
            bottom: 20,
            right: 12,
            child: Column(
              children: [
                _buildActionButton(
                  icon: liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? Colors.red : Colors.white,
                  label: '${data.postLikeCounts[postId] ?? 0}',
                  onTap: () async {
                    await data.togglePostLike(postId);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  icon: Icons.comment,
                  color: Colors.white,
                  label: '${data.postCommentCounts[postId] ?? 0}',
                  onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => PostCommentsSheet(data: data, postId: postId)),
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  icon: saved ? Icons.bookmark : Icons.bookmark_border,
                  color: saved ? Colors.amber : Colors.white,
                  label: 'حفظ',
                  onTap: () async {
                    await data.toggleSavePost(postId);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  icon: Icons.bar_chart,
                  color: Colors.white,
                  label: 'معلومات',
                  onTap: () {
                    data.incrementPostView(postId);
                    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => PostInfoSheet(data: data, post: post));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle, border: Border.all(color: Colors.white30)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// =======================================================
// مشغل فيديو لتيك توك
// =======================================================
class TikTokVideo extends StatefulWidget {
  final String url;
  final bool isActive;
  const TikTokVideo({super.key, required this.url, required this.isActive});

  @override
  State<TikTokVideo> createState() => _TikTokVideoState();
}

class _TikTokVideoState extends State<TikTokVideo> {
  late VideoPlayerController _controller;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller.initialize().then((_) {
      _controller.setLooping(true);
      _controller.setVolume(1);
      if (widget.isActive) _controller.play();
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant TikTokVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.play();
      } else {
        _controller.pause();
      }
    }
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller)),
        Positioned(
          bottom: 100,
          right: 16,
          child: GestureDetector(
            onTap: () {
              setState(() => _muted = !_muted);
              _controller.setVolume(_muted ? 0 : 1);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: Icon(_muted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 24),
            ),
          ),
        ),
      ],
    );
  }
}