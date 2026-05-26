class MatchModel {
  final String matchId;
  final String partnerId;
  final String partnerName;
  final String? partnerPhotoUrl;
  final int? partnerAge;
  final String? partnerCity;
  final DateTime? matchedAt;
  int unreadCount;
  String? lastMessage;
  DateTime? lastMessageAt;
  /// Only set for likes-sent items: "pending" | "accepted" | "rejected"
  final String? likeStatus;
  /// Set when the match has been unmatched/removed
  final DateTime? removedAt;
  /// True when the partner is currently online
  final bool isOnline;

  MatchModel({
    required this.matchId,
    required this.partnerId,
    required this.partnerName,
    this.partnerPhotoUrl,
    this.partnerAge,
    this.partnerCity,
    this.matchedAt,
    this.unreadCount = 0,
    this.lastMessage,
    this.lastMessageAt,
    this.likeStatus,
    this.removedAt,
    this.isOnline = false,
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    // Shape A — get_my_matches / get_conversations
    //   { match_id, partner: { id, name, main_image_url, age, city }, matched_at, last_message, unread_count }
    // Shape B — get_who_liked_me
    //   flat profile: { id, name, main_image_url, age, city, ... }
    // Shape C — get_likes_sent
    //   { profile: { id, name, main_image_url, age, city, ... }, status, sent_at }

    final partner = json['partner'] as Map?;
    final profile = json['profile'] as Map?;   // Shape C

    if (partner != null) {
      // ── Shape A ────────────────────────────────────────────
      final lastMsgRaw = json['last_message'];
      String? lastMsg;
      DateTime? lastMessageAt;
      if (lastMsgRaw is Map) {
        lastMsg = lastMsgRaw['content'] as String?;
        final atStr = lastMsgRaw['created_at'] as String?;
        if (atStr != null) lastMessageAt = DateTime.tryParse(atStr);
      } else if (lastMsgRaw is String) {
        lastMsg = lastMsgRaw;
      }
      final matchedAtStr =
          json['matched_at'] as String? ?? json['created_at'] as String?;
      final removedAtStr = json['removed_at'] as String?;
      return MatchModel(
        matchId: json['match_id'] as String? ?? '',
        partnerId: partner['id'] as String? ?? '',
        partnerName: partner['name'] as String? ?? 'Unknown',
        partnerPhotoUrl: partner['main_image_url'] as String?,
        partnerAge: partner['age'] as int?,
        partnerCity: partner['city'] as String?,
        matchedAt:
            matchedAtStr != null ? DateTime.tryParse(matchedAtStr) : null,
        unreadCount: json['unread_count'] as int? ?? 0,
        lastMessage: lastMsg,
        lastMessageAt: lastMessageAt,
        removedAt: removedAtStr != null ? DateTime.tryParse(removedAtStr) : null,
        isOnline: partner['is_online'] as bool? ?? false,
      );
    } else if (profile != null) {
      // ── Shape C — likes-sent ───────────────────────────────
      return MatchModel(
        matchId: '',
        partnerId: profile['id'] as String? ?? '',
        partnerName: profile['name'] as String? ?? 'Unknown',
        partnerPhotoUrl: profile['main_image_url'] as String?,
        partnerAge: profile['age'] as int?,
        partnerCity: profile['city'] as String?,
        likeStatus: json['status'] as String? ?? 'pending',
      );
    } else {
      // ── Shape B — liked_me / raw profile ──────────────────
      return MatchModel(
        matchId: json['match_id'] as String? ?? '',
        partnerId:
            json['id'] as String? ?? json['partner_id'] as String? ?? '',
        partnerName: json['name'] as String? ?? 'Unknown',
        partnerPhotoUrl: json['main_image_url'] as String?,
        partnerAge: json['age'] as int?,
        partnerCity: json['city'] as String?,
      );
    }
  }
}
