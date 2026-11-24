class FeedbackMessage {
  final String id, sender, body;
  final DateTime createdAt;
  const FeedbackMessage(
      {required this.id,
      required this.sender,
      required this.body,
      required this.createdAt});
  factory FeedbackMessage.fromJson(Map<String, dynamic> json) =>
      FeedbackMessage(
          id: json['id'] as String,
          sender: json['sender'] as String,
          body: json['body'] as String,
          createdAt: DateTime.parse(json['createdAt'] as String));
}

class FeedbackThread {
  final String id,
      category,
      subject,
      status,
      platform,
      locale,
      contactEmail,
      preview;
  final DateTime createdAt, updatedAt;
  final bool unread;
  final List<FeedbackMessage> messages;
  final Map<String, dynamic>? author;
  const FeedbackThread(
      {required this.id,
      required this.category,
      required this.subject,
      required this.status,
      required this.platform,
      required this.locale,
      required this.contactEmail,
      required this.preview,
      required this.createdAt,
      required this.updatedAt,
      required this.unread,
      this.messages = const [],
      this.author});
  factory FeedbackThread.fromJson(Map<String, dynamic> json) => FeedbackThread(
      id: json['id'] as String,
      category: json['category'] as String,
      subject: json['subject'] as String,
      status: json['status'] as String,
      platform: json['platform'] as String? ?? 'unknown',
      locale: json['locale'] as String? ?? 'ru',
      contactEmail: json['contactEmail'] as String? ?? '',
      preview: json['preview'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      unread: json['unread'] == true,
      messages: (json['messages'] as List? ?? [])
          .map((m) =>
              FeedbackMessage.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList(),
      author: json['author'] == null
          ? null
          : Map<String, dynamic>.from(json['author'] as Map));
}

class FeedbackPage {
  final List<FeedbackThread> items;
  final int total, unreadCount;
  const FeedbackPage(
      {this.items = const [], this.total = 0, this.unreadCount = 0});
  factory FeedbackPage.fromJson(Map<String, dynamic> json) => FeedbackPage(
      items: (json['items'] as List)
          .map((v) =>
              FeedbackThread.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList(),
      total: json['total'] as int,
      unreadCount: json['unreadCount'] as int);
}
