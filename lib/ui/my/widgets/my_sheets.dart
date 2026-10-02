import 'package:flutter/material.dart';

import '../../core/ui/notice_copy.dart';

import '../../../domain/models/friend.dart';
import '../../../domain/models/report.dart';
import '../../../domain/models/sent_tape.dart';
import '../../../utils/format.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/dimens.dart';
import '../../core/themes/tape_palette.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/app_sheet.dart';
import '../../core/ui/buttons.dart';
import '../../core/ui/mini_tape.dart';
import '../../report/widgets/report_sheet.dart';
import 'sent_status.dart';
import '../view_model/my_view_model.dart';
import '../../core/ui/tappable.dart';
import '../../core/ui/keep_all.dart';

TextStyle get _title => AppText.suit(800, 20, letterSpacingEm: -.01);
TextStyle get _subMulti =>
    AppText.suit(500, 14, height: 1.55, color: AppColors.textSub);

/// 글자만 있는 48 버튼 (취소)
Widget _textButton(String label, VoidCallback onTap) => Tappable(
  behavior: HitTestBehavior.opaque,
  onTap: onTap,
  child: ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 48),
    child: Center(child: Text(label, style: AppText.suit(600, 14))),
  ),
);

/// 차단한 친구 행의 34 알약 버튼 (`#F3F3F1`, `700 13.5px`)
Widget _pillButton(String label, VoidCallback onTap) => Tappable(
  behavior: HitTestBehavior.opaque,
  onTap: onTap,
  child: Container(
    constraints: const BoxConstraints(minHeight: 34),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(17),
    ),
    child: Center(
      widthFactor: 1,
      child: Text(label, style: AppText.suit(700, 13.5)),
    ),
  ),
);

/// 친구 ⋯ (`shFriend`): 녹음해서 보내기 / 크레딧 선물하기 / 별명 설정 / 친구 삭제 / 신고하기 / 차단
Future<void> showFriendSheet(
  BuildContext context, {
  required Friend friend,
  required VoidCallback onRecord,
  required VoidCallback onGift,
  required VoidCallback onAlias,
  required VoidCallback onRemove,
  required VoidCallback onBlock,
}) {
  return showAppSheet<void>(
    context,
    builder: (sheet) {
      void then(VoidCallback f) {
        Navigator.of(sheet).pop();
        f();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(friend.name, style: AppText.sheetTitle),
          ),
          SheetRow(label: '녹음해서 보내기', onTap: () => then(onRecord)),
          SheetRow(label: '크레딧 선물하기', onTap: () => then(onGift)),
          SheetRow(
            label: '별명 설정',
            trailing: friend.nickname ?? '없음',
            trailingStyle: AppText.suit(500, 13.5, color: AppColors.textMuted),
            onTap: () => then(onAlias),
          ),
          SheetRow(label: '친구 삭제', onTap: () => then(onRemove)),
          SheetRow(
            label: '신고하기',
            onTap: () {
              Navigator.of(sheet).pop();
              showReportSheet(
                context,
                target: PersonReport(userId: friend.id, name: friend.name),
              );
            },
          ),
          SheetRow(
            label: '차단',
            danger: true,
            divider: false,
            onTap: () {
              Navigator.of(sheet).pop();
              showBlockSheet(context, name: friend.name, onBlock: onBlock);
            },
          ),
        ],
      );
    },
  );
}

/// 친구 차단 (`shBlock`)
Future<void> showBlockSheet(
  BuildContext context, {
  required String name,
  required VoidCallback onBlock,
}) {
  return showAppSheet<void>(
    context,
    builder: (sheet) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(keepAll('$name님을 차단할까요?'), style: _title),
        const SizedBox(height: 6),
        Text(
          keepAll('차단하면 $name님이 보낸 테이프를 받지 않아요.\n이미 받은 테이프는 서랍에 남아요.'),
          style: _subMulti,
        ),
        const SizedBox(height: 22),
        AppButton(
          label: '차단하기',
          onTap: () {
            Navigator.of(sheet).pop();
            onBlock();
          },
        ),
        const SizedBox(height: 2),
        _textButton('취소', () => Navigator.of(sheet).pop()),
      ],
    ),
  );
}

