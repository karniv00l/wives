import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:wives/components/CompactIconButton.dart';
import 'package:wives/components/WindowTitleBar.dart';
import 'package:wives/hooks/useTabShorcuts.dart';
import 'package:wives/models/intents.dart';
import 'package:wives/providers/PreferencesProvider.dart';
import 'package:wives/providers/TerminalProvider.dart';
import 'package:wives/services/native.dart';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import 'package:collection/collection.dart';

class TerminalFrame extends HookConsumerWidget {
  final AutoScrollController scrollController;
  const TerminalFrame({
    required this.scrollController,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, ref) {
    final shells = NativeUtils.getShells();
    final terminal = ref.watch(terminalProvider);
    final preferences = ref.watch(preferencesProvider);

    final activeIndex = terminal.activeIndex;

    void createNewTab([String? shell]) => scrollController.scrollToIndex(
          terminal.createTerminalTab(shell),
          preferPosition: AutoScrollPosition.begin,
        );

    void closeTab(int index) {
      terminal.closeTerminalTab(index);
    }

    final isSearchOpen = useState(false);
    final currentTerminal = terminal.terminalAt(activeIndex)?.value;
    useEffect(() {
      if (isSearchOpen.value) {
        isSearchOpen.value = false;
      }
      // currentTerminal?.isUserSearchActive = false;
      return null;
    }, [activeIndex]);

    // useSearchOverlay(
    //   isSearchOpen.value,
    //   onClose: () {
    //     isSearchOpen.value = false;
    //     currentTerminal?.isUserSearchActive = false;
    //     terminal.terminalAt(activeIndex)?.key.requestFocus();
    //   },
    //   onSearch: (value) {
    //     currentTerminal?.userSearchPattern = value;
    //   },
    //   onUpdateSearchOptions: (options) {
    //     currentTerminal?.userSearchOptions = options;
    //   },
    // );

    final shortcuts = useTabShortcuts(ref, scrollController);

    return CallbackShortcuts(
      bindings: {
        // this mitigates the Arrow Up focus change issue
        LogicalKeySet(LogicalKeyboardKey.arrowUp): () {},
        // this mitigates the Tab focus change issue
        LogicalKeySet(LogicalKeyboardKey.tab): () {},
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: WindowTitleBar(
            leading: Scrollbar(
              controller: scrollController,
              child: ListView.builder(
                controller: scrollController,
                scrollDirection: Axis.horizontal,
                shrinkWrap: true,
                itemCount: terminal.instances.length + 1,
                itemBuilder: (context, i) {
                  if (terminal.instances.length == i) {
                    return Center(
                      child: Row(
                        children: [
                          const SizedBox(width: 5),
                          CompactIconButton(
                            onPressed: createNewTab,
                            child: const Icon(Icons.add_rounded),
                          ),
                          PopupMenuButton<String>(
                            position: PopupMenuPosition.under,
                            onSelected: (value) {
                              if (value == "settings") {
                                GoRouter.of(context).push("/settings");
                              } else {
                                createNewTab(value);
                              }
                            },
                            onCanceled: () {
                              final tab = terminal.instances.entries
                                  .elementAt(activeIndex)
                                  .key;
                              tab.requestFocus();
                            },
                            offset: const Offset(0, 10),
                            tooltip: "Shells",
                            color: Colors.black,
                            itemBuilder: (context) {
                              return [
                                ...shells
                                    .map((shell) => PopupMenuItem(
                                          height: 30,
                                          value: shell,
                                          child: ListTile(
                                            dense: true,
                                            horizontalTitleGap: 0,
                                            contentPadding: EdgeInsets.zero,
                                            leading: const Icon(
                                                Icons.terminal_rounded),
                                            title: Text(shell),
                                          ),
                                        ))
                                    .toList(),
                                const PopupMenuItem(
                                  height: 30,
                                  value: "settings",
                                  child: ListTile(
                                    dense: true,
                                    horizontalTitleGap: 0,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.settings_outlined),
                                    title: Text("Settings"),
                                  ),
                                )
                              ];
                            },
                            child:
                                const Icon(Icons.keyboard_arrow_down_rounded),
                          ),
                        ],
                      ),
                    );
                  }

                  final tab = "Terminal $i";
                  return AutoScrollTag(
                    controller: scrollController,
                    index: i,
                    key: ValueKey(i),
                    child: InkWell(
                      onTap: activeIndex != i
                          ? () {
                              terminal.setActiveIndex(i);
                              scrollController.scrollToIndex(
                                i,
                                preferPosition: AutoScrollPosition.end,
                              );
                            }
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        margin: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: activeIndex == i ? Colors.grey[800] : null,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                              child: Row(children: [
                                Text(tab),
                                const SizedBox(width: 5),
                                CompactIconButton(
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 15,
                                  ),
                                  onPressed: () => closeTab(i),
                                )
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          body: terminal.instances.entries.mapIndexed((i, tab) {
            final isActive = i == activeIndex;
            final controller = TerminalController();
            return TerminalView(
              tab.value,
              controller: controller,
              padding: const EdgeInsets.all(5),
              autofocus: true,
              focusNode: tab.key,
              textStyle: TerminalStyle(
                fontSize: preferences.fontSize,
                fontFamily: "Cascadia Mono",
              ),
              shortcuts: {
                if (isActive) ...shortcuts,
                const SingleActivator(
                  LogicalKeyboardKey.keyC,
                  control: true,
                  shift: true,
                ): CopyPasteIntent(
                  tab.value,
                  intentType: CopyPasteIntentType.copy,
                  controller: controller,
                ),
                const SingleActivator(
                  LogicalKeyboardKey.keyV,
                  control: true,
                  shift: true,
                ): CopyPasteIntent(
                  tab.value,
                  intentType: CopyPasteIntentType.paste,
                  controller: controller,
                ),
              },
            );
          }).toList()[activeIndex],
        ),
      ),
    );
  }
}
