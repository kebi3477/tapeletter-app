import 'package:flutter/material.dart';

import '../../../domain/models/user.dart';
import '../../core/ui/text_limits.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/animations.dart';
import '../../core/ui/buttons.dart';
import '../../core/ui/tape_widget.dart';
import '../view_model/name_view_model.dart';

/// 이름 정하기 (`auName`)
class NameScreen extends StatefulWidget {
  const NameScreen({super.key, required this.viewModel});

  final NameViewModel viewModel;

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  late final TextEditingController _c = TextEditingController(
    text: widget.viewModel.name,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    const underline = UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.ink, width: 2),
    );
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: SlideUp(
          child: ListenableBuilder(
            listenable: vm,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BackBar(onBack: vm.back),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                  child: Text('테이프에 적힐\n이름을 알려주세요', style: AppText.bigTitle),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Text(
                    '친구에게 보이는 이름이에요 · 최대 8자',
                    style: AppText.suit(
                      500,
                      14,
                      height: 1.5,
                      color: AppColors.textSub,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      clipBehavior: Clip.none,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TapeWidget(from: vm.preview),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: 280,
                            height: 52,
                            child: TextField(
                              controller: _c,
                              onChanged: vm.setName,
                              textAlign: TextAlign.center,
                              style: AppText.suit(700, 20),
                              cursorColor: AppColors.ink,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => vm.submit(),
                              inputFormatters: [
                                maxCharacters(User.maxNameLength),
                              ],
                              decoration: InputDecoration(
                                hintText: '이름',
                                hintStyle: AppText.suit(
                                  700,
                                  20,
                                  color: AppColors.textFaint,
                                ),
                                isCollapsed: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                enabledBorder: underline,
                                focusedBorder: underline,
                              ),
                            ),
                          ),
                          // gap 28 − margin-top 18
                          const SizedBox(height: 10),
                          Text(
                            '${vm.length}/${User.maxNameLength}',
                            style: AppText.suit(
                              600,
                              12.5,
                              tabularNums: true,
                              color: vm.atMax
                                  ? AppColors.red
                                  : AppColors.textFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, bottomSafe(context)),
                  child: AppButton(
                    label: '시작하기',
                    background: vm.canSubmit
                        ? AppColors.ink
                        : AppColors.disabled,
                    onTap: vm.submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
