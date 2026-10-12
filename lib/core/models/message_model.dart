import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String text;
  final String senderId;
  final String senderName;
  final String senderImageUrl;
  final String senderRole;
  final Timestamp timestamp;
  final List<String> readBy;

  // New fields for PDF/image/material sharing
  final String messageType; // text, image, file
  final String fileUrl;
  final String fileName;
  final String fileType; // image, pdf, file
  final int fileSize;

  Message({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.senderImageUrl,
    required this.senderRole,
    required this.timestamp,
    List<String>? readBy,
    this.messageType = 'text',
    this.fileUrl = '',
    this.fileName = '',
    this.fileType = '',
    this.fileSize = 0,
  }) : readBy = readBy ?? [];

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      throw StateError('Missing data for message ${doc.id}');
    }

    final timestampData = data['timestamp'];

    final Timestamp timestamp = timestampData is Timestamp
        ? timestampData
        : Timestamp.now();

    return Message(
      id: doc.id,
      text: (data['text'] ?? '').toString(),
      senderId: (data['senderId'] ?? '').toString(),
      senderName: (data['senderName'] ?? 'User').toString(),
      senderImageUrl: (data['senderImageUrl'] ?? '').toString(),
      senderRole: (data['senderRole'] ?? 'attendee').toString(),
      timestamp: timestamp,
      readBy: List<String>.from(data['readBy'] ?? []),

      // New file/material fields
      messageType: (data['messageType'] ?? 'text').toString(),
      fileUrl: (data['fileUrl'] ?? '').toString(),
      fileName: (data['fileName'] ?? '').toString(),
      fileType: (data['fileType'] ?? '').toString(),
      fileSize: data['fileSize'] is int ? data['fileSize'] as int : 0,
    );
  }

  bool get isTextMessage {
    return messageType == 'text' || fileUrl.isEmpty;
  }

  bool get isImageMessage {
    return messageType == 'image' || fileType == 'image';
  }

  bool get isFileMessage {
    return messageType == 'file' || fileUrl.isNotEmpty;
  }

  bool get isPdfFile {
    return fileType.toLowerCase() == 'pdf' ||
        fileName.toLowerCase().endsWith('.pdf');
  }

  String get readableFileSize {
    if (fileSize <= 0) {
      return '';
    }

    if (fileSize < 1024) {
      return '$fileSize B';
    }

    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }

    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool isReadBy(String userId) {
    return readBy.contains(userId);
  }
}