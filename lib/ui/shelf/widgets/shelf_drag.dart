import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/tape_item.dart';
import '../view_model/shelf_view_model.dart';
import '../../core/ui/tappable.dart';

/// 드래그 정렬의 화면 쪽 처리 — logic.js `rowDown`, `dragMove`, `relY`.
///
/// 드롭할 수 있는 곳(행·칸 제목·빈 칸, 템플릿의 `data-drop`)이 [DropZone]으로 등록되고,
/// 손가락 위치로 [ShelfViewModel.dragOver]에 넘길 [DropTarget]을 계산한다.
class ShelfDragController extends ChangeNotifier {
  ShelfDragController({required this.viewModel, required this.scroll});

  /// 터치: 이만큼 누르고 있으면 드래그 시작 (그 전에 움직이면 스크롤)
  static const holdTime = Duration(milliseconds: 380);

  /// 마우스: 이만큼 움직이면 드래그 시작
  static const double mouseSlop = 6;

  /// 목록 끝에서 이 안으로 들어오면 자동 스크롤
  static const double edge = 56;

  /// 자동 스크롤 한 번에 움직이는 양
  static const double scrollStep = 12;

  final ShelfViewModel viewModel;
  final ScrollController scroll;

  /// 고스트 카드 기준 영역(서랍 본문)과 스크롤 영역
  final GlobalKey areaKey = GlobalKey();
  final GlobalKey viewportKey = GlobalKey();

  final Map<Object, _Zone> _zones = {};

  TapeItem? _item;

  /// 고스트 카드 위치 (영역 위에서 `y − 30`)
  double? _ghostY;

  TapeItem? get ghostItem => _item;
  double? get ghostY => _ghostY;

  /// 손가락 위치 (드래그 영역 기준) — 책꽂이 고스트(테이프 등)는 손가락 가운데에 둔다
  Offset? get ghostAt => _ghostAt;
  Offset? _ghostAt;

  void register(
    Object owner,
    GlobalKey key,
    DropTarget target,
    bool row, {
    bool col = false,
  }) => _zones[owner] = _Zone(key, target, row, col);

  void unregister(Object owner) => _zones.remove(owner);

  void start(TapeItem item, Offset global) {
    viewModel.startDrag(item.id);
    if (!viewModel.dragging) return;
    // 길게 눌러 집어 들었다
    Haptic.medium.fire();
    _item = item;
    move(global);
  }

  void move(Offset global) {
    if (_item == null) return;
    viewModel.dragOver(_hit(global));
    _autoScroll(global.dy);
    final area = _rect(areaKey);
    if (area != null) {
      _ghostY = global.dy - area.top - 30;
      _ghostAt = global - area.topLeft;
      notifyListeners();
    }
  }

  Future<void> end() async {
    if (_item == null) return;
    _item = null;
    _ghostY = null;
    _ghostAt = null;
    notifyListeners();
    await viewModel.endDrag();
  }

  void cancel() {
    if (_item == null) return;
    _item = null;
    _ghostY = null;
    _ghostAt = null;
    notifyListeners();
    viewModel.cancelDrag();
  }

  /// 행 위쪽 절반이면 그 앞, 아래쪽 절반이면 그 뒤. 책꽂이(`data-col`)는 왼쪽·오른쪽 절반.
  /// 칸 제목·빈 칸이면 그 칸 맨 앞, 선반 전체(`dropEnd`)면 맨 뒤.
  /// 겹치면 가장 안쪽(작은) 영역이 이긴다 (`elementFromPoint(...).closest('[data-drop]')`).
  DropTarget? _hit(Offset p) {
    _Zone? best;
    Rect? bestRect;
    for (final z in _zones.values) {
      final r = _rect(z.key);
      if (r == null || !r.contains(p)) continue;
      if (bestRect == null ||
          r.width * r.height < bestRect.width * bestRect.height) {
        best = z;
        bestRect = r;
      }
    }
    if (best == null || bestRect == null) return null;
    var idx = best.target.index;
    if (best.row && p.dy > bestRect.top + bestRect.height / 2) idx++;
    if (best.col && p.dx > bestRect.left + bestRect.width / 2) idx++;
    return DropTarget(best.target.groupId, idx);
  }

