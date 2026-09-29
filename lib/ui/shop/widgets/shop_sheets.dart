import 'package:flutter/material.dart';

import '../../core/ui/notice_copy.dart';

import '../../../domain/models/shop.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/dimens.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/app_sheet.dart';
import '../../core/ui/buttons.dart';
import '../../core/ui/credit_icon.dart';
import '../view_model/shop_view_model.dart';
import '../../core/ui/tappable.dart';

/// [ShopViewModel.sheet]이 생기면 바텀시트를 열고, 없어지면 닫는다.
///
/// 프로토타입처럼 시트 하나 안에서 구매 → 충전 → 결제 → 구매로 내용만 바뀐다.
class ShopSheetHost extends StatefulWidget {
  const ShopSheetHost({
    super.key,
    required this.viewModel,
    required this.child,
  });

  final ShopViewModel viewModel;
  final Widget child;

  @override
  State<ShopSheetHost> createState() => _ShopSheetHostState();
}

class _ShopSheetHostState extends State<ShopSheetHost> {
  BuildContext? _sheetContext;

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_sync);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    final open = _sheetContext != null;
    final want = widget.viewModel.sheet != null;
    if (want && !open) {
      _sheetContext = context; // 여는 중 표시
      showAppSheet<void>(
        context,
        builder: (sheet) {
          _sheetContext = sheet;
          return ShopSheetBody(viewModel: widget.viewModel);
        },
      ).whenComplete(() {
        _sheetContext = null;
        // 딤이나 끌어내리기로 닫았다
        if (widget.viewModel.sheet != null) widget.viewModel.closeSheet();
      });
    } else if (!want && open) {
      final sheet = _sheetContext!;
      if (sheet != context && sheet.mounted) Navigator.of(sheet).pop();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 시트 내용 — `shBuy` `shCharge` `shPay` `shPayFail` `shAd` `shAdFail` `shGift`
class ShopSheetBody extends StatelessWidget {
  const ShopSheetBody({super.key, required this.viewModel});

  final ShopViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final vm = viewModel;
        return switch (vm.sheet) {
          BuySheet(:final item) => _Buy(vm: vm, item: item),
          ChargeSheet(:final need) => _Charge(vm: vm, need: need),
          PaySheet(:final pack) => _Pay(vm: vm, pack: pack),
          PayFailSheet() => _PayFail(vm: vm),
          AdSheet(:final count) => _Ad(vm: vm, count: count),
          AdFailSheet() => _AdFail(vm: vm),
          GiftSheet() => _Gift(vm: vm, sheet: vm.sheet! as GiftSheet),
          null => const SizedBox.shrink(),
        };
      },
    );
  }
}

TextStyle get _title => AppText.suit(800, 20, letterSpacingEm: -.01);
TextStyle get _sub => AppText.suit(500, 14, color: AppColors.textSub);
TextStyle get _subMulti =>
    AppText.suit(500, 14, height: 1.55, color: AppColors.textSub);

/// 글자만 있는 48 버튼 (닫기·취소·결제 취소)
class _TextButton extends StatelessWidget {
  const _TextButton({
    required this.label,
    required this.onTap,
    this.color = AppColors.ink,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Tappable(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Center(
          child: Text(label, style: AppText.suit(600, 14, color: color)),
        ),
      ),
    ),
  );
}

/// 구매 확인 (`shBuy`)
class _Buy extends StatelessWidget {
  const _Buy({required this.vm, required this.item});

  final ShopViewModel vm;
  final ShopItem item;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(item.name, style: _title),
      const SizedBox(height: 6),
      Text(
        '${item.price} 크레딧 · 남는 크레딧 ${vm.credits - item.price}',
        style: _sub,
      ),
      const SizedBox(height: 24),
      AppButton(label: '구매', onTap: vm.confirmBuy),
      const SizedBox(height: 12),
      Text(
        NoticeCopy.noRefundPurchase,
        textAlign: TextAlign.center,
        style: AppText.notice,
      ),
    ],
  );
}

/// 크레딧 부족 (`shCharge`)
class _Charge extends StatelessWidget {
  const _Charge({required this.vm, required this.need});

  final ShopViewModel vm;
  final int need;

  @override
  Widget build(BuildContext context) {
    Widget row(String left, String right, VoidCallback onTap, Color ink) =>
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Tappable(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(left, style: AppText.suit(700, 15)),
                  Text(right, style: AppText.suit(600, 15, color: ink)),
                ],
              ),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('크레딧이 $need 부족해요', style: AppText.suit(800, 20)),
        const SizedBox(height: 6),
        Text('충전하면 바로 이어서 살 수 있어요', style: _sub),
        const SizedBox(height: 12),
        row(
          '광고 보고 받기',
          '+10 · ${vm.adsLeft}번 남음',
          vm.openAd,
          AppColors.textMuted,
        ),
        for (final p in vm.catalog.packs)
          row(
            '${_comma(p.credits)} 크레딧',
            p.priceLabel,
            () => vm.charge(p),
            AppColors.textSecondary,
          ),
        const SizedBox(height: 12),
        Text(NoticeCopy.refundWithin7Days, style: AppText.notice),
      ],
    );
  }
}

