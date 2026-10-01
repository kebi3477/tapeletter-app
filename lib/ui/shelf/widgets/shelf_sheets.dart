import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/report.dart';
import '../../../domain/models/shelf.dart';
import '../../../domain/models/tape_item.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/app_sheet.dart';
import '../../core/ui/buttons.dart';
import '../../core/ui/choice_chip.dart';
import '../../../utils/format.dart';
import '../../report/widgets/report_sheet.dart';
import '../view_model/shelf_view_model.dart';
import '../../core/ui/tappable.dart';

/// 받은 테이프 신고 — 보낸 사람을 차단 대상으로 (`report({target: 'tape'})`)
TapeReport tapeReportOf(TapeItem item) => TapeReport(
  deliveryId: item.id,
  name: item.from,
  userId: item.senderId,
  date: formatMonthDayTime(item.date),
);

/// ⋯ 메뉴 (`shItem`): 답장 녹음하기 / 메모 남기기 / 다른 칸으로 옮기기 / 신고하기 / 지우기.
/// 서랍 목록과 재생 화면(`vMore`, [inViewer])이 같은 메뉴를 쓴다 (`itemFull: true`).
/// - 부제: 목록은 `날짜 시:분 · 칸`, 재생 화면은 `where: ''`라 `날짜 시:분`만
/// - 메모가 있으면 부제 아래 메모 카드(탭하면 수정), 메뉴 이름은 "메모 수정하기"
/// - 메모 시트(`shMemo`)에서 저장하거나 지우면 목록은 메뉴로 돌아오고 재생 화면은 닫는다.
///   재생 화면은 [onMemo]로 라벨을 바로 바꾼다
/// - 재생 화면에서 옮기거나 지우면 재생을 닫는다 ([onLeave], `closeViewer`)
/// - 지우기는 확인(`shDelConfirm`)을 거친다. 취소하면 메뉴로 돌아온다
Future<void> showItemSheet(
  BuildContext context, {
  required ShelfViewModel viewModel,
  required TapeItem item,
  required VoidCallback? onReply,
  bool inViewer = false,
  VoidCallback? onLeave,
  ValueChanged<String?>? onMemo,
}) {
  return showAppSheet<void>(
    context,
    builder: (sheet) => _ItemMenu(
      outer: context,
      sheet: sheet,
      viewModel: viewModel,
      item: item,
      onReply: onReply,
      inViewer: inViewer,
      onLeave: onLeave,
      onMemo: onMemo,
    ),
  );
}

class _ItemMenu extends StatefulWidget {
  const _ItemMenu({
    required this.outer,
    required this.sheet,
    required this.viewModel,
    required this.item,
    required this.onReply,
    required this.inViewer,
    required this.onLeave,
    required this.onMemo,
  });

  final BuildContext outer;
  final BuildContext sheet;
  final ShelfViewModel viewModel;
  final TapeItem item;
  final VoidCallback? onReply;
  final bool inViewer;
  final VoidCallback? onLeave;
  final ValueChanged<String?>? onMemo;

  @override
  State<_ItemMenu> createState() => _ItemMenuState();
}

enum _ItemPage { menu, memo, deleteConfirm }

class _ItemMenuState extends State<_ItemMenu> {
  _ItemPage _page = _ItemPage.menu;

  /// 지금 메모. 메모 시트에서 저장하면 메뉴로 돌아와 바로 보인다.
  late String? _memo = widget.item.memo;

  void _close() => Navigator.of(widget.sheet).pop();

  @override
  Widget build(BuildContext context) => switch (_page) {
    _ItemPage.menu => _menu(),
    _ItemPage.memo => _MemoForm(
      from: widget.item.from,
      memo: _memo,
      onSave: _saveMemo,
    ),
    _ItemPage.deleteConfirm => _deleteConfirm(),
  };

  /// 저장 (`mmSave`) · 지우기 (`mmDel`, 빈 문자열). 목록은 메뉴로, 재생 화면은 닫는다.
  /// 재생 화면 라벨은 먼저 바꾸고, 서버가 거절하면 되돌린다.
  void _saveMemo(String draft) {
    final memo = draft.trim().isEmpty ? null : draft.trim();
    final prev = _memo;
    final onMemo = widget.onMemo;
    onMemo?.call(memo);
    widget.viewModel
        .setMemo(widget.item.copyWith(memo: () => prev), draft)
        .then((ok) {
          if (!ok) onMemo?.call(prev);
        });
    if (widget.inViewer) {
      _close();
    } else {
      setState(() {
        _memo = memo;
        _page = _ItemPage.menu;
      });
    }
  }

  Widget _menu() {
    final item = widget.item;
    final memo = _memo;
    final vm = widget.viewModel;
    final onReply = widget.onReply;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(item.from, style: AppText.sheetTitle),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 10),
          child: Text(
            widget.inViewer ? formatMonthDayTime(item.date) : vm.sheetSub(item),
            style: AppText.suit(500, 13.5, color: AppColors.textMuted),
          ),
        ),
        // 메모 카드 (`itemHasMemo`) — 탭하면 수정
        if (memo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Tappable(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _page = _ItemPage.memo),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.memoPaper,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.memoStroke),
                ),
                child: Text(
                  memo,
                  style: AppText.suit(
                    600,
                    14.5,
                    height: 1.5,
                    color: AppColors.memoInk,
                  ),
                ),
              ),
            ),
          ),
        // 보낸 사람이 탈퇴했으면(senderId 없음) 답장할 수 없다.
        if (onReply != null)
          SheetRow(
            label: '답장 녹음하기',
            onTap: () {
              _close();
              onReply();
            },
          ),
        SheetRow(
          label: memo == null ? '메모 남기기' : '메모 수정하기',
          onTap: () => setState(() => _page = _ItemPage.memo),
        ),
        // 안 뜯은 소포는 옮길 수 없다 (계약서 409).
        if (vm.canMove(item))
          SheetRow(
            label: '다른 칸으로 옮기기',
            onTap: () {
              _close();
              showMoveSheet(
                widget.outer,
                viewModel: vm,
                item: item,
                onMoved: widget.onLeave,
              );
            },
          ),
        SheetRow(
          label: '신고하기',
          onTap: () {
            _close();
            showReportSheet(widget.outer, target: tapeReportOf(item));
          },
        ),
        SheetRow(
          label: '지우기',
          danger: true,
          divider: false,
          onTap: () => setState(() => _page = _ItemPage.deleteConfirm),
        ),
      ],
    );
  }

  /// 테이프를 지울까요? (`shDelConfirm`) — 취소 · 지우기 (52, radius 14, 간격 8)
  Widget _deleteConfirm() {
    Widget button(String label, Color bg, Color fg, VoidCallback onTap) =>
        Expanded(
          child: AppButton(
            label: label,
            background: bg,
            foreground: fg,
            height: 52,
            radius: 14,
            onTap: onTap,
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('테이프를 지울까요?', style: AppText.suit(800, 20, letterSpacingEm: -.02)),
        const SizedBox(height: 6),
        Text(
          '${widget.item.from}님이 보낸 테이프가 서랍에서 사라져요. 지운 테이프는 되돌릴 수 없어요.',
          style: AppText.suit(
            500,
            14,
            height: 1.55,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 6 + 18),
        Row(
          children: [
            button(
              '취소',
              AppColors.surface,
              AppColors.ink,
              () => setState(() => _page = _ItemPage.menu),
            ),
            const SizedBox(width: 8),
            button('지우기', AppColors.red, AppColors.paper, () {
              _close();
              widget.onLeave?.call();
              widget.viewModel.deleteItem(widget.item.id);
            }),
          ],
        ),
      ],
    );
  }
}

/// 테이프 메모 (`shMemo`) — 나에게만 보이는 메모. 최대 40자, 40자에 닿으면 카운터가 빨강.
/// 지우기는 메모가 있을 때만 (`mmCanDel`). [onSave]에 빈 문자열을 넘기면 지운다.
class _MemoForm extends StatefulWidget {
  const _MemoForm({
    required this.from,
    required this.memo,
    required this.onSave,
  });

  final String from;
  final String? memo;
  final ValueChanged<String> onSave;

  @override
  State<_MemoForm> createState() => _MemoFormState();
}

class _MemoFormState extends State<_MemoForm> {
  late final TextEditingController _draft = TextEditingController(
    text: widget.memo ?? '',
  )..addListener(() => setState(() {}));

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = _draft.text.characters.length;
    const max = ShelfViewModel.memoMax;
    final box = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.memoStroke),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('테이프 메모', style: AppText.suit(800, 20, letterSpacingEm: -.01)),
        const SizedBox(height: 6),
        Text(
          '${widget.from}님의 테이프 · 나에게만 보여요',
          style: AppText.suit(500, 14, height: 1.55, color: AppColors.textSub),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _draft,
          autofocus: true,
          minLines: 3,
          maxLines: 3,
          style: AppText.suit(600, 16, height: 1.55),
          cursorColor: AppColors.ink,
          // 한 줄 메모 (계약서: 줄바꿈 안 됨) — 칸 너비에서만 줄이 넘어간다
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'[\r\n]')),
            LengthLimitingTextInputFormatter(
              max,
              maxLengthEnforcement:
                  MaxLengthEnforcement.truncateAfterCompositionEnds,
            ),
          ],
          decoration: InputDecoration(
            hintText: '이 테이프를 받은 날, 기억하고 싶은 것',
            hintStyle: AppText.suit(
              600,
              16,
              height: 1.55,
              color: AppColors.textFaint,
            ),
            filled: true,
            fillColor: AppColors.memoPaper,
            isCollapsed: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: box,
            focusedBorder: box,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '테이프 라벨에도 적혀요',
                style: AppText.suit(
                  500,
                  12.5,
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$n/$max',
              style: AppText.suit(
                600,
                12.5,
                height: 1.5,
                tabularNums: true,
                color: n >= max ? AppColors.red : AppColors.textFaint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            if (widget.memo != null) ...[
              SizedBox(
                width: 96,
                child: AppButton(
                  label: '지우기',
                  background: AppColors.surface,
                  foreground: AppColors.red,
                  onTap: () => widget.onSave(''),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: AppButton(
                label: '저장',
                onTap: () => widget.onSave(_draft.text),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 옮기기 (`shMove`): 어느 칸으로 옮길까요?
Future<void> showMoveSheet(
  BuildContext context, {
  required ShelfViewModel viewModel,
  required TapeItem item,
  VoidCallback? onMoved,
}) {
  final s = viewModel.shelf;
  return showAppSheet<void>(
    context,
    builder: (sheet) {
      void go(String? groupId) {
        Navigator.of(sheet).pop();
        onMoved?.call();
        viewModel.moveTo(item.id, groupId);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('어느 칸으로 옮길까요?', style: AppText.sheetTitle),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text(
              '한 칸에 테이프를 10개까지 넣을 수 있어요',
              style: AppText.suit(500, 13.5, color: AppColors.textSub),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SheetRow(
                    label: ShelfViewModel.unsortedName,
                    trailing: '${s.unsorted.length}개',
                    trailingStyle: _moveCount(AppColors.textCount),
                    onTap: () => go(null),
                  ),
                  // 꽉 찬 칸: 이름 `#B5B5B2`, 개수 레드 "꽉 참 10/10".
                  // 누르면 안내 토스트만 (그 칸에 이미 있으면 맨 뒤로 옮긴다)
                  for (final g in s.groups)
                    SheetRow(
                      label: g.name,
                      labelColor: viewModel.groupFull(g)
                          ? AppColors.textFaint
                          : null,
                      trailing: viewModel.moveCountText(g),
                      trailingStyle: _moveCount(
                        viewModel.groupFull(g)
                            ? AppColors.red
                            : AppColors.textCount,
                      ),
                      onTap: () => viewModel.hasRoom(item, g.id)
                          ? go(g.id)
                          : viewModel.toast(ShelfViewModel.groupFullMessage),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// 옮기기 시트 개수 `700 13px` tabular
TextStyle _moveCount(Color color) =>
    AppText.suit(700, 13, tabularNums: true, color: color);

/// 칸 추가·수정 (`shGroup`). [group]이 있으면 이름 바꾸기 + 칸 삭제.
Future<void> showGroupSheet(
  BuildContext context, {
  required ShelfViewModel viewModel,
  ShelfGroup? group,
}) {
  return showAppSheet<void>(
    context,
    builder: (sheet) => _GroupForm(viewModel: viewModel, group: group),
  );
}

class _GroupForm extends StatefulWidget {
  const _GroupForm({required this.viewModel, this.group});

  final ShelfViewModel viewModel;
  final ShelfGroup? group;

  @override
  State<_GroupForm> createState() => _GroupFormState();
}

class _GroupFormState extends State<_GroupForm> {
  late final TextEditingController _draft = TextEditingController(
    text: widget.group?.name ?? '',
  )..addListener(() => setState(() {}));
  final FocusNode _focus = FocusNode();

  /// 고른 카테고리 (`sh.cat`)
  String? _cat;

  /// 카테고리 칩 → 예시 이름 (`CAT_EX`). "직접 입력"은 비우고 입력칸에 포커스.
  static const categories = {
    '사람': '엄마 목소리',
    '기념일': '2026 생일',
    '여행': '제주 여행',
    '일상': '출근길 인사',
    '가족': '우리 가족',
    '연인': '우리의 100일',
    '직접 입력': '',
  };

  @override
  void dispose() {
    _draft.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _pickCategory(String c) {
    setState(() => _cat = c);
    final text = categories[c]!;
    _draft.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    if (c == '직접 입력') _focus.requestFocus();
  }

  void _save() {
    final name = _draft.text.trim();
    if (name.isEmpty) {
      widget.viewModel.toast('칸 이름을 적어 주세요');
      return;
    }
    final g = widget.group;
    Navigator.of(context).pop();
    if (g == null) {
      widget.viewModel.addGroup(name);
    } else {
      widget.viewModel.renameGroup(g.id, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final n = _draft.text.characters.length;
    final max = ShelfViewModel.groupNameMax;
    const underline = UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.ink, width: 2),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 칸 만들기 (`groupNew`): 카테고리 칩
        if (g == null) ...[
          Text(
            '이 칸에 어떤 목소리를 모을까요?',
            style: AppText.suit(800, 20, letterSpacingEm: -.01),
          ),
          const SizedBox(height: 6),
          Text(
            '사람, 순간, 주제별로 모아 두면 오래 간직할 수 있어요\n'
            '한 칸에 테이프를 10개까지 넣을 수 있어요',
            style: AppText.suit(500, 14, height: 1.5, color: AppColors.textSub),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in categories.keys)
                AppChoiceChip(
                  label: c,
                  selected: _cat == c,
                  onTap: () => _pickCategory(c),
                ),
            ],
          ),
          const SizedBox(height: 22),
        ],
        Text('칸 이름', style: AppText.suit(600, 13, color: AppColors.textMuted)),
        SizedBox(
          height: 52,
          child: TextField(
            controller: _draft,
            focusNode: _focus,
            style: AppText.suit(800, 22),
            cursorColor: AppColors.ink,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            inputFormatters: [
              LengthLimitingTextInputFormatter(
                max,
                maxLengthEnforcement:
                    MaxLengthEnforcement.truncateAfterCompositionEnds,
              ),
            ],
            decoration: InputDecoration(
              hintText: '칸 이름을 적어 주세요',
              hintStyle: AppText.suit(800, 22, color: AppColors.textFaint),
              isCollapsed: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              enabledBorder: underline,
              focusedBorder: underline,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '예) 2026 생일, 제주 여행, 엄마 목소리, 힘들 때 듣기',
                style: AppText.suit(
                  500,
                  12.5,
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$n/$max',
              style: AppText.suit(
                600,
                12.5,
                height: 1.5,
                tabularNums: true,
                color: n >= max ? AppColors.red : AppColors.textFaint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // 이름이 없으면 비활성 (`groupBg` #CFCFCC, background .2s)
        AppButton(
          label: g == null ? '칸 만들기' : '저장',
          background: _draft.text.trim().isEmpty
              ? AppColors.disabled
              : AppColors.ink,
          onTap: _save,
        ),
        if (g != null)
          Semantics(
            button: true,
            child: Tappable(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(context).pop();
                widget.viewModel.deleteGroup(g.id);
              },
              child: SizedBox(
                height: 48,
                child: Center(
                  child: Text(
                    '칸 삭제',
                    style: AppText.suit(600, 14, color: AppColors.red),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
