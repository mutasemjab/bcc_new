import 'package:flutter/material.dart';

/// BCC Chat palette — derived from assets/app_icon.png:
/// the logo's sky-blue gradient (#84C4EB → #A9DEF6) and charcoal (#5A5A5C).
abstract final class AppColors {
  // Logo colors (exact)
  static const logoBlue = Color(0xFF84C4EB);
  static const logoBlueLight = Color(0xFFA9DEF6);
  static const charcoal = Color(0xFF5A5A5C);

  // Brand — a deeper shade of the logo blue so white text/icons stay readable.
  static const primary = Color(0xFF3A9AD9);
  static const primaryDeep = Color(0xFF2479B5);
  static const accent = logoBlueLight;
  static const violet = charcoal; // tertiary tone

  static const brandGradient = LinearGradient(
    colors: [primaryDeep, primary, logoBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const outgoingBubbleGradient = LinearGradient(
    colors: [primaryDeep, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const storyRingGradient = SweepGradient(
    colors: [logoBlueLight, primary, primaryDeep, charcoal, logoBlueLight],
  );

  // Semantic
  static const online = Color(0xFF22C55E);
  static const danger = Color(0xFFFF4D6D);
  static const warning = Color(0xFFFFB020);

  /// "Read" ticks: dark navy so they stand out on the blue outgoing bubble
  /// (white = sent/delivered); light blue on dark overlays.
  static const readTick = Color(0xFF0B2E6B);
  static const readTickOnDark = Color(0xFF6FD3FF);

  // Dark surfaces (neutral charcoal, like the logo's "C")
  static const darkBackground = Color(0xFF0E0F11);
  static const darkSurface = Color(0xFF17191C);
  static const darkSurfaceHigh = Color(0xFF212429);
  static const darkStroke = Color(0xFF2C3036);
  static const darkTextPrimary = Color(0xFFF2F4F7);
  static const darkTextSecondary = Color(0xFF9A9EA6);
  static const darkIncomingBubble = Color(0xFF23262B);

  // Light surfaces (white with a hint of logo blue)
  static const lightBackground = Color(0xFFF4F8FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceHigh = Color(0xFFE8F3FA);
  static const lightStroke = Color(0xFFDCE6EE);
  static const lightTextPrimary = Color(0xFF2B2B2D);
  static const lightTextSecondary = charcoal;
  static const lightIncomingBubble = Color(0xFFFFFFFF);

  /// Stable per-user colors for group sender names & avatar fallbacks.
  static const identityColors = [
    Color(0xFF3A9AD9),
    Color(0xFF00B8A9),
    Color(0xFF7B61FF),
    Color(0xFFFF6FB5),
    Color(0xFFFF8A3D),
    Color(0xFF22C55E),
    Color(0xFFE6B800),
    Color(0xFF00A3FF),
  ];

  static Color identity(String seed) => identityColors[seed.hashCode.abs() % identityColors.length];

  /// Backgrounds offered in the text-story editor.
  static const storyBackgrounds = [
    Color(0xFF3A9AD9),
    Color(0xFF5A5A5C),
    Color(0xFF00A99D),
    Color(0xFFFF4D6D),
    Color(0xFFFF8A3D),
    Color(0xFF17191C),
    Color(0xFF1B9E4B),
    Color(0xFFB03CFF),
  ];
}

/// Theme-dependent tokens that Material's ColorScheme does not cover.
@immutable
class ChatPalette extends ThemeExtension<ChatPalette> {
  const ChatPalette({
    required this.incomingBubble,
    required this.incomingText,
    required this.outgoingText,
    required this.textSecondary,
    required this.stroke,
    required this.surfaceHigh,
    required this.wallpaperDot,
  });

  final Color incomingBubble;
  final Color incomingText;
  final Color outgoingText;
  final Color textSecondary;
  final Color stroke;
  final Color surfaceHigh;
  final Color wallpaperDot;

  static const dark = ChatPalette(
    incomingBubble: AppColors.darkIncomingBubble,
    incomingText: AppColors.darkTextPrimary,
    outgoingText: Colors.white,
    textSecondary: AppColors.darkTextSecondary,
    stroke: AppColors.darkStroke,
    surfaceHigh: AppColors.darkSurfaceHigh,
    wallpaperDot: Color(0x14FFFFFF),
  );

  static const light = ChatPalette(
    incomingBubble: AppColors.lightIncomingBubble,
    incomingText: AppColors.lightTextPrimary,
    outgoingText: Colors.white,
    textSecondary: AppColors.lightTextSecondary,
    stroke: AppColors.lightStroke,
    surfaceHigh: AppColors.lightSurfaceHigh,
    wallpaperDot: Color(0x143A9AD9),
  );

  @override
  ChatPalette copyWith({
    Color? incomingBubble,
    Color? incomingText,
    Color? outgoingText,
    Color? textSecondary,
    Color? stroke,
    Color? surfaceHigh,
    Color? wallpaperDot,
  }) => ChatPalette(
    incomingBubble: incomingBubble ?? this.incomingBubble,
    incomingText: incomingText ?? this.incomingText,
    outgoingText: outgoingText ?? this.outgoingText,
    textSecondary: textSecondary ?? this.textSecondary,
    stroke: stroke ?? this.stroke,
    surfaceHigh: surfaceHigh ?? this.surfaceHigh,
    wallpaperDot: wallpaperDot ?? this.wallpaperDot,
  );

  @override
  ChatPalette lerp(ThemeExtension<ChatPalette>? other, double t) {
    if (other is! ChatPalette) return this;
    return ChatPalette(
      incomingBubble: Color.lerp(incomingBubble, other.incomingBubble, t)!,
      incomingText: Color.lerp(incomingText, other.incomingText, t)!,
      outgoingText: Color.lerp(outgoingText, other.outgoingText, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      stroke: Color.lerp(stroke, other.stroke, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      wallpaperDot: Color.lerp(wallpaperDot, other.wallpaperDot, t)!,
    );
  }
}

extension ThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  ChatPalette get palette => Theme.of(this).extension<ChatPalette>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
