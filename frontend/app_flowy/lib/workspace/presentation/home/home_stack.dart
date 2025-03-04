import 'package:app_flowy/startup/startup.dart';
import 'package:app_flowy/workspace/presentation/home/home_screen.dart';
import 'package:flowy_infra/theme.dart';
import 'package:flowy_sdk/log.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:time/time.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:app_flowy/plugin/plugin.dart';
import 'package:app_flowy/startup/tasks/load_plugin.dart';
import 'package:app_flowy/workspace/presentation/plugins/blank/blank.dart';
import 'package:app_flowy/workspace/presentation/home/home_sizes.dart';
import 'package:app_flowy/workspace/presentation/home/navigation.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flowy_infra_ui/style_widget/extension.dart';
import 'package:flowy_infra/notifier.dart';

typedef NavigationCallback = void Function(String id);

late FToast fToast;

class HomeStack extends StatelessWidget {
  static GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();
  // final Size size;
  const HomeStack({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Log.info('HomePage build');
    final theme = context.watch<AppTheme>();
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        getIt<HomeStackManager>().stackTopBar(),
        Expanded(
          child: Container(
            color: theme.surface,
            child: FocusTraversalGroup(
              child: getIt<HomeStackManager>().stackWidget(),
            ),
          ),
        ),
      ],
    );
  }
}

class FadingIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const FadingIndexedStack({
    Key? key,
    required this.index,
    required this.children,
    this.duration = const Duration(
      milliseconds: 250,
    ),
  }) : super(key: key);

  @override
  _FadingIndexedStackState createState() => _FadingIndexedStackState();
}

class _FadingIndexedStackState extends State<FadingIndexedStack> {
  double _targetOpacity = 1;

  @override
  void initState() {
    super.initState();
    fToast = FToast();
    fToast.init(HomeScreen.scaffoldKey.currentState!.context);
  }

  @override
  void didUpdateWidget(FadingIndexedStack oldWidget) {
    if (oldWidget.index == widget.index) return;
    setState(() => _targetOpacity = 0);
    Future.delayed(1.milliseconds, () => setState(() => _targetOpacity = 1));
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: _targetOpacity > 0 ? widget.duration : 0.milliseconds,
      tween: Tween(begin: 0, end: _targetOpacity),
      builder: (_, value, child) {
        return Opacity(opacity: value, child: child);
      },
      child: IndexedStack(index: widget.index, children: widget.children),
    );
  }
}

abstract class NavigationItem {
  Widget get leftBarItem;
  Widget? get rightBarItem => null;

  NavigationCallback get action => (id) {
        getIt<HomeStackManager>().setStackWithId(id);
      };
}

class HomeStackNotifier extends ChangeNotifier {
  Plugin _plugin;
  PublishNotifier<bool> collapsedNotifier = PublishNotifier();

  Widget get titleWidget => _plugin.pluginDisplay.leftBarItem;

  HomeStackNotifier({Plugin? plugin}) : _plugin = plugin ?? makePlugin(pluginType: DefaultPlugin.blank.type());

  set plugin(Plugin newPlugin) {
    if (newPlugin.pluginId == _plugin.pluginId) {
      return;
    }

    _plugin.displayNotifier?.removeListener(notifyListeners);
    _plugin.dispose();

    _plugin = newPlugin;
    _plugin.displayNotifier?.addListener(notifyListeners);
    notifyListeners();
  }

  Plugin get plugin => _plugin;
}

// HomeStack is initialized as singleton to controll the page stack.
class HomeStackManager {
  final HomeStackNotifier _notifier = HomeStackNotifier();
  HomeStackManager();

  Widget title() {
    return _notifier.plugin.pluginDisplay.leftBarItem;
  }

  PublishNotifier<bool> get collapsedNotifier => _notifier.collapsedNotifier;

  void setPlugin(Plugin newPlugin) {
    _notifier.plugin = newPlugin;
  }

  void setStackWithId(String id) {}

  Widget stackTopBar() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _notifier),
      ],
      child: Selector<HomeStackNotifier, Widget>(
        selector: (context, notifier) => notifier.titleWidget,
        builder: (context, widget, child) {
          return const HomeTopBar();
        },
      ),
    );
  }

  Widget stackWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _notifier),
      ],
      child: Consumer(builder: (ctx, HomeStackNotifier notifier, child) {
        return FadingIndexedStack(
          index: getIt<PluginSandbox>().indexOf(notifier.plugin.pluginType),
          children: getIt<PluginSandbox>().supportPluginTypes.map((pluginType) {
            if (pluginType == notifier.plugin.pluginType) {
              return notifier.plugin.pluginDisplay.buildWidget();
            } else {
              return const BlankStackPage();
            }
          }).toList(),
        );
      }),
    );
  }
}

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppTheme>();
    return Container(
      color: theme.surface,
      height: HomeSizes.topBarHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const FlowyNavigation(),
          const HSpace(16),
          ChangeNotifierProvider.value(
            value: Provider.of<HomeStackNotifier>(context, listen: false),
            child: Consumer(
              builder: (BuildContext context, HomeStackNotifier notifier, Widget? child) {
                return notifier.plugin.pluginDisplay.rightBarItem ?? const SizedBox();
              },
            ),
          ) // _renderMoreButton(),
        ],
      )
          .padding(
            horizontal: HomeInsets.topBarTitlePadding,
          )
          .bottomBorder(color: Colors.grey.shade300),
    );
  }
}
