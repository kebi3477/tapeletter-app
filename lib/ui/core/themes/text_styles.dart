import 'package:flutter/painting.dart';

import 'colors.dart';

/// 글꼴은 SUIT 하나. 원본의 `font: <굵기> <크기>px/<줄높이> 'SUIT'` 축약형을 그대로 옮긴다.
abstract final class AppText {
  static const family = 'SUIT';

  static const tabular = [FontFeature.tabularFigures()];

  /// `font:<weight> <size>px/<height> 'SUIT'; letter-spacing:<em>em`
  static TextStyle suit(
    int weight,
    double size, {
    double? height,
    Color color = AppColors.ink,
    double letterSpacingEm = 0,
    bool tabularNums = false,
  }) {
    return TextStyle(
      fontFamily: family,
      fontWeight: _weight(weight),
      fontSize: size,
      height: height,
      color: color,
      letterSpacing: letterSpacingEm == 0 ? null : size * letterSpacingEm,
      fontFeatures: tabularNums ? tabular : null,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  static FontWeight _weight(int w) => switch (w) {
    300 => FontWeight.w300,
    400 => FontWeight.w400,
    500 => FontWeight.w500,
    600 => FontWeight.w600,
    700 => FontWeight.w700,
    800 => FontWeight.w800,
    _ => FontWeight.w400,
  };

  // tokens.json › type
  /// 800 24px SUIT, -0.02em
  static final screenTitle = suit(800, 24, letterSpacingEm: -.02);

  /// 800 26px/1.25 SUIT, -0.02em
  static final bigTitle = suit(800, 26, height: 1.25, letterSpacingEm: -.02);

  /// 800 24px/1.3 SUIT, -0.02em
  static final result = suit(800, 24, height: 1.3, letterSpacingEm: -.02);

  /// 800 20px SUIT
  /// 결제·환불 안내 보조 글자 (`500 12px/1.6`, `#9A9A97`) — 전자상거래법 안내
  static final notice = suit(500, 12, height: 1.6, color: AppColors.textMuted);

  static final sheetTitle = suit(800, 20);

  /// 800 17px SUIT, -0.01em
  static final section = suit(800, 17, letterSpacingEm: -.01);

  /// 700 16px SUIT
  static final button = suit(700, 16);

  /// 700 15.5px SUIT
  static final rowTitle = suit(700, 15.5);

  /// 600 14px SUIT
  static final body = suit(600, 14);

  /// 500 12.5px SUIT #9A9A97
  static final caption = suit(500, 12.5, color: AppColors.textMuted);

  /// 700 11px SUIT
  static final tab = suit(700, 11);
}

/// 큰 글씨 (v10.4) — 디자인 확인 배율 1.0 · 1.3 · 1.6
abstract final class AppTextScale {
  /// 이보다 크면 1.6배로 묶는다
  static const double max = 1.6;

  /// 이 배율부터 받은 테이프 목록 오른쪽 날짜를 부제 앞으로 옮긴다
  static const double compact = 1.3;
}
