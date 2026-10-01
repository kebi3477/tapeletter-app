import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/report.dart';
import '../../core/ui/text_limits.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/dimens.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/app_sheet.dart';
import '../../core/ui/buttons.dart';
import '../../core/ui/choice_chip.dart';
import '../view_model/report_view_model.dart';
import '../../core/ui/tappable.dart';

/// 신고 (`shReport`) — 테이프 ⋯, 친구 ⋯, 차단한 친구 "신고", 재생 화면 ⋯에서 연다.
/// 네트워크가 끊기면 같은 시트에서 `shReportFail`로 바뀌고, 적은 내용은 남는다.
Future<void> showReportSheet(
  BuildContext context, {
  required ReportTarget target,
  bool alreadyBlocked = false,
}) {
  final vm = ReportViewModel(
    target: target,
    reports: context.read(),
    friends: context.read(),
    toast: context.read(),
    alreadyBlocked: alreadyBlocked,
  );
  return showAppSheet<void>(
    context,
    builder: (sheet) => ReportSheet(viewModel: vm),
  ).whenComplete(vm.dispose);
}

class ReportSheet extends StatefulWidget {
  const ReportSheet({super.key, required this.viewModel});

  final ReportViewModel viewModel;

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  late final TextEditingController _memo = TextEditingController(
    text: widget.viewModel.memo,
  );

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onChange);
  }

  void _onChange() {
    if (widget.viewModel.done && mounted) {
      widget.viewModel.removeListener(_onChange);
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onChange);
    _memo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) => Flexible(
        child: SingleChildScrollView(
          child: vm.failed ? _FailView(vm: vm) : _Form(vm: vm, memo: _memo),
        ),
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({required this.vm, required this.memo});

  final ReportViewModel vm;
  final TextEditingController memo;

  @override
  Widget build(BuildContext context) {
    final n = vm.memoLength;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('무엇이 문제인가요?', style: AppText.suit(800, 20, letterSpacingEm: -.01)),
        const SizedBox(height: 6),
        Text(
          vm.subtitle,
          style: AppText.suit(500, 14, color: AppColors.textSub),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final r in ReportReason.values)
              AppChoiceChip(
                label: r.label,
                selected: vm.reason == r,
                onTap: () => vm.selectReason(r),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          '자세히 적기 (선택)',
          style: AppText.suit(600, 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 88,
          child: TextField(
            controller: memo,
            onChanged: vm.setMemo,
            // 300자까지 (`slice(0, 300)`) — 한글 조합 중에도 넘지 않는다
            inputFormatters: [maxCharacters(ReportViewModel.memoMax)],
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            style: AppText.suit(500, 15, height: 1.5),
            cursorColor: AppColors.ink,
            decoration: InputDecoration(
              hintText: '어떤 일이 있었는지 알려 주세요',
              hintStyle: AppText.suit(
                500,
                15,
                height: 1.5,
                color: AppColors.textFaint,
              ),
              filled: true,
              fillColor: AppColors.surfaceSoft,
              isCollapsed: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$n/${ReportViewModel.memoMax}',
          textAlign: TextAlign.right,
          style: AppText.suit(
            600,
            12.5,
            tabularNums: true,
            color: n >= ReportViewModel.memoMax
                ? AppColors.red
                : AppColors.textFaint,
          ),
        ),
        if (vm.canBlock)
          _BlockToggle(
            label: vm.blockLabel,
            on: vm.block,
            onTap: vm.toggleBlock,
          ),
        const SizedBox(height: 10),
        _SubmitButton(label: vm.cta, enabled: vm.canSubmit, onTap: vm.submit),
        const SizedBox(height: 2),
        _TextButton('취소', () => Navigator.of(context).pop()),
      ],
    );
  }
}

/// 신고를 보내지 못했어요 (`shReportFail`)
class _FailView extends StatelessWidget {
  const _FailView({required this.vm});

  final ReportViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '신고를 보내지 못했어요',
          style: AppText.suit(800, 20, letterSpacingEm: -.01),
        ),
        const SizedBox(height: 6),
        Text(
          '인터넷 연결을 확인하고 다시 시도해 주세요.\n적은 내용은 그대로 남아 있어요.',
          style: AppText.suit(500, 14, height: 1.55, color: AppColors.textSub),
        ),
        const SizedBox(height: 22),
        AppButton(label: vm.busy ? '보내는 중…' : '다시 시도', onTap: vm.retry),
        const SizedBox(height: 2),
        _TextButton('돌아가기', vm.back),
      ],
    );
  }
}

/// "○○님 차단하기" (48, 체크 상자 22·radius 6·테두리 2)
class _BlockToggle extends StatelessWidget {
  const _BlockToggle({
    required this.label,
    required this.on,
    required this.onTap,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: on,
      child: Tappable(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: on ? AppColors.ink : AppColors.paper,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.ink, width: 2),
                ),
                alignment: Alignment.center,
                child: Opacity(
                  opacity: on ? 1 : 0,
                  // rotate(-45deg) translate(1px, -1px)
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationZ(-math.pi / 4)
                      ..translateByDouble(1, -1, 0, 1),
                    child: Container(
                      width: 10,
                      height: 5,
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: AppColors.paper, width: 2),
                          bottom: BorderSide(color: AppColors.paper, width: 2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: AppText.suit(600, 14.5))),
            ],
          ),
        ),
      ),
    );
  }
}

/// 신고하기 (56, radius 16, 사유를 고르기 전·보내는 중에는 `#CFCFCC`, `background .2s`)
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Tappable(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: AppSizes.primaryButton,
          decoration: BoxDecoration(
            color: enabled ? AppColors.ink : AppColors.disabled,
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppText.suit(700, 16, color: AppColors.paper),
          ),
        ),
      ),
    );
  }
}

class _TextButton extends StatelessWidget {
  const _TextButton(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tappable(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: SizedBox(
      height: 48,
      child: Center(child: Text(label, style: AppText.suit(600, 14))),
    ),
  );
}
