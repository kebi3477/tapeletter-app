import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/tape_type.dart';
import '../../../domain/models/user.dart';
import '../../core/ui/text_limits.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/dimens.dart';
import '../../core/themes/tape_palette.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/credit_icon.dart';
import '../../core/ui/skeleton.dart';
import '../view_model/my_view_model.dart';
import 'my_page_screen.dart';
import 'my_sheets.dart';
import '../../core/ui/tappable.dart';

/// 마이 탭 홈 — 템플릿 `vMy` 블록. 이름, 크레딧, 아이콘 4개(`myMenu`), 보유 테이프.
/// 받은·보낸 테이프, 친구, 설정은 하위 화면([MyPageScreen])으로 간다.
class MyScreen extends StatefulWidget {
  const MyScreen({
    super.key,
    required this.viewModel,
    required this.onOpenHistory,
    required this.onGoShop,
    required this.onOpenPage,
    this.openSentId,
  });

  final MyViewModel viewModel;
  final VoidCallback onOpenHistory;
  final VoidCallback onGoShop;

  /// 아이콘 → 하위 화면 (`myPage`)
  final ValueChanged<MyPage> onOpenPage;

  /// 열자마자 상세를 띄울 보낸 테이프 (`/my?sent=`, "테이프를 받았어요" 푸시)
  final String? openSentId;

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  late final TextEditingController _name = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.viewModel.enter();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSent());
  }

  @override
  void didUpdateWidget(MyScreen old) {
    super.didUpdateWidget(old);
    if (widget.openSentId != old.openSentId) _openSent();
  }

  Future<void> _openSent() async {
    final id = widget.openSentId;
    if (id == null) return;
    final s = await widget.viewModel.sentById(id);
    if (s == null || !mounted) return;
    await showSentDetailSheet(
      context,
      sent: s,
      onReshare: () => widget.viewModel.reshare(s),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _startEdit() {
    final vm = widget.viewModel;
    vm.startEditName();
    _name.text = vm.nameDraft;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _nameFocus.requestFocus(),
    );
  }

  /// 저장 · Enter (`doneName`) — 비어 있으면 입력칸에 남는다
  Future<void> _done() async {
    await widget.viewModel.commitName();
    if (widget.viewModel.editingName && mounted) _nameFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) => Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              // 아이콘 줄의 margin 0 −6 때문에 18만 들이고 나머지는 6을 더 들인다.
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final w in [
                    SizedBox(
                      height: AppSizes.header,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('마이', style: AppText.screenTitle),
                      ),
                    ),
                    _nameBlock(vm),
                    _CreditRow(
                      credits: vm.credits,
                      onTap: widget.onOpenHistory,
                    ),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: w,
                    ),
                  const SizedBox(height: 16),
                  _Menu(vm: vm, onOpen: widget.onOpenPage),
                  for (final w in [
                    _SectionHeader(
                      title: '보유 테이프',
                      top: 18,
                      bottom: 12,
                      action: '상점 ›',
                      onAction: widget.onGoShop,
                    ),
                    _Drawer(vm: vm),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: w,
                    ),
                ],
              ),
            ),
          ),
          if (vm.skeleton)
            const Positioned(
              left: 0,
              right: 0,
              top: AppSizes.header,
              bottom: 0,
              child: _MySkeleton(),
            ),
        ],
      ),
    );
  }

  /// 이름(800 21) + "수정" / 고치는 중: 입력칸 + 취소 · 저장 (40 알약), 도움말에 글자 수
  Widget _nameBlock(MyViewModel vm) {
    const underline = UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.ink, width: 2),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: vm.editingName
                ? Row(
                    children: [
                      Expanded(
                        // Esc → 취소 (`nameKey`)
                        child: CallbackShortcuts(
                          bindings: {
                            const SingleActivator(LogicalKeyboardKey.escape):
                                vm.cancelEditName,
                          },
                          child: TextField(
                            controller: _name,
                            focusNode: _nameFocus,
                            onChanged: vm.setNameDraft,
                            onSubmitted: (_) => _done(), // Enter
                            style: AppText.suit(800, 21),
                            cursorColor: AppColors.ink,
                            inputFormatters: [
                              maxCharacters(User.maxNameLength),
                            ],
                            decoration: const InputDecoration(
                              isCollapsed: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 7),
                              enabledBorder: underline,
                              focusedBorder: underline,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _Pill(label: '취소', onTap: vm.cancelEditName),
                      const SizedBox(width: 6),
                      _Pill(label: '저장', dark: true, onTap: _done),
                    ],
                  )
                : Tappable(
                    behavior: HitTestBehavior.opaque,
                    onTap: _startEdit,
                    child: Row(
                      children: [
                        Text(vm.name, style: AppText.suit(800, 21)),
                        const SizedBox(width: 8),
                        Text(
                          '수정',
                          style: AppText.suit(
                            600,
                            12.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 2),
          Text(
            vm.nameHelp,
            style: AppText.caption.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// 40 높이 알약 (`#F3F3F1` / 저장은 `#111` 흰 글자)
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap, this.dark = false});

  final String label;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Tappable(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: dark ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppText.suit(
            700,
            13.5,
            color: dark ? AppColors.paper : AppColors.ink,
          ),
        ),
      ),
    ),
  );
}

/// 아이콘 4개 (`myMenu`) — 4열, gap 4. 좌우 margin −6은 부모가 6을 덜 들여 쓴다.
class _Menu extends StatelessWidget {
  const _Menu({required this.vm, required this.onOpen});

  final MyViewModel vm;
  final ValueChanged<MyPage> onOpen;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (i, p) in MyPage.values.indexed) ...[
        if (i > 0) const SizedBox(width: 4),
        Expanded(
          child: _MenuTile(
            page: p,
            count: vm.menuCount(p),
            dot: p == MyPage.recv && vm.hasNewReceived,
            onTap: () => onOpen(p),
          ),
        ),
      ],
    ],
  );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.page,
    required this.count,
    required this.dot,
    required this.onTap,
  });

  final MyPage page;
  final String count;
  final bool dot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: page.title,
    excludeSemantics: true,
    child: Tappable(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  Center(child: _MenuIcon(page)),
                  if (dot)
                    Positioned(
                      top: 6,
                      right: 6,
                      // 8 점 + box-shadow 0 0 0 2px #F6F6F4
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surfaceSoft,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(page.title, style: AppText.suit(700, 13)),
            const SizedBox(height: 2),
            SizedBox(
              height: 18,
              child: Text(
                count,
                style: AppText.suit(
                  600,
                  12.5,
                  color: AppColors.textMuted,
                  tabularNums: true,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 아이콘 (`i1`~`i4`) — 원본은 CSS 도형 (카세트 · 소포 · 사람 · 슬라이더)
class _MenuIcon extends StatelessWidget {
  const _MenuIcon(this.page);

  final MyPage page;

  static const _ink = AppColors.ink;

  static BoxDecoration _stroke({double w = 2, BorderRadius? r, Color? fill}) =>
      BoxDecoration(
        color: fill,
        border: Border.all(color: _ink, width: w),
        borderRadius: r,
      );

  @override
  Widget build(BuildContext context) => switch (page) {
    // 26×18 카세트: 테두리 2 radius 3, 가운데 6×6 릴 두 개 (gap 5)
    MyPage.recv => Container(
      width: 26,
      height: 18,
      decoration: _stroke(r: BorderRadius.circular(3)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: _stroke(w: 1.5).copyWith(shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Container(
            width: 6,
            height: 6,
            decoration: _stroke(w: 1.5).copyWith(shape: BoxShape.circle),
          ),
        ],
      ),
    ),
    // 24×20 소포: 몸통(top 4), 뚜껑(top 4, 높이 6, radius 3 3 0 0), 가운데 끈
    MyPage.sent => SizedBox(
      width: 24,
      height: 20,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 4,
            bottom: 0,
            child: DecoratedBox(
              decoration: _stroke(r: BorderRadius.circular(3)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 4,
            height: 6,
            child: DecoratedBox(
              decoration: _stroke(
                r: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ),
          ),
          const Positioned(
            left: 11,
            width: 2,
            top: 0,
            height: 10,
            child: ColoredBox(color: _ink),
          ),
        ],
      ),
    ),
    // 22×22 사람 (탭바 마이 아이콘과 같은 모양)
    MyPage.friends => SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        children: [
          Positioned(
            left: 6,
            top: 1,
            width: 10,
            height: 10,
            child: DecoratedBox(
              decoration: _stroke().copyWith(shape: BoxShape.circle),
            ),
          ),
          Positioned(
            left: 2,
            right: 2,
            bottom: 1,
            height: 8,
            child: CustomPaint(painter: _ShouldersPainter()),
          ),
        ],
      ),
    ),
    // 22×18 슬라이더: 선 3개(top 2 · 8 · 14) + 손잡이 3개
    MyPage.settings => SizedBox(
      width: 22,
      height: 18,
      child: Stack(
        children: [
          for (final t in const [2.0, 8.0, 14.0])
            Positioned(
              left: 0,
              right: 0,
              top: t,
              height: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _ink,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          for (final (l, t) in const [(4.0, 0.0), (12.0, 6.0), (6.0, 12.0)])
            Positioned(
              left: l,
              top: t,
              width: 6,
              height: 6,
              child: DecoratedBox(
                decoration: _stroke(fill: AppColors.surfaceSoft)
                    .copyWith(shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    ),
  };
}

/// 어깨: 테두리 2, 아래 테두리 없음, radius 9 9 0 0
class _ShouldersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const w = 2.0;
    final r = size.height.clamp(0, 9).toDouble();
    final path = Path()
      ..moveTo(w / 2, size.height)
      ..lineTo(w / 2, r)
      ..arcToPoint(Offset(r, w / 2), radius: Radius.circular(r - w / 2))
      ..lineTo(size.width - r, w / 2)
      ..arcToPoint(
        Offset(size.width - w / 2, r),
        radius: Radius.circular(r - w / 2),
      )
      ..lineTo(size.width - w / 2, size.height);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = w,
    );
  }

  @override
  bool shouldRepaint(_ShouldersPainter old) => false;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.top,
    required this.bottom,
    this.action,
    this.onAction,
  });

  final String title;
  final double top;
  final double bottom;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top, bottom: bottom),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppText.suit(800, 16)),
        if (action != null)
          Tappable(
            onTap: onAction,
            child: Text(
              action!,
              style: AppText.suit(600, 13, color: AppColors.textMuted),
            ),
          ),
      ],
    ),
  );
}

/// 크레딧 행 56 (`#F6F6F4` radius 16)
class _CreditRow extends StatelessWidget {
  const _CreditRow({required this.credits, required this.onTap});

  final int credits;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tappable(
    onTap: onTap,
    child: Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        children: [
          const CreditIcon(size: 24),
          const SizedBox(width: 10),
          Expanded(child: Text('크레딧', style: AppText.suit(600, 14.5))),
          Text('$credits', style: AppText.suit(800, 16, tabularNums: true)),
          const SizedBox(width: 10),
          const Chevron(),
        ],
      ),
    ),
  );
}

/// 보유 테이프 3칸 (15초 "무료", 1·3분 "N개", 0이면 레드·테이프 opacity .4)
class _Drawer extends StatelessWidget {
  const _Drawer({required this.vm});

  final MyViewModel vm;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (i, t) in TapeType.values.indexed) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: _DrawerCard(type: t, owned: vm.ownedOf(t)),
        ),
      ],
    ],
  );
}

class _DrawerCard extends StatelessWidget {
  const _DrawerCard({required this.type, required this.owned});

  final TapeType type;
  final int owned;

  @override
  Widget build(BuildContext context) {
    final p = TapePalette.of(type);
    final zero = !type.isUnlimited && owned <= 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Column(
        children: [
          Opacity(
            opacity: zero ? .4 : 1,
            child: _BigMiniTape(palette: p),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: AppText.suit(700, 13),
              children: [
                TextSpan(text: '${p.name} '),
                TextSpan(
                  text: type.isUnlimited ? '무료' : '$owned개',
                  style: TextStyle(
                    color: zero ? AppColors.red : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 보유 테이프 카드의 56×36 미니 테이프
class _BigMiniTape extends StatelessWidget {
  const _BigMiniTape({required this.palette});

  final TapePalette palette;

  @override
  Widget build(BuildContext context) => Container(
    width: 56,
    height: 36,
    decoration: BoxDecoration(
      color: palette.shell,
      borderRadius: BorderRadius.circular(4),
      boxShadow: [
        BoxShadow(
          color: AppColors.black.withValues(alpha: .25),
          offset: const Offset(0, 1),
          blurRadius: 2,
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          left: 3,
          right: 3,
          top: 3,
          height: 19,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Column(
              children: [
                Container(height: 5, color: palette.band),
                const Expanded(child: ColoredBox(color: AppColors.labelPaper)),
              ],
            ),
          ),
        ),
        Positioned(
          left: 15,
          right: 15,
          top: 11,
          height: 9,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: TapeInk.hubCore,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 0,
          height: 8,
          child: ClipPath(
            clipper: _Trapezoid(),
            child: ColoredBox(color: AppColors.black.withValues(alpha: .2)),
          ),
        ),
      ],
    ),
  );
}

class _Trapezoid extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(s.width * .1, 0)
    ..lineTo(s.width * .9, 0)
    ..lineTo(s.width, s.height)
    ..lineTo(0, s.height)
    ..close();

  @override
  bool shouldReclip(_Trapezoid old) => false;
}

/// 마이 스켈레톤 (`skMy`)
class _MySkeleton extends StatelessWidget {
  const _MySkeleton();

  @override
  Widget build(BuildContext context) {
    Widget row() => const SkeletonPulse(
      child: SizedBox(
        height: 58,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SkeletonBar(width: 72, height: 14),
            SkeletonBar(width: 20, height: 20, light: true, radius: 10),
          ],
        ),
      ),
    );
    return ColoredBox(
      color: AppColors.paper,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonPulse(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBar(width: 120, height: 22),
                  SizedBox(height: 26),
                  SkeletonBar(
                    width: double.infinity,
                    height: 56,
                    light: true,
                    radius: 16,
                  ),
                  SizedBox(height: 26),
                  SkeletonBar(width: 50, height: 16),
                ],
              ),
            ),
            row(),
            row(),
            row(),
            row(),
          ],
        ),
      ),
    );
  }
}
