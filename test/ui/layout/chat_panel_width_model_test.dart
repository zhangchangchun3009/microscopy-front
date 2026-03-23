import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/layout/chat_panel_width_model.dart';

void main() {
  group('ChatPanelWidthModel', () {
    test('默认 factor=0.30', () {
      final model = ChatPanelWidthModel();

      expect(model.currentFactor, 0.30);
      expect(model.lastExpandedFactor, 0.30);
      expect(model.collapsed, isFalse);
    });

    test('拖拽增宽时上限不超过0.50', () {
      final model = ChatPanelWidthModel();

      model.applyDrag(windowWidth: 1000, deltaDx: -600);

      expect(model.currentFactor, 0.50);
    });

    test('窄屏下 effectiveMinWidth=min(320,maxWidth) 的边界', () {
      final model = ChatPanelWidthModel();

      model.applyDrag(windowWidth: 500, deltaDx: -1000);

      // maxWidth=250, effectiveMinWidth=min(320,250)=250, 因此最终宽度固定为250
      expect(model.currentFactor, 0.50);
    });

    test('左拖(deltaDx<0)时面板变宽', () {
      final model = ChatPanelWidthModel();
      final before = model.currentFactor;

      model.applyDrag(windowWidth: 1000, deltaDx: -80);

      expect(model.currentFactor, greaterThan(before));
    });

    test('右拖(deltaDx>0)时面板变窄', () {
      final model = ChatPanelWidthModel();
      final before = model.currentFactor;

      model.applyDrag(windowWidth: 1200, deltaDx: 40);

      expect(model.currentFactor, lessThan(before));
    });

    test('resize 时 currentFactor 与 lastExpandedFactor 同时合法化', () {
      final model = ChatPanelWidthModel(
        currentFactor: 0.45,
        lastExpandedFactor: 0.49,
      );

      model.clampForWindow(400);

      expect(model.currentFactor, 0.50);
      expect(model.lastExpandedFactor, 0.50);
    });

    test('windowWidth<=0 时 applyDrag 不产生非法值', () {
      final model = ChatPanelWidthModel(currentFactor: 0.42);

      model.applyDrag(windowWidth: 0, deltaDx: -100);
      expect(model.currentFactor, 0.42);
      expect(model.currentFactor.isFinite, isTrue);

      model.applyDrag(windowWidth: -300, deltaDx: 50);
      expect(model.currentFactor, 0.42);
      expect(model.currentFactor.isFinite, isTrue);
    });

    test('折叠态 saveExpandedWidth 不应覆盖历史值', () {
      final model = ChatPanelWidthModel(
        currentFactor: 0.33,
        lastExpandedFactor: 0.45,
      );

      model.collapse(1000);
      model.setCurrentFactor(0.47);
      model.saveExpandedWidth();

      // collapse 已内聚保存为 0.33，折叠态 save 不应再被后续 currentFactor 覆盖
      expect(model.lastExpandedFactor, 0.33);
    });

    test('expand 恢复 lastExpandedFactor', () {
      final model = ChatPanelWidthModel(
        currentFactor: 0.41,
        lastExpandedFactor: 0.41,
      );

      model.collapse(1000);
      model.expand();

      expect(model.collapsed, isFalse);
      expect(model.currentFactor, 0.41);
    });

    test('无历史值时回退默认值', () {
      final model = ChatPanelWidthModel(
        currentFactor: 0.45,
        lastExpandedFactor: null,
        collapsed: true,
      );

      model.expand();

      expect(model.currentFactor, ChatPanelWidthModel.defaultFactor);
      expect(model.lastExpandedFactor, ChatPanelWidthModel.defaultFactor);
    });

    test('collapse 动作本身保存合法化后的展开宽度', () {
      final model = ChatPanelWidthModel(
        currentFactor: 0.48,
        lastExpandedFactor: 0.35,
      );

      model.collapse(400);

      expect(model.collapsed, isTrue);
      // 400px 下 maxWidth=200, effectiveMinWidth=200，合法化后 factor 为 0.5
      expect(model.lastExpandedFactor, 0.50);
    });

    test('collapsed 时 applyDrag 无效', () {
      final model = ChatPanelWidthModel(
        currentFactor: 0.35,
        lastExpandedFactor: 0.35,
      );
      model.collapse(1000);
      final before = model.currentFactor;

      model.applyDrag(windowWidth: 1000, deltaDx: -200);

      expect(model.currentFactor, before);
    });
  });
}