  void _autoScroll(double y) {
    final v = _rect(viewportKey);
    if (v == null || !scroll.hasClients) return;
    final pos = scroll.position;
    double? to;
    if (y > v.bottom - edge) {
      to = pos.pixels + scrollStep;
    } else if (y < v.top + edge) {
      to = pos.pixels - scrollStep;
    }
    if (to != null) {
      scroll.jumpTo(to.clamp(pos.minScrollExtent, pos.maxScrollExtent));
    }
  }

  static Rect? _rect(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

class _Zone {
  _Zone(this.key, this.target, this.row, this.col);

  final GlobalKey key;
  final DropTarget target;
  final bool row;
  final bool col;
}

/// 템플릿의 `data-drop="gi:idx"` (+ `data-row`).
class DropZone extends StatefulWidget {
  const DropZone({
    super.key,
    required this.controller,
    required this.target,
    this.row = false,
    this.col = false,
    required this.child,
  });

  final ShelfDragController controller;
  final DropTarget target;
  final bool row;

  /// 책꽂이 가로 배치 — x 좌표로 앞·뒤 (`data-col`)
  final bool col;
  final Widget child;

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  final GlobalKey _key = GlobalKey();

  void _register() => widget.controller.register(
    this,
    _key,
    widget.target,
    widget.row,
    col: widget.col,
  );

  @override
  void initState() {
    super.initState();
    _register();
  }

  @override
  void didUpdateWidget(DropZone old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) old.controller.unregister(this);
    _register();
  }

  @override
  void dispose() {
    widget.controller.unregister(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}

/// 목록 행의 제스처: 짧게 탭하면 재생, 380ms 누르면(마우스는 6px 움직이면) 드래그.
class DragRowGestures extends StatefulWidget {
  const DragRowGestures({
    super.key,
    required this.controller,
    required this.item,
    required this.onTap,
    required this.child,
  });

  final ShelfDragController controller;
  final TapeItem item;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<DragRowGestures> createState() => _DragRowGesturesState();
}

class _DragRowGesturesState extends State<DragRowGestures> {
  Offset? _mouseDown;
  bool _mouseDragging = false;
  bool _dragged = false;

  ShelfDragController get _c => widget.controller;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        _dragged = false;
        if (e.kind == PointerDeviceKind.mouse) {
          _mouseDown = e.position;
          _mouseDragging = false;
        }
      },
      onPointerMove: (e) {
        if (e.kind != PointerDeviceKind.mouse || _mouseDown == null) return;
        if (!_mouseDragging) {
          if ((e.position - _mouseDown!).distance <=
              ShelfDragController.mouseSlop) {
            return;
          }
          _mouseDragging = true;
          _dragged = true;
          _c.start(widget.item, e.position);
          return;
        }
        _c.move(e.position);
      },
      onPointerUp: (e) {
        if (_mouseDragging) _c.end();
        _mouseDown = null;
        _mouseDragging = false;
      },
      onPointerCancel: (e) {
        if (_mouseDragging) _c.cancel();
        _mouseDown = null;
        _mouseDragging = false;
      },
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          TapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                TapGestureRecognizer.new,
                (r) {
                  r.onTap = () {
                    if (!_dragged) Haptic.selection.wrap(widget.onTap)!();
                  };
                },
              ),
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(
                  duration: ShelfDragController.holdTime,
                  supportedDevices: const {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.stylus,
                    PointerDeviceKind.invertedStylus,
                  },
                ),
                (r) {
                  r.onLongPressStart = (d) {
                    _dragged = true;
                    _c.start(widget.item, d.globalPosition);
                  };
                  r.onLongPressMoveUpdate = (d) => _c.move(d.globalPosition);
                  r.onLongPressEnd = (_) => _c.end();
                  r.onLongPressCancel = _c.cancel;
                },
              ),
        },
        child: widget.child,
      ),
    );
  }
}
