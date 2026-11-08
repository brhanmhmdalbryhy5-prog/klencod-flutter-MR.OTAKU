import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/colors.dart';
import '../core/helpers.dart';
import '../data/app_data.dart';

class NovelsPage extends StatelessWidget {
  final AppData data;
  const NovelsPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الروايات')),
      body: AnimatedBuilder(
        animation: data,
        builder: (context, _) {
          if (data.novels.isEmpty) {
            return const Center(child: Text('لا توجد روايات حالياً.', style: TextStyle(color: Colors.grey)));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: data.novels.length,
            itemBuilder: (context, i) {
              final novel = data.novels[i];
              final cover = clean(novel['cover_url']);
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => NovelReaderPage(data: data, novel: novel),
                  )),
                  child: Row(
                    children: [
                      // صورة الغلاف
                      SizedBox(
                        width: 100, height: 140,
                        child: cover.isNotEmpty
                            ? CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover)
                            : Container(color: AppColors.cardBlack, child: const Icon(Icons.book, size: 50, color: AppColors.gold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(clean(novel['title']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.gold)),
                              const SizedBox(height: 6),
                              Text('تأليف: ${clean(novel['author'])}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                              const SizedBox(height: 6),
                              Text(
                                clean(novel['description']),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// =======================================================
// شاشة قراءة الرواية (مثل المانغا)
// =======================================================
class NovelReaderPage extends StatefulWidget {
  final AppData data;
  final Map<String, dynamic> novel;
  const NovelReaderPage({super.key, required this.data, required this.novel});

  @override
  State<NovelReaderPage> createState() => _NovelReaderPageState();
}

class _NovelReaderPageState extends State<NovelReaderPage> {
  List<Map<String, dynamic>> images = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final res = await widget.data.getNovelImages(widget.novel['id']);
    if (mounted) setState(() { images = res; loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(clean(widget.novel['title']), style: const TextStyle(color: Colors.white)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : images.isEmpty
              ? const Center(child: Text('لا توجد صفحات لهذه الرواية.', style: TextStyle(color: Colors.white)))
              : ListView.builder(
                  itemCount: images.length,
                  itemBuilder: (context, i) {
                    final imgUrl = clean(images[i]['image_url']);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: CachedNetworkImage(
                        imageUrl: imgUrl,
                        width: double.infinity,
                        fit: BoxFit.fitWidth,
                        placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
                        errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    );
                  },
                ),
    );
  }
}