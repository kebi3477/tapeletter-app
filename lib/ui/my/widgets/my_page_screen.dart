import 'package:flutter/material.dart';

import '../../../domain/models/friend.dart';
import '../../../domain/models/sent_tape.dart';
import '../../../utils/format.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/dimens.dart';
import '../../core/themes/tape_palette.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/buttons.dart';
import '../../core/ui/mini_tape.dart';
import '../../core/ui/parcel_box.dart';
import '../../friend/widgets/alias_sheet.dart';
import 'sent_status.dart';
import '../view_model/my_view_model.dart';
import 'my_sheets.dart';
import '../../core/ui/tappable.dart';
import '../../core/ui/keep_all.dart';

/// 마이 하위 화면 (`mpOn`) — 받은 테이프 · 보낸 테이프 · 친구 · 설정.
/// 탭바 위를 덮는 오버레이다 (`slideUp .3s`).
class MyPageScreen extends StatefulWidget {
  const MyPageScreen({
    super.key,
    required this.page,
    required this.viewModel,
    required this.onBack,
    required this.onOpenItem,
    required this.onOpenFriend,
    required this.onRecordTo,
    required this.onGift,
    required this.onOpenHistory,
    required this.onSignedOut,
  });

  final MyPage page;
  final MyViewModel viewModel;

  /// ‹ (`closeMp`)
  final VoidCallback onBack;

  /// 받은 테이프 행 → 재생 (`openItem`)
  final ValueChanged<ReceivedTape> onOpenItem;
  final ValueChanged<Friend> onOpenFriend;
  final ValueChanged<Friend> onRecordTo;
  final ValueChanged<Friend> onGift;
  final VoidCallback onOpenHistory;
  final VoidCallback onSignedOut;

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // 보낸 테이프: 끝 가까이 오면 다음 페이지
    _scroll.addListener(() {
      if (widget.page != MyPage.sent) return;
      final p = _scroll.position;
      if (p.pixels > p.maxScrollExtent - 400) widget.viewModel.loadMoreSent();
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
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.page.title, style: AppText.bigTitle),
                    const SizedBox(height: 4),
                    Text(
                      vm.pageSubtitle(widget.page),
                      style: AppText.suit(
                        500,
                        13.5,
                        color: AppColors.textMuted,
                        tabularNums: true,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: switch (widget.page) {
                      MyPage.recv => _received(vm),
                      MyPage.sent => [_sent(context, vm)],
                      MyPage.friends => _friends(context, vm),
                      MyPage.settings => _settings(context, vm),
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

  List<Widget> _received(MyViewModel vm) => [
    for (final x in vm.received)
      ReceivedRow(tape: x, onTap: () => widget.onOpenItem(x)),
    if (vm.received.isEmpty)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
        child: Text(
          keepAll('아직 받은 테이프가 없어요'),
          textAlign: TextAlign.center,
          style: AppText.suit(500, 14, height: 1.5, color: AppColors.textFaint),
        ),
      ),
  ];

  Widget _sent(BuildContext context, MyViewModel vm) => SentCard(
    vm: vm,
    onTap: (s) =>
        showSentDetailSheet(context, sent: s, onReshare: () => vm.reshare(s)),
  );

  List<Widget> _friends(BuildContext context, MyViewModel vm) => [
    for (final f in vm.friends)
      MyFriendRow(
        friend: f,
        onTap: () => widget.onOpenFriend(f),
        onStar: () => vm.toggleStar(f),
        onMore: () => showFriendSheet(
          context,
          friend: f,
          onRecord: () => widget.onRecordTo(f),
          onGift: () => widget.onGift(f),
          onAlias: () => showAliasSheet(
            context,
            friend: f,
            onSave: (v) => vm.setNickname(f, v),
          ),
          onRemove: () => vm.removeFriend(f),
          onBlock: () => vm.block(f),
        ),
      ),
  ];

  List<Widget> _settings(BuildContext context, MyViewModel vm) => [
    SettingRow(
      label: '알림',
      onTap: vm.toggleNotifications,
      trailing: SettingToggle(on: vm.notificationsOn),
    ),
    SettingRow(label: '연결된 계정', trailing: SettingValue(vm.providerText)),
    SettingRow(
      label: '크레딧 내역',
      onTap: widget.onOpenHistory,
      trailing: const Chevron(),
    ),
    SettingRow(
      label: '차단한 친구',
      onTap: () => showBlockedSheet(context, viewModel: vm),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SettingValue(vm.blockedCountText),
          const SizedBox(width: 8),
          const Chevron(),
        ],
      ),
    ),
    Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 4),
      child: Text('정보', style: AppText.suit(800, 16)),
    ),
    SettingRow(
      label: '이용약관',
      onTap: () => vm.openDoc(AppDoc.terms),
      trailing: const Chevron(),
    ),
    SettingRow(
      label: '개인정보 처리방침',
      onTap: () => vm.openDoc(AppDoc.privacy),
      trailing: const Chevron(),
    ),
    SettingRow(
      label: '문의하기',
      onTap: () => vm.openDoc(AppDoc.contact),
      trailing: const Chevron(),
    ),
    SettingRow(
      label: '앱 버전',
      trailing: SettingValue(vm.version, tabular: true),
    ),
    Container(
      height: 1,
      margin: const EdgeInsets.only(top: 14, bottom: 4),
      color: AppColors.line,
    ),
    SettingRow(
      label: '로그아웃',
      onTap: () async {
        await vm.logout();
        widget.onSignedOut();
      },
    ),
    SettingRow(
      label: '회원 탈퇴',
      color: AppColors.textFaint,
      onTap: () =>
          showWithdrawSheet(context, viewModel: vm, onDone: widget.onSignedOut),
    ),
  ];
}