/// 차단한 친구 (`shBlocked`) — 신고 / 해제
Future<void> showBlockedSheet(
  BuildContext context, {
  required MyViewModel viewModel,
}) {
  return showAppSheet<void>(
    context,
    builder: (sheet) => ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final list = viewModel.blocked;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(keepAll('차단한 친구'), style: _title),
            ),
            for (final b in list)
              Container(
                constraints: const BoxConstraints(minHeight: 56),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.line)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        b.name,
                        style: AppText.suit(700, 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 이미 차단한 사람이라 신고 시트의 차단 체크는 숨긴다
                    _pillButton('신고', () {
                      Navigator.of(sheet).pop();
                      showReportSheet(
                        context,
                        target: PersonReport(userId: b.id, name: b.name),
                        alreadyBlocked: true,
                      );
                    }),
                    const SizedBox(width: 6),
                    _pillButton('해제', () => viewModel.unblock(b)),
                  ],
                ),
              ),
            if (list.isEmpty)
              SizedBox(
                height: 80,
                child: Center(
                  child: Text(
                    keepAll('차단한 친구가 없어요'),
                    style: AppText.suit(500, 14, color: AppColors.textFaint),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

/// 보낸 테이프 상세 (`shSentDetail`)
Future<void> showSentDetailSheet(
  BuildContext context, {
  required SentTape sent,
  required VoidCallback onReshare,
}) {
  final p = TapePalette.of(sent.type);
  Widget row(String k, String v, {Color ink = AppColors.ink}) => Container(
    constraints: const BoxConstraints(minHeight: 48),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: AppText.suit(600, 14.5, color: AppColors.textSub)),
        Text(v, style: AppText.suit(700, 14.5, color: ink)),
      ],
    ),
  );
  return showAppSheet<void>(
    context,
    builder: (sheet) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              MiniTape(palette: p),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 긴 이름은 줄바꿈 (`overflow-wrap:anywhere`)
                    Text(
                      keepAll('${sent.to}에게 보낸 테이프'),
                      style: AppText.suit(800, 20, height: 1.3),
                    ),
                    const SizedBox(height: 3),
                    SentStatusLabel(
                      sent: sent,
                      text: MyViewModel.sentShort(sent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        row('보낸 날', formatMonthDay(sent.date)),
        row('길이', p.name),
        row(
          '상태',
          MyViewModel.sentDetailStatus(sent),
          ink: sent.status == SentStatus.opened
              ? AppColors.ink
              : AppColors.textMuted,
        ),
        Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(AppRadius.row),
          ),
          child: Text(
            keepAll('테이프는 이제 받는 사람만 들을 수 있어요'),
            style: AppText.suit(
              500,
              13.5,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        if (MyViewModel.canReshare(sent)) ...[
          const SizedBox(height: 14),
          AppButton(
            label: '링크 다시 공유하기',
            onTap: () {
              Navigator.of(sheet).pop();
              onReshare();
            },
          ),
        ],
      ],
    ),
  );
}

/// 회원 탈퇴 (`shWithdraw`) — 확인을 체크해야 탈퇴할 수 있다.
Future<void> showWithdrawSheet(
  BuildContext context, {
  required MyViewModel viewModel,
  required VoidCallback onDone,
}) {
  return showAppSheet<void>(
    context,
    builder: (sheet) => _WithdrawForm(
      viewModel: viewModel,
      onDone: () {
        Navigator.of(sheet).pop();
        onDone();
      },
    ),
  );
}

class _WithdrawForm extends StatefulWidget {
  const _WithdrawForm({required this.viewModel, required this.onDone});

  final MyViewModel viewModel;
  final VoidCallback onDone;

  @override
  State<_WithdrawForm> createState() => _WithdrawFormState();
}

class _WithdrawFormState extends State<_WithdrawForm> {
  bool _ok = false;
  bool _busy = false;

  Future<void> _go() async {
    if (!_ok || _busy) return;
    setState(() => _busy = true);
    final done = await widget.viewModel.withdraw();
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    Widget line(String k, String v, {bool top = false}) => Container(
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        border: top
            ? const Border(top: BorderSide(color: AppColors.withdrawLine))
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: AppText.suit(600, 14.5)),
          Text(v, style: AppText.suit(800, 14.5, tabularNums: true)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(keepAll('정말 탈퇴할까요?'), style: _title),
        const SizedBox(height: 6),
        Text(keepAll('탈퇴하면 아래 내용이 모두 사라지고 되돌릴 수 없어요'), style: _subMulti),
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          child: Column(
            children: [
              line('받은 테이프', '${vm.receivedCount}개'),
              line('크레딧', '${vm.credits}', top: true),
              line('친구', '${vm.friendCount}명', top: true),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(keepAll(NoticeCopy.refundBeforeWithdraw), style: AppText.notice),
        const SizedBox(height: 6),
        Semantics(
          checked: _ok,
          child: Tappable(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _ok = !_ok),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _ok ? AppColors.ink : AppColors.paper,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.ink, width: 2),
                    ),
                    child: Opacity(
                      opacity: _ok ? 1 : 0,
                      child: Center(
                        child: Transform.rotate(
                          angle: -0.785,
                          child: Transform.translate(
                            offset: const Offset(1, -1),
                            child: Container(
                              width: 10,
                              height: 5,
                              decoration: const BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: AppColors.paper,
                                    width: 2,
                                  ),
                                  bottom: BorderSide(
                                    color: AppColors.paper,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    keepAll('모두 사라진다는 걸 확인했어요'),
                    style: AppText.suit(600, 14.5),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        AppButton(
          label: '탈퇴하기',
          background: _ok ? AppColors.red : AppColors.disabled,
          onTap: _go,
        ),
        const SizedBox(height: 2),
        _textButton('취소', () => Navigator.of(context).pop()),
      ],
    );
  }
}