String _comma(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// 결제 진행 (`shPay`) — 44 스피너, 1.4초
class _Pay extends StatelessWidget {
  const _Pay({required this.vm, required this.pack});

  final ShopViewModel vm;
  final CreditPack pack;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 10),
      const Center(
        child: SizedBox.square(
          dimension: 44,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppColors.ink,
            backgroundColor: AppColors.line,
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        '${pack.priceLabel} 결제 중이에요',
        textAlign: TextAlign.center,
        style: AppText.suit(800, 20),
      ),
      const SizedBox(height: 6),
      Text(
        '${_comma(pack.credits)} 크레딧 · 잠시만 기다려 주세요',
        textAlign: TextAlign.center,
        style: _sub,
      ),
      const SizedBox(height: 18),
      _TextButton(
        label: '결제 취소',
        onTap: vm.payCancel,
        color: AppColors.textSub,
      ),
    ],
  );
}

/// 결제 실패 (`shPayFail`)
class _PayFail extends StatelessWidget {
  const _PayFail({required this.vm});

  final ShopViewModel vm;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('결제하지 못했어요', style: _title),
      const SizedBox(height: 6),
      Text(
        '카드 정보를 확인하거나 다른 결제 수단으로\n다시 시도해 주세요. 돈은 빠져나가지 않았어요.',
        style: _subMulti,
      ),
      const SizedBox(height: 22),
      AppButton(label: '다시 시도', onTap: vm.payRetry),
      const SizedBox(height: 2),
      _TextButton(label: '닫기', onTap: vm.payClose),
    ],
  );
}

/// 광고 (`shAd`) — 200 높이 검정 카드, 카운트 3·2·1, ✕
class _Ad extends StatelessWidget {
  const _Ad({required this.vm, required this.count});

  final ShopViewModel vm;
  final int count;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '광고',
                    style: AppText.suit(
                      600,
                      13,
                      color: AppColors.paper.withValues(alpha: .6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$count',
                    style: AppText.suit(
                      800,
                      34,
                      color: AppColors.paper,
                      tabularNums: true,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Semantics(
                button: true,
                label: '광고 닫기',
                excludeSemantics: true,
                child: Tappable(
                  onTap: vm.closeAd,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.paper.withValues(alpha: .16),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '✕',
                      style: AppText.suit(
                        600,
                        13,
                        height: 1,
                        color: AppColors.paper,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text(
        '끝까지 보면 10 크레딧을 받아요',
        textAlign: TextAlign.center,
        style: AppText.suit(500, 13, color: AppColors.textMuted),
      ),
    ],
  );
}

/// 광고 불러오기 실패 (`shAdFail`)
class _AdFail extends StatelessWidget {
  const _AdFail({required this.vm});

  final ShopViewModel vm;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('광고를 불러오지 못했어요', style: _title),
      const SizedBox(height: 6),
      Text('잠시 후 다시 시도해 주세요.\n충전으로도 크레딧을 받을 수 있어요.', style: _subMulti),
      const SizedBox(height: 22),
      AppButton(label: '확인', onTap: vm.adFailOk),
    ],
  );
}

/// 크레딧 선물하기 (`shGift`)
class _Gift extends StatelessWidget {
  const _Gift({required this.vm, required this.sheet});

  final ShopViewModel vm;
  final GiftSheet sheet;

  @override
  Widget build(BuildContext context) {
    final label = AppText.suit(600, 13, color: AppColors.textMuted);
    final to = sheet.to;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('크레딧 선물하기', style: AppText.suit(800, 20)),
            Text(
              '보유 ${vm.credits}',
              style: AppText.suit(
                600,
                13,
                color: AppColors.textMuted,
                tabularNums: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('받는 사람', style: label),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: OverflowBox(
            maxWidth: MediaQuery.sizeOf(context).width,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                for (final (i, f) in vm.giftFriends.indexed) ...[
                  if (i > 0) const SizedBox(width: 6),
                  _Chip(
                    label: f.name,
                    on: to?.id == f.id,
                    onTap: () => vm.selectGiftTo(f),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('크레딧', style: label),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final (i, n) in vm.catalog.giftAmounts.indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: _AmountPill(
                  amount: n,
                  on: sheet.amount == n,
                  onTap: () => vm.selectGiftAmount(n),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 22),
        AppButton(
          label: to == null
              ? '받는 사람을 골라주세요'
              : '${to.name}에게 ${sheet.amount} 크레딧 보내기',
          background: to == null ? AppColors.disabled : AppColors.ink,
          onTap: vm.sendGift,
        ),
      ],
    );
  }
}

/// 친구 칩 (높이 40, 선택 시 `#111`/흰 글자)
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tappable(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: on ? AppColors.ink : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: AppText.suit(
            700,
            14,
            color: on ? AppColors.paper : AppColors.ink,
          ),
        ),
      ),
    ),
  );
}

/// 금액 알약 44 (아이콘 14 + 숫자)
class _AmountPill extends StatelessWidget {
  const _AmountPill({
    required this.amount,
    required this.on,
    required this.onTap,
  });

  final int amount;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: on,
    label: '$amount 크레딧',
    excludeSemantics: true,
    child: Tappable(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: on ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CreditIcon(size: 14),
            const SizedBox(width: 5),
            Text(
              '$amount',
              style: AppText.suit(
                800,
                15,
                tabularNums: true,
                color: on ? AppColors.paper : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