/// 받은 테이프 행 60 (`recvList`): 미니 테이프(안 뜯었으면 소포), 보낸 사람, `칸 · 길이`, 레드 점, 날짜
class ReceivedRow extends StatelessWidget {
  const ReceivedRow({super.key, required this.tape, required this.onTap});

  final ReceivedTape tape;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final x = tape.item;
    // 큰 글씨(1.3배 이상): 오른쪽 날짜를 부제 앞으로 옮겨 본문 폭을 확보한다 (v10.4)
    final big =
        MediaQuery.textScalerOf(context).scale(1) >= AppTextScale.compact;
    return Semantics(
      button: true,
      child: Tappable(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Row(
            children: [
              SizedBox(
                width: AppSizes.miniTape.width,
                height: AppSizes.miniTape.height,
                child: tape.boxed
                    ? const MiniParcel()
                    : MiniTape(palette: TapePalette.of(x.type)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      x.from,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.suit(700, 15.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      keepAll(MyViewModel.receivedSub(tape, withDate: big)),
                      style: AppText.suit(
                        500,
                        12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (tape.boxed) ...[
                const SizedBox(width: 14),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              if (!big) ...[
                const SizedBox(width: 14),
                Text(
                  formatMonthDayTime(x.date),
                  style: AppText.suit(
                    600,
                    12.5,
                    color: AppColors.textFaint,
                    tabularNums: true,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 친구 행 58: 이름, ☆, ⋯ (margin 0 −12, padding 0 4 0 12)
class MyFriendRow extends StatelessWidget {
  const MyFriendRow({
    super.key,
    required this.friend,
    required this.onTap,
    required this.onStar,
    required this.onMore,
  });

  final Friend friend;
  final VoidCallback onTap;
  final VoidCallback onStar;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Row(
          children: [
            Expanded(
              child: FriendNameLine(
                friend: friend,
                style: AppText.suit(700, 15),
              ),
            ),
            Semantics(
              button: true,
              label: friend.starred ? '즐겨찾기 해제' : '즐겨찾기',
              excludeSemantics: true,
              child: Tappable(
                behavior: HitTestBehavior.opaque,
                onTap: onStar,
                child: SizedBox.square(
                  dimension: 40,
                  child: Center(
                    child: Text(
                      friend.starred ? '★' : '☆',
                      // 글자 모양 아이콘 — 큰 글씨에도 크기 고정 (v10.4)
                      textScaler: TextScaler.noScaling,
                      style: AppText.suit(
                        400,
                        19,
                        height: 1,
                        color: friend.starred
                            ? AppColors.star
                            : AppColors.disabled,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: '${friend.name} 더 보기',
              excludeSemantics: true,
              child: Tappable(
                behavior: HitTestBehavior.opaque,
                onTap: onMore,
                child: SizedBox(
                  width: 36,
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 3),
                        Container(
                          width: 3.5,
                          height: 3.5,
                          decoration: const BoxDecoration(
                            color: AppColors.textFaint,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 보낸 테이프 목록 (`mpSent`, v10) — 카드 배경 없이 받은 테이프 목록과 같은 형식.
class SentCard extends StatelessWidget {
  const SentCard({super.key, required this.vm, required this.onTap});

  final MyViewModel vm;
  final ValueChanged<SentTape> onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final s in vm.sent) SentRow(sent: s, onTap: () => onTap(s)),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          keepAll('보낸 테이프는 받은 사람만 들을 수 있어요'),
          style: AppText.suit(500, 12, height: 1.4, color: AppColors.textFaint),
        ),
      ),
    ],
  );
}

/// 보낸 테이프 행: 최소 60, 패딩 8 12(좌우 −12로 넓힘), radius 14, 간격 14.
/// 미니 테이프 48×32 · "{이름}에게 보냄" `700 15.5/1.3` 한 줄 말줄임 ·
/// [상태 점·상태] · MM.DD · 길이 (`500 12.5` `#9A9A97`, 좁으면 다음 줄) · ›
class SentRow extends StatelessWidget {
  const SentRow({super.key, required this.sent, required this.onTap});

  final SentTape sent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tappable(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          MiniTape(palette: TapePalette.of(sent.type)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  keepAll('${sent.to}에게 보냄'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.suit(700, 15.5, height: 1.3),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SentStatusLabel(
                      sent: sent,
                      text: MyViewModel.sentStatus(sent),
                    ),
                    Text(
                      MyViewModel.sentMeta(sent),
                      style: AppText.suit(
                        500,
                        12.5,
                        height: 1.35,
                        tabularNums: true,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '›',
            // 글자 모양 아이콘 — 큰 글씨에도 크기 고정 (v10.4)
            textScaler: TextScaler.noScaling,
            style: AppText.suit(400, 20, height: 1, color: AppColors.disabled),
          ),
        ],
      ),
    ),
  );
}

/// 설정 행 52 (`600 15px`)
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.label,
    this.onTap,
    this.trailing,
    this.color = AppColors.ink,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    child: Tappable(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: AppText.suit(600, 15, color: color)),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      ),
    ),
  );
}

class SettingValue extends StatelessWidget {
  const SettingValue(this.text, {super.key, this.tabular = false});

  final String text;
  final bool tabular;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppText.suit(
      500,
      13.5,
      color: AppColors.textMuted,
      tabularNums: tabular,
    ),
  );
}

class Chevron extends StatelessWidget {
  const Chevron({super.key});

  @override
  Widget build(BuildContext context) => Text(
    '›',
    // 글자 모양 아이콘 — 큰 글씨에도 크기 고정 (v10.4)
    textScaler: TextScaler.noScaling,
    style: AppText.suit(400, 20, height: 1, color: AppColors.disabled),
  );
}

/// 알림 토글 48×28 (켜짐 `#111`, 꺼짐 `#DADAD7`, 손잡이 22)
class SettingToggle extends StatelessWidget {
  const SettingToggle({super.key, required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    width: 48,
    height: 28,
    decoration: BoxDecoration(
      color: on ? AppColors.ink : AppColors.toggleOff,
      borderRadius: BorderRadius.circular(14),
    ),
    child: AnimatedAlign(
      duration: const Duration(milliseconds: 200),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 22,
        height: 22,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: AppColors.paper,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: .2),
              offset: const Offset(0, 1),
              blurRadius: 3,
            ),
          ],
        ),
      ),
    ),
  );
}
