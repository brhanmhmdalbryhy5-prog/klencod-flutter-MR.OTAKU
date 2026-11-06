// ✅ مضاف: account_id و replyToId عند حفظ التعليق
Future<bool> addComment(dynamic newsId, String userName, String text, {String? replyTo, String? replyToId, File? imageFile}) async {
  if ((text.trim().isEmpty && imageFile == null)) return false;
  try {
    final clientId = await getClientId();
    String? imageUrl;
    if (imageFile != null) imageUrl = await uploadGeneralImage(imageFile, 'comments');
    
    await supabase.from('news_comments').insert({
      'news_id': newsId,
      'client_id': clientId,
      'account_id': currentAccountId,
      'user_name': currentDisplayName,
      'comment_text': text.trim(),
      'reply_to': replyTo,
      'reply_to_id': replyToId, // 👈 حفظ معرف التعليق الأصلي
      'image_url': imageUrl,
    });
    commentCounts[newsId] = (commentCounts[newsId] ?? 0) + 1; notifyListeners(); return true;
  } catch (e) { return false; }
}