import 'package:flutter/material.dart';

import '../themes/colors.dart';
import '../themes/dimens.dart';
import '../themes/text_styles.dart';
import 'css_paint.dart';
import 'keep_all.dart';

/// 크라프트 소포 박스 260×190 — 템플릿 `vSending` 블록.
abstract final class ParcelBox {
  static const size = Size(260, 190);
  static const double lidHeight = 46;
}

/// 박스 안쪽 (`#A87C44`).
class ParcelBoxInside extends StatelessWidget {
  const ParcelBoxInside({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.boxInside,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// 박스 앞면: 크라프트 그라데이션 + 박스 테이프 십자 + "받는 사람" 메모.
class ParcelBoxFront extends StatelessWidget {
  const ParcelBoxFront({super.key, required this.recipient});

  final String recipient;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: AppShadows.parcel,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: _FrontPainter(),
          child: Stack(
            children: [
              Positioned(
                right: 16,
                bottom: 16,
                width: 92,
                child: Transform.rotate(
                  angle: -3 * 3.141592653589793 / 180,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 9,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: AppShadows.memo,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          keepAll('받는 사람'),
                          style: AppText.suit(
                            600,
                            10,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          recipient,
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

class _FrontPainter extends CustomPainter {
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
    canvas.drawRect(Rect.fromLTWH(125, 0, 10, size.height), tape);
    canvas.drawRect(Rect.fromLTWH(0, 88, size.width, 12), tape);
    CssPaint.insetShadow(
      canvas,
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      spread: 1,
      color: AppColors.black.withValues(alpha: .06),
    );
  }

  @override
  bool shouldRepaint(_FrontPainter old) => false;
}

/// 박스 뚜껑 (높이 46).
class ParcelBoxLid extends StatelessWidget {
  const ParcelBoxLid({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(8),
          bottom: Radius.circular(2),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.flapTop, AppColors.flapBottom],
        ),
        boxShadow: AppShadows.flap,
      ),
      child: const Stack(
        children: [
          Positioned(
            left: 125,
            top: 0,
            bottom: 0,
            width: 10,
            child: ColoredBox(color: AppColors.flapTape),
          ),
        ],
      ),
    );
  }
}

/// 서랍 목록의 안 뜯은 소포 48×32.
class MiniParcel extends StatelessWidget {
  const MiniParcel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.miniTape.width,
      height: AppSizes.miniTape.height,
      decoration: BoxDecoration(
        color: AppColors.kraft,
        borderRadius: BorderRadius.circular(3),
        boxShadow: AppShadows.miniTape,
      ),
      child: const Stack(
        children: [
          Positioned(
            left: 21,
            top: 0,
            bottom: 0,
            width: 6,
            child: ColoredBox(color: AppColors.kraftTape),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 13,
            height: 6,
            child: ColoredBox(color: AppColors.kraftTape),
          ),
        ],
      ),
    );
  }
}
