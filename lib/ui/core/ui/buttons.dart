import 'package:flutter/material.dart';

import '../themes/colors.dart';
import '../themes/dimens.dart';
import '../themes/text_styles.dart';
import 'tappable.dart';

/// 하단 56 버튼 (radius 16, `700 16px`). 검정·회색·카카오 변형은 색만 바꾼다.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onTap,
    this.background = AppColors.ink,
    this.foreground = AppColors.paper,
    this.leading,
    this.gap = 8,
    this.height = AppSizes.primaryButton,
    this.radius = AppRadius.button,
    this.textStyle,
  });

  /// 회색(`#F3F3F1`) 버튼
  const AppButton.soft({
    super.key,
    required this.label,
    required this.onTap,
    this.leading,
    this.gap = 8,
    this.height = AppSizes.primaryButton,
    this.radius = AppRadius.button,
    this.textStyle,
  }) : background = AppColors.surface,
       foreground = AppColors.ink;

  final String label;
  final VoidCallback? onTap;
  final Color background;
  final Color foreground;
  final Widget? leading;
  final double gap;
  final double height;
  final double radius;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tappable(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // 비활성(회색 `#CFCFCC`) 버튼은 눌러도 울리지 않는다 (안내 토스트만)
        haptic: background == AppColors.disabled
            ? Haptic.none
            : Haptic.selection,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: height,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(radius),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, SizedBox(width: gap)],
              Text(
                label,
                style: (textStyle ?? AppText.button).copyWith(
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ‹ 뒤로가기 바 (높이 56, 패딩 0 12, 터치 영역 44).
class BackBar extends StatelessWidget {
  const BackBar({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.backBar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            button: true,
            label: '뒤로',
            child: Tappable(
              behavior: HitTestBehavior.opaque,
              onTap: onBack,
              child: SizedBox(
                width: AppSizes.minTap,
                height: AppSizes.minTap,
                child: Center(
                  child: Text('‹', style: AppText.suit(300, 32, height: 1)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 하단 버튼 영역 아래 여백 30. 홈 인디케이터가 더 크면 그만큼 띄운다.
double bottomSafe(BuildContext context) {
  final inset = MediaQuery.viewPaddingOf(context).bottom;
  return inset > AppSpacing.bottomSafe ? inset : AppSpacing.bottomSafe;
}
