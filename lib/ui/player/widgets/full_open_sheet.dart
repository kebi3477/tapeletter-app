import 'package:flutter/material.dart';

import '../../../domain/models/shelf.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/buttons.dart';
import '../../core/ui/tappable.dart';

/// 서랍 꽉 참 알림 (`shFullOpen`) — 재생 화면에서 소포를 탭했는데 `stored >= cap`일 때.
/// 꽉 찬 선반 → 문구 → 칸별 보관 카드 → "서랍 넓히기" / "서랍 정리하기".
class FullOpenSheet extends StatelessWidget {
  const FullOpenSheet({
    super.key,
    required this.drawer,
    required this.buyLabel,
    required this.onBuy,
    required this.onTidy,
  });

  final Shelf drawer;

  /// "10개 더 · 100 크레딧"
  final String buyLabel;
  final VoidCallback onBuy;
  final VoidCallback onTidy;

  @override
  Widget build(BuildContext context) {
    const cap = ShelfGroup.defaultCap;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            children: [
              const _FullShelf(),
              const SizedBox(height: 18),
              Text(
                '서랍이 꽉 찼어요',
                style: AppText.suit(800, 20, letterSpacingEm: -.02),
              ),
              const SizedBox(height: 6),
              Text(
                '소포를 뜯으려면 서랍에 자리가 필요해요.\n테이프를 지우거나 서랍을 넓혀 주세요.',
                textAlign: TextAlign.center,
                style: AppText.suit(
                  500,
                  14,
                  height: 1.55,
                  color: AppColors.textSub,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // 칸별 보관 (`#F6F6F4` radius 16, 패딩 14 16, 간격 10)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('칸별 보관', style: AppText.suit(800, 14)),
                  Text(
                    '한 칸에 최대 $cap개',
                    style: AppText.suit(600, 12.5, color: AppColors.textSub),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 분류 안 함은 뜯은 테이프 수만 (`n개`, 칸 한도 없음)
              _GroupBar(
                name: '분류 안 함',
                n: drawer.unsorted.where((x) => x.opened).length,
                cap: cap,
                free: true,
              ),
              for (final g in drawer.groups) ...[
                const SizedBox(height: 10),
                _GroupBar(name: g.name, n: g.items.length, cap: g.cap),
              ],
              const SizedBox(height: 10),
              Container(height: 1, color: AppColors.cardDivider),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('서랍 전체', style: AppText.suit(700, 13.5)),
                  Text(
                    '${drawer.stored}/${drawer.cap}',
                    style: AppText.suit(
                      800,
                      13,
                      tabularNums: true,
                      color: AppColors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AppButton(
          label: '서랍 넓히기',
          gap: 6,
          onTap: onBuy,
          trailing: Text(
            buyLabel,
            style: AppText.suit(600, 13, color: AppColors.paperMuted),
          ),
        ),
        const SizedBox(height: 2),
        Semantics(
          button: true,
          child: Tappable(
            behavior: HitTestBehavior.opaque,
            onTap: onTidy,
            child: SizedBox(
              height: 52,
              child: Center(
                child: Text(
                  '서랍 정리하기',
                  style: AppText.suit(700, 15, color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 칸 이름(72) + 10칸 막대 + `n/10`. 꽉 찬 칸은 레드, 분류 안 함은 `n개`.
class _GroupBar extends StatelessWidget {
  const _GroupBar({
    required this.name,
    required this.n,
    required this.cap,
    this.free = false,
  });

  final String name;
  final int n;
  final int cap;
  final bool free;

  @override
  Widget build(BuildContext context) {
    final full = !free && n >= cap;
    final fill = full ? AppColors.red : AppColors.ink;
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.suit(700, 13.5),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < 10; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                Expanded(
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: i < n ? fill : AppColors.handle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 38,
          child: Text(
            free ? '$n개' : '$n/$cap',
            textAlign: TextAlign.right,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: AppText.suit(
              700,
              12.5,
              tabularNums: true,
              color: full ? AppColors.red : AppColors.textSub,
            ),
          ),
        ),
      ],
    );
  }
}

/// 꽉 찬 선반 (200 폭): 판 62 + 등 10개(14×50, 간격 2) + 받침 8.
class _FullShelf extends StatelessWidget {
  const _FullShelf();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Column(
        children: [
          Container(
            height: 62,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.shelfBoardTop, AppColors.shelfBoardBottom],
              ),
            ),
            alignment: Alignment.bottomCenter,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < AppColors.fullSpines.length; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Container(
                    width: 14,
                    height: 50,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.fullSpines[i],
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(2),
                        bottom: Radius.circular(1),
                      ),
                    ),
                    alignment: Alignment.centerRight,
                    child: Container(width: 2, color: AppColors.spineShade),
                  ),
                ],
              ],
            ),
          ),
          Container(
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.shelfPlank,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(3)),
            ),
          ),
        ],
      ),
    );
  }
}
