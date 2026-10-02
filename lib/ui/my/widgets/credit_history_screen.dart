import 'package:flutter/material.dart';

import '../../core/themes/colors.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/buttons.dart';
import '../../core/ui/credit_icon.dart';
import '../view_model/credit_history_view_model.dart';
import '../../core/ui/tappable.dart';

/// 크레딧 내역 — 템플릿 `histOn` 블록 (탭바 위 오버레이).
class CreditHistoryScreen extends StatefulWidget {
  const CreditHistoryScreen({
    super.key,
    required this.viewModel,
    required this.onBack,
    required this.onCharge,
  });

  final CreditHistoryViewModel viewModel;
  final VoidCallback onBack;

  /// 충전하기 → 상점
  final VoidCallback onCharge;

  @override
  State<CreditHistoryScreen> createState() => _CreditHistoryScreenState();
}

class _CreditHistoryScreenState extends State<CreditHistoryScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // 끝 가까이 오면 다음 페이지 (`nextCursor`)
    _scroll.addListener(() {
      final p = _scroll.position;
      if (p.pixels > p.maxScrollExtent - 200) widget.viewModel.loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: vm,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BackBar(onBack: widget.onBack),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '크레딧',
                      style: AppText.suit(600, 13, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const CreditIcon(size: 28),
                        const SizedBox(width: 10),
                        Text(
                          '${vm.credits}',
                          style: AppText.suit(800, 34, tabularNums: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Tappable(
                      onTap: widget.onCharge,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 40),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          widthFactor: 1,
                          child: Text('충전하기', style: AppText.suit(700, 14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.line)),
                  ),
                  child: ListView.builder(
                    controller: _scroll,
                    padding: EdgeInsets.fromLTRB(
                      24,
                      0,
                      24,
                      24 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    itemCount: vm.entries.length,
                    itemBuilder: (context, i) {
                      final e = vm.entries[i];
                      return Container(
                        constraints: const BoxConstraints(minHeight: 64),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppColors.line),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.reason, style: AppText.suit(700, 15)),
                                  const SizedBox(height: 2),
                                  Text(
                                    CreditHistoryViewModel.dateText(e),
                                    style: AppText.suit(
                                      500,
                                      12.5,
                                      color: AppColors.textMuted,
                                      tabularNums: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              CreditHistoryViewModel.amountText(e),
                              style: AppText.suit(
                                800,
                                16,
                                tabularNums: true,
                                color: e.amount > 0
                                    ? AppColors.ink
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
