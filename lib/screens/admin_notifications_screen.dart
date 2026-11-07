import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/theme_manager.dart';
import '../data/app_data.dart';

class AdminNotificationsScreen extends StatefulWidget {
  final AppData data;
  const AdminNotificationsScreen({super.key, required this.data});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  bool _isSending = false;
  bool _sendToAll = true;

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى كتابة العنوان والنص')));
      return;
    }

    int? targetId;
    if (!_sendToAll) {
      targetId = int.tryParse(_targetCtrl.text.trim());
      if (targetId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رقم الحساب غير صحيح')));
        return;
      }
    }

    setState(() => _isSending = true);
    final ok = await widget.data.sendAdminNotification(
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      targetAccountId: _sendToAll ? null : targetId,
    );
    setState(() => _isSending = false);

    if (ok) {
      _titleCtrl.clear();
      _bodyCtrl.clear();
      _targetCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_sendToAll ? '✅ تم إرسال الإشعار للجميع!' : '✅ تم إرسال الإشعار للمستخدم رقم $targetId'),
          backgroundColor: Colors.green,
        ));
      }
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ فشل الإرسال'), backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = ThemeManager.instance.primaryColor;
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الإشعارات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: primary.withOpacity(0.3))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.campaign, color: primary),
                    const SizedBox(width: 8),
                    const Text('إرسال إشعار جديد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 16),
                  TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: _bodyCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'النص', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('إرسال للجميع'),
                    value: _sendToAll,
                    activeColor: primary,
                    onChanged: (v) => setState(() => _sendToAll = v),
                  ),
                  if (!_sendToAll) ...[
                    const SizedBox(height: 8),
                    TextField(controller: _targetCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رقم حساب المستخدم (ID)', border: OutlineInputBorder(), hintText: 'مثال: 1234')),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSending ? null : _send,
                      icon: _isSending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
                      label: Text(_isSending ? 'جاري الإرسال...' : 'إرسال'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}