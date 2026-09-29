import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/models/share_link.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/animations.dart';
import '../../core/ui/buttons.dart';
import '../../core/ui/css_paint.dart';
import '../../core/ui/tappable.dart';

/// 링크 오류 (`leOn`) — 이미 받은 링크 / 만료된 링크 / 내가 보낸 링크.
class LinkErrorScreen extends StatelessWidget {
  const LinkErrorScreen({
    super.key,
    required this.kind,
    required this.myName,
    required this.onClose,
    required this.onReshare,
  });

  final LinkErrorKind kind;

  /// own일 때 메모에 "보낸 사람 · 나"
  final String myName;
  final VoidCallback onClose;

  /// own: 링크 다시 공유하기
  final VoidCallback onReshare;

  @override
  Widget build(BuildContext context) {
    // logic.js `LE`
    final (top, name, title, sub, cta) = switch (kind) {
      LinkErrorKind.taken => (
        '받는 사람',
        '이미 받음',
        '이미 다른 분이 받은 테이프예요',
        '테이프는 한 사람만 받을 수 있어요.\n보낸 분께 다시 보내 달라고 해보세요.',
        '확인',
      ),
      LinkErrorKind.expired => (
        '보관 기한',
        '지남',
        '링크가 만료됐어요',
        '받지 않은 테이프는 7일이 지나면 사라져요.\n보낸 분께 다시 보내 달라고 해보세요.',
        '확인',
      ),
      LinkErrorKind.own => (
        '보낸 사람',
        myName,
        '내가 보낸 테이프예요',
        '테이프는 받는 사람만 들을 수 있어요.\n링크를 다시 보낼까요?',
        '링크 다시 공유하기',
      ),
    };
    final own = kind == LinkErrorKind.own;
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: FadeUp(
          duration: const Duration(milliseconds: 300),
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Semantics(
                      button: true,
                      label: '닫기',
                      excludeSemantics: true,
                      child: Tappable(
                        behavior: HitTestBehavior.opaque,
                        onTap: onClose,
                        child: SizedBox.square(
                          dimension: 44,
                          child: Center(
                            child: Text(
                              '✕',
                              style: AppText.suit(400, 22, height: 1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 흑백·반투명 (내 링크만 컬러)
                      Opacity(
                        opacity: own ? 1 : .5,
                        child: ColorFiltered(
                          colorFilter: own
                              ? const ColorFilter.mode(
                                  Colors.transparent,
                                  BlendMode.dst,
                                )
                              : const ColorFilter.matrix(_grayscale),
                          child: _SmallParcel(top: top, name: name),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: AppText.suit(
                          800,
                          24,
                          height: 1.3,
                          letterSpacingEm: -.02,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        sub,
                        textAlign: TextAlign.center,
                        style: AppText.suit(
                          500,
                          15,
                          height: 1.55,
                          color: AppColors.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, bottomSafe(context)),
                child: Column(
                  children: [
                    AppButton(label: cta, onTap: own ? onReshare : onClose),
                    if (own) ...[
                      const SizedBox(height: 2),
                      Tappable(
                        behavior: HitTestBehavior.opaque,
                        onTap: onClose,
                        child: SizedBox(
                          height: 48,
                          child: Center(
                            child: Text('닫기', style: AppText.suit(600, 14)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// `filter: grayscale(1)`
  static const _grayscale = <double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// 200×146 크라프트 박스 + 메모
class _SmallParcel extends StatelessWidget {
  const _SmallParcel({required this.top, required this.name});

  final String top;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 146,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: .35),
            offset: const Offset(0, 14),
            blurRadius: 30,
            spreadRadius: -12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: _KraftPainter(),
          child: Stack(
            children: [
              Positioned(
                right: 14,
                bottom: 14,
                width: 92,
                child: Transform.rotate(
                  angle: -3 * math.pi / 180,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 9,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.black.withValues(alpha: .15),
                          offset: const Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          top,
                          style: AppText.suit(
                            600,
                            10,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          softWrap: false,
                          style: AppText.suit(800, 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KraftPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = CssPaint.linearGradient(rect, 135, const [
          AppColors.kraftLight,
          AppColors.kraftDark,
        ]),
    );
    final tape = Paint()..color = AppColors.kraftTape;
    canvas.drawRect(Rect.fromLTWH(95, 0, 10, size.height), tape);
    canvas.drawRect(Rect.fromLTWH(0, 67, size.width, 12), tape);
  }

  @override
  bool shouldRepaint(_KraftPainter old) => false;
}
