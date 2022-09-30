import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:wives/hooks/useAutoScrollController.dart';
import 'package:wives/hooks/usePaletteOverlay.dart';
import 'package:wives/models/intents.dart';
import 'package:wives/providers/TerminalProvider.dart';
import 'package:wives/routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  doWhenWindowReady(() {
    const initialSize = Size(700, 500);
    appWindow.minSize = initialSize;
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.show();
  });
  runApp(const ProviderScope(child: Terminal()));
}

class Terminal extends HookConsumerWidget {
  const Terminal({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, ref) {
    final terminalTabScrollController = useAutoScrollController();
    final openPalette = usePaletteOverlay();

    useEffect(() {
      router.go("/", extra: terminalTabScrollController);
      ref.read(terminalProvider).terminalAt(0)?.key.requestFocus();
      return null;
    }, []);

    return MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      title: 'Terminal',
      darkTheme: ThemeData.dark().copyWith(
        backgroundColor: Colors.black,
        scaffoldBackgroundColor: Colors.transparent,
        buttonTheme: ButtonThemeData(
          hoverColor: Colors.grey.withOpacity(0.2),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          isDense: true,
          border: OutlineInputBorder(
            borderSide: BorderSide(
              color: Colors.grey,
              width: 2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Colors.grey,
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Colors.blue,
              width: 2,
            ),
          ),
        ),
      ),
      themeMode: ThemeMode.dark,
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.keyT, control: true):
            TabIntent(
          controller: terminalTabScrollController,
          ref: ref,
          intentType: TabIntentType.create,
        ),
        const SingleActivator(LogicalKeyboardKey.keyW, control: true):
            TabIntent(
          controller: terminalTabScrollController,
          ref: ref,
          intentType: TabIntentType.close,
        ),
        const SingleActivator(LogicalKeyboardKey.tab, control: true): TabIntent(
          controller: terminalTabScrollController,
          ref: ref,
          intentType: TabIntentType.cycleForward,
        ),
        const SingleActivator(LogicalKeyboardKey.comma, control: true):
            const NavigationIntent(path: "/settings"),
        const SingleActivator(LogicalKeyboardKey.equal, control: true):
            FontAdjustmentIntent(ref: ref, adjustment: 1),
        const SingleActivator(LogicalKeyboardKey.minus, control: true):
            FontAdjustmentIntent(ref: ref, adjustment: -1),
        const SingleActivator(LogicalKeyboardKey.keyP, control: true):
            const PaletteIntent(),
      },
      actions: {
        ...WidgetsApp.defaultActions,
        TabIntent: TabAction(),
        NavigationIntent: NavigationAction(),
        FontAdjustmentIntent: FontAdjustmentAction(),
        PaletteIntent: CallbackAction(
          onInvoke: (intent) => openPalette(),
        )
      },
    );
  }
}
