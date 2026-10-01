import 'package:flutter/material.dart';

import '../themes/colors.dart';
import '../themes/dimens.dart';
import '../themes/text_styles.dart';
import 'tappable.dart';

/// 바텀시트 — 템플릿 `sheetOn` 블록.
///
/// 딤 `rgba(0,0,0,.36)` `dimIn .2s`, 패널 `sheetUp .28s cubic-bezier(.2,.8,.2,1)`,
/// radius 26 26 0 0, 패딩 10 24 34, 손잡이 40×5 `#E3E3E0`. 탭바 위로 뜬다.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.dim,
    elevation: 0,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 280),
      curve: AppMotion.snap,
      reverseDuration: Duration(milliseconds: 200),
    ),
    builder: (context) => AppSheet(child: builder(context)),
  );
}

class AppSheet extends StatelessWidget {
  const AppSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.paper,
          borderRadius: AppRadius.sheetTop,
        ),
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AppColors.handle,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// 시트 선택지 행 (56, `700 16px`, 구분선 `#F0F0EE`). 위험한 동작은 레드.
class SheetRow extends StatelessWidget {
  const SheetRow({
    super.key,
    required this.label,
    required this.onTap,
    this.trailing,
    this.trailingStyle,
    this.danger = false,
    this.divider = true,
    this.labelColor,
  });

  final String label;
  final VoidCallback onTap;
  final String? trailing;
  final TextStyle? trailingStyle;
  final bool danger;
  final bool divider;

  /// 글자색 (없으면 검정, [danger]면 레드)
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Tappable(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            border: divider
                ? const Border(bottom: BorderSide(color: AppColors.line))
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppText.suit(
                    700,
                    16,
                    color:
                        labelColor ?? (danger ? AppColors.red : AppColors.ink),
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style:
                      trailingStyle ??
                      AppText.suit(600, 13, color: AppColors.textCount),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
