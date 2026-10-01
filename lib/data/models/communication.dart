import 'package:latlong2/latlong.dart';

import 'enums.dart';

enum MessageKind { text, image, location, system }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.kind,
    required this.sentAt,
    this.text = '',
    this.imagePath,
    this.location,
    this.read = false,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final MessageKind kind;
  final DateTime sentAt;
  final String text;
  final String? imagePath;
  final LatLng? location;
  final bool read;

  String get preview => switch (kind) {
    MessageKind.text || MessageKind.system => text,
    MessageKind.image => '📷 Photo',
    MessageKind.location => '📍 Location',
  };
}

class Conversation {
  const Conversation({
    required this.id,
    required this.propertyId,
    required this.seekerId,
    required this.ownerId,
    required this.updatedAt,
    this.lastMessage,
    this.unreadFor = const {},
    this.blockedBy,
  });

  final String id;
  final String propertyId;
  final String seekerId;
  final String ownerId;
  final DateTime updatedAt;
  final ChatMessage? lastMessage;

  /// Unread count per participant id.
  final Map<String, int> unreadFor;
  final String? blockedBy;

  String otherParty(String me) => me == seekerId ? ownerId : seekerId;

  Conversation copyWith({DateTime? updatedAt, ChatMessage? lastMessage, Map<String, int>? unreadFor, String? blockedBy}) => Conversation(
    id: id,
    propertyId: propertyId,
    seekerId: seekerId,
    ownerId: ownerId,
    updatedAt: updatedAt ?? this.updatedAt,
    lastMessage: lastMessage ?? this.lastMessage,
    unreadFor: unreadFor ?? this.unreadFor,
    blockedBy: blockedBy ?? this.blockedBy,
  );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.category,
    required this.title,
    required this.body,
    required this.createdAt,
    this.deepLink,
    this.read = false,
  });

  final String id;
  final String userId;
  final NotificationCategory category;
  final String title;
  final String body;
  final DateTime createdAt;

  /// In-app route, e.g. `/property/p12`.
  final String? deepLink;
  final bool read;

  AppNotification markRead() =>
      AppNotification(id: id, userId: userId, category: category, title: title, body: body, createdAt: createdAt, deepLink: deepLink, read: true);
}

class TicketMessage {
  const TicketMessage({required this.fromSupport, required this.text, required this.sentAt});
  final bool fromSupport;
  final String text;
  final DateTime sentAt;
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.userId,
    required this.subject,
    required this.category,
    required this.status,
    required this.createdAt,
    required this.messages,
    this.propertyId,
  });

  final String id;
  final String userId;
  final String subject;
  final String category;
  final TicketStatus status;
  final DateTime createdAt;
  final List<TicketMessage> messages;
  final String? propertyId;

  SupportTicket copyWith({TicketStatus? status, List<TicketMessage>? messages}) => SupportTicket(
    id: id,
    userId: userId,
    subject: subject,
    category: category,
    createdAt: createdAt,
    propertyId: propertyId,
    status: status ?? this.status,
    messages: messages ?? this.messages,
  );
}

class FaqItem {
  const FaqItem(this.question, this.answer);
  final String question;
  final String answer;
}
