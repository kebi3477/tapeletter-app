import 'package:flutter/material.dart';

import '../../../domain/models/sent_tape.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/text_styles.dart';
import '../view_model/my_view_model.dart';

/// 보낸 테이프 상태 색 (`sentSt(r)`): 링크 대기 레드 · 열어 봄 검정 · 안 열어 봄 빈 점
extension SentKindStyle on SentKind {
  /// 글자 (`stInk`)
  Color get ink => switch (this) {
    SentKind.link => AppColors.red,
    SentKind.heard => AppColors.ink,
    SentKind.sealed => AppColors.textMuted,
  };

  /// 점 안 (`stDot`)
  Color get dot => switch (this) {
    SentKind.link => AppColors.red,
    SentKind.heard => AppColors.ink,
    SentKind.sealed => Colors.transparent,
  };

  /// 점 테두리 1.5 (`stRing`)
  Color get ring => switch (this) {
    SentKind.link => AppColors.red,
    SentKind.heard => AppColors.ink,
    SentKind.sealed => AppColors.textFaint,
  };
}

/// 상태 점 7 + 상태 `700 12.5` (점과 간격 5)
class SentStatusLabel extends StatelessWidget {
  const SentStatusLabel({super.key, required this.sent, required this.text});

  final SentTape sent;
  final String text;

  @override
  Widget build(BuildContext context) {
    final k = MyViewModel.sentKind(sent);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: k.dot,
            shape: BoxShape.circle,
            border: Border.all(color: k.ring, width: 1.5),
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: AppText.suit(
              700,
              12.5,
              height: 1.35,
              tabularNums: true,
              color: k.ink,
            ),
          ),
        ),
      ],
    );
  }
}
