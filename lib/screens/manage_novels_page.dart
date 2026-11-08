import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/colors.dart';
import '../core/helpers.dart';
import '../data/app_data.dart';

class ManageNovelsPage extends StatefulWidget {
  final AppData data;
  const ManageNovelsPage({super.key, required this.data});
  @override
  State<ManageNovelsPage> createState() => _ManageNovelsPageState();
}

class _ManageNovelsPageState extends State<ManageNovelsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الروايات')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddNovelDialog(),
        child: const Icon(Icons.add),
      ),
      body: AnimatedBuilder(
        animation: widget.data,
        builder: (context, _) {
          if (widget.data.novels.isEmpty) return const Center(child: Text('لا توجد روايات مضافة.'));
          return ListView.builder(
            itemCount: widget.data.novels.length,
            itemBuilder: (_, i) {
              final novel = widget.data.novels[i];
              final cover = clean(novel['cover_url']);
              return Card(
                child: ListTile(
                  leading: cover.isNotEmpty
                      ? CachedNetworkImage(imageUrl: cover, width: 50, height: 70, fit: BoxFit.cover)
                      : const Icon(Icons.book, size: 50),
                  title: Text(novel['title']),
                  subtitle: Text('المؤلف: ${novel['author']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      if (await widget.data.deleteNovel(novel['id'])) {
                        showSnack(context, 'تم حذف الرواية');
                      }
                    },
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ManageNovelImagesPage(data: widget.data, novel: novel),
                  )),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddNovelDialog() async {
    final title = TextEditingController();
    final author = TextEditingController(text: 'برهان');
    final desc = TextEditingController();
    File? coverFile;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('إضافة رواية جديدة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان الرواية')),
                  TextField(controller: author, decoration: const InputDecoration(labelText: 'المؤلف')),
                  TextField(controller: desc, decoration: const InputDecoration(labelText: 'الوصف')),
                  const SizedBox(height: 10),
                  if (coverFile != null) Image.file(coverFile!, height: 100),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                      if (picked != null) setState(() => coverFile = File(picked.path));
                    },
                    icon: const Icon(Icons.image),
                    label: const Text('اختيار صورة الغلاف'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              FilledButton(
                onPressed: () async {
                  if (title.text.trim().isEmpty) return;
                  await widget.data.addNovel(title.text, author.text, desc.text, coverFile);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =======================================================
// صفحة إدارة صور الرواية (الصفحات)
// =======================================================
class ManageNovelImagesPage extends StatefulWidget {
  final AppData data;
  final Map<String, dynamic> novel;
  const ManageNovelImagesPage({super.key, required this.data, required this.novel});
  @override
  State<ManageNovelImagesPage> createState() => _ManageNovelImagesPageState();
}

class _ManageNovelImagesPageState extends State<ManageNovelImagesPage> {
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

  Future<void> _addImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final file = File(picked.path);
    final pageNumber = images.length + 1;
    final ok = await widget.data.addNovelImage(widget.novel['id'], file, pageNumber);
    if (ok) {
      _loadImages();
      showSnack(context, 'تمت إضافة الصفحة $pageNumber');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('صور: ${widget.novel['title']}')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addImage,
        child: const Icon(Icons.add_photo_alternate),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : images.isEmpty
              ? const Center(child: Text('لا توجد صور لهذه الرواية.'))
              : ListView.builder(
                  itemCount: images.length,
                  itemBuilder: (_, i) {
                    final img = images[i];
                    return Card(
                      child: ListTile(
                        leading: CachedNetworkImage(
                          imageUrl: clean(img['image_url']),
                          width: 50, height: 50, fit: BoxFit.cover,
                        ),
                        title: Text('الصفحة ${img['page_number']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await widget.data.deleteNovelImage(img['id']);
                            _loadImages();
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}