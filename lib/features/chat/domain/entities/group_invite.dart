import 'package:equatable/equatable.dart';

/// Public preview of a group behind a join link.
class GroupInvitePreview extends Equatable {
  const GroupInvitePreview({
    required this.code,
    required this.chatId,
    required this.name,
    this.photoUrl,
    this.description = '',
  });

  final String code;
  final String chatId;
  final String name;
  final String? photoUrl;
  final String description;

  @override
  List<Object?> get props => [code, chatId, name, photoUrl, description];
}

/// Join links look like https://bccnew-53344.web.app/join/<chatId>/<code>.
abstract final class GroupLinks {
  static const host = 'bccnew-53344.web.app';

  static String build(String chatId, String code) => 'https://$host/join/$chatId/$code';

  /// Extracts (chatId, code) from a pasted link, or null if it isn't one.
  static (String chatId, String code)? parse(String text) {
    final m = RegExp(r'join/([A-Za-z0-9]+)/([A-Za-z0-9]+)').firstMatch(text.trim());
    if (m == null) return null;
    return (m.group(1)!, m.group(2)!);
  }
}
