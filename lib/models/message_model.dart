class MessageModel {
  String id;
  String text;
  String senderId;
  DateTime timestamp;
  bool seen;
  
  MessageModel({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
    this.seen = false,
  });
  
  factory MessageModel.fromDatabase(Map<String, dynamic> data, String id) {
    return MessageModel(
      id: id,
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] ?? 0),
      seen: data['seen'] ?? false,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'senderId': senderId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'seen': seen,
    };
  }
}