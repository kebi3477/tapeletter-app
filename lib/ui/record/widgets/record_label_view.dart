import 'package:flutter/material.dart';

import '../../../domain/models/user.dart';
import '../../core/ui/text_limits.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/tape_palette.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/animations.dart';
import '../../core/ui/buttons.dart';
import '../../core/ui/tape_widget.dart';
import '../view_model/record_view_model.dart';
import '../../core/ui/keep_all.dart';

/// 녹음 · 라벨 — 템플릿 `vLabel` 블록.
///
/// 기존 친구면 이름이 110ms에 한 글자씩 라벨 카드에 타이핑된다.
/// 새 친구면 입력칸(최대 8자)을 보여준다.
class RecordLabelView extends StatefulWidget {
  const RecordLabelView({super.key, required this.viewModel});

  final RecordViewModel viewModel;

  @override
  State<RecordLabelView> createState() => _RecordLabelViewState();
}

class _RecordLabelViewState extends State<RecordLabelView> {
  late final TextEditingController _name = TextEditingController(
    text: widget.viewModel.newName,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final palette = TapePalette.of(vm.tape);
    final isNew = vm.to?.isNew ?? false;
    return SlideUp(
      child: Column(
        children: [
          BackBar(onBack: vm.backPick),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                // 라벨 카드는 테이프 위로 22px 삐져나온다.
                clipBehavior: Clip.none,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TapeWidget(
                      palette: palette,
                      packL: palette.packFull,
                      packR: TapePalette.packEmpty,
                      from: vm.myName,
                      to: vm.typedName,
                    ),
                    if (isNew) ...[
                      const SizedBox(height: 34),
                      _NewNameField(vm: vm, controller: _name),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, bottomSafe(context)),
            child: AppButton(
              label: '보내기',
              background: vm.canSend ? AppColors.ink : AppColors.disabled,
              onTap: vm.sendNow,
            ),
          ),
        ],
      ),
    );
  }
}

/// 글자(grapheme) 수로 자르는 입력 제한. 한글 조합 중에는 자르지 않는다.
/// 새 친구 이름 (`isNewTo`, v3) — 선택 입력, 최대 8자. 비우면 "새 친구"로 적힌다.
class _NewNameField extends StatelessWidget {
  const _NewNameField({required this.vm, required this.controller});

  final RecordViewModel vm;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final n = vm.newName.characters.length;
    final underline = const UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.ink, width: 2),
    );
    return SizedBox(
      width: 280,
      child: Column(
        children: [
          Text(
            keepAll('받는 사람 이름 (선택)'),
            style: AppText.suit(600, 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: TextField(
              controller: controller,
              onChanged: vm.setNewName,
              textAlign: TextAlign.center,
              style: AppText.suit(700, 20),
              cursorColor: AppColors.ink,
              inputFormatters: [maxCharacters(User.maxNameLength)],
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: keepAll('예) 지현, 동생'),
                hintStyle: AppText.suit(700, 20, color: AppColors.textFaint),
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
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
                  keepAll('누구에게 보냈는지 알아보는 이름이에요. 비우면 ‘새 친구’로 적혀요'),
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
                '$n/${User.maxNameLength}',
                style: AppText.suit(
                  600,
                  12.5,
                  height: 1.5,
                  tabularNums: true,
                  color: n >= User.maxNameLength
                      ? AppColors.red
                      : AppColors.textFaint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
