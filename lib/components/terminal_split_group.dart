import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:wives/providers/terminal_theme_provider.dart';
import 'package:wives/components/compact_icon_button.dart';
import 'package:wives/providers/preferences_provider.dart';
import 'package:wives/providers/terminal_tree.dart';
import 'package:xterm/core.dart';
import 'package:xterm/ui.dart';

class TerminalSplitGroup extends HookConsumerWidget {
  final TerminalNode node;
  final VoidCallback? onClose;
  final void Function(
          TerminalNode node, TapDownDetails details, CellOffset offset)?
      onSecondaryTapDown;
  final Map<ShortcutActivator, Intent>? shortcuts;
  const TerminalSplitGroup({
    required this.node,
    this.onClose,
    this.onSecondaryTapDown,
    this.shortcuts,
    super.key,
  });

  @override
  Widget build(BuildContext context, ref) {
    final preferences = ref.watch(preferencesProvider);

    useEffect(() {
      listener() {
        if (node.focusNode.hasFocus) {
          ref.read(TerminalTree.provider).setFocused(node);
        }
      }

      node.focusNode.addListener(listener);

      return () {
        node.focusNode.removeListener(listener);
      };
    }, [node.focusNode]);

    final defaultBody = Stack(
      children: [
        TerminalView(
          node.terminal,
          padding: const EdgeInsets.all(5),
          autofocus: true,
          focusNode: node.focusNode,
          controller: node.controller,
          textStyle: TerminalStyle(
            fontSize: preferences.fontSize,
            fontFamily: preferences.fontFamily,
          ),
          onTapUp: (p0, p1) {
            node.focusNode.requestFocus();
          },
          onSecondaryTapDown: (details, cellOffset) =>
              onSecondaryTapDown?.call(node, details, cellOffset),
          shortcuts: shortcuts,
          theme: preferences.defaultTheme.value,
        ),
        Material(
          type: MaterialType.transparency,
          child: IconTheme(
            data: const IconThemeData(size: 18, color: Colors.white),
            child: Padding(
              padding: const EdgeInsets.only(top: 5, right: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Tooltip(
                    message: "Split Terminal Horizontally",
                    child: CompactIconButton(
                      onPressed: () {
                        node.split(TerminalAxis.row);
                      },
                      child:
                          const Icon(FluentIcons.split_horizontal_12_regular),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Tooltip(
                    message: "Split Terminal Vertically",
                    child: CompactIconButton(
                      onPressed: () {
                        node.split(TerminalAxis.column);
                      },
                      child: const Icon(FluentIcons.split_vertical_12_regular),
                    ),
                  ),
                  if (onClose != null) ...[
                    const SizedBox(width: 5),
                    Tooltip(
                      message: "Close this Sub-Terminal",
                      child: CompactIconButton(
                        onPressed: onClose,
                        child: const Icon(Icons.close_sharp),
                      ),
                    )
                  ]
                ],
              ),
            ),
          ),
        ),
      ],
    );

    final invertedAxis =
        node.axis == TerminalAxis.row ? TerminalAxis.column : TerminalAxis.row;

    if (node.isLeaf) return defaultBody;

    return MultiSplitViewTheme(
      data: MultiSplitViewThemeData(
        dividerThickness: 1,
        dividerPainter: DividerPainter(
          backgroundColor: Theme.of(context).dividerColor,
        ),
      ),
      child: MultiSplitView(
        axis: node.axis,
        children: [
          MultiSplitView(
            axis: invertedAxis,
            children: [
              defaultBody,
              ...node.disobedientChildren.map(
                (childNode) => TerminalSplitGroup(
                  node: childNode,
                  onSecondaryTapDown: onSecondaryTapDown,
                  shortcuts: shortcuts,
                  onClose: () {
                    node.removeChild(childNode);
                  },
                ),
              ),
            ],
          ),
          ...node.obedientChildren.map(
            (childNode) {
              return TerminalSplitGroup(
                node: childNode,
                onSecondaryTapDown: onSecondaryTapDown,
                shortcuts: shortcuts,
                onClose: () {
                  node.removeChild(childNode);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
