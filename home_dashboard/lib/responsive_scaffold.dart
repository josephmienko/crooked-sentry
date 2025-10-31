import 'package:flutter/material.dart';
import 'core/constants/navigation_config.dart';
import 'core/models/navigation_models.dart';
import 'core/models/network_type.dart';
import 'core/layout/layout_manager.dart';
import 'core/layout/layout_builders.dart';
import 'core/layout/content_builder.dart';
import 'core/navigation/navigation_state_manager.dart';
import 'core/navigation/navigation_handler.dart';
import 'core/services/dialog_service.dart';
import 'core/services/scroll_handler.dart';
import 'shared/widgets/footer_controller.dart';

class ResponsiveScaffold extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final NetworkType networkType;
  final bool networkLoaded;
  final VoidCallback? onRefreshNetwork;
  final Widget child;

  const ResponsiveScaffold({
    Key? key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.networkType,
    required this.networkLoaded,
    this.onRefreshNetwork,
    required this.child,
  }) : super(key: key);

  @override
  State<ResponsiveScaffold> createState() => _ResponsiveScaffoldState();
}

class _ResponsiveScaffoldState extends State<ResponsiveScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final LayoutManager _layoutManager;
  late final NavigationStateManager _navStateManager;
  late final FooterController _footerController;
  late final ScrollHandler _scrollHandler;
  late final NavigationHandler _navHandler;

  final List<NavItem> _navItems = NavigationConfig.items;

  @override
  void initState() {
    super.initState();
    _footerController = FooterController();
    _scrollHandler = ScrollHandler(footerController: _footerController);
    _layoutManager = LayoutManager();
    _navStateManager = NavigationStateManager();
    _navHandler = NavigationHandler(
      stateManager: _navStateManager,
      footerController: _footerController,
      navItems: _navItems,
    );

    // Listen to scroll handler for AppBar updates
    _scrollHandler.addListener(_onScrollStateChanged);
  }

  @override
  void dispose() {
    _scrollHandler.removeListener(_onScrollStateChanged);
    _scrollHandler.dispose();
    _footerController.dispose();
    _navStateManager.dispose();
    _layoutManager.dispose();
    super.dispose();
  }

  void _onScrollStateChanged() {
    // ScrollHandler notifies when scroll state changes
    setState(() {});
  }

  void _toggleThemeMode() {
    final newMode = switch (widget.themeMode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.light,
    };
    widget.onThemeModeChanged(newMode);
  }

  void _onNavTap(int index) {
    if (_navHandler.shouldShowChildMenu(index)) {
      // Show child menu in dialog for small screens
      _showChildMenuDialog(index);
    } else {
      _navHandler.onNavTap(index, context);
    }
  }

  void _showChildMenuDialog(int parentIndex) {
    Navigator.pop(context); // Close main drawer first
    Future.delayed(const Duration(milliseconds: 100), () {
      DialogService.showChildMenuDialog(
        context: context,
        parentItem: _navItems[parentIndex],
        parentIndex: parentIndex,
        selectedChildIndex: _navStateManager.selectedCCChild,
        selectedGrandchildIndex: _navStateManager.selectedGrandchild,
        expandedChildren: _navStateManager.expandedChildren,
        onChildTap: (index) => _navHandler.onChildTap(index, context),
        onGrandchildTap: (childIndex, grandchildIndex) =>
            _navHandler.onGrandchildTap(childIndex, grandchildIndex, context),
        onBack: () {
          Navigator.pop(context);
          Future.delayed(const Duration(milliseconds: 100), () {
            _scaffoldKey.currentState?.openDrawer();
          });
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final colorScheme = Theme.of(context).colorScheme;

        // Auto-show footer on small screens
        _footerController.maybeAutoShowForSmallScreen(width);

        // Handle layout transitions
        _handleLayoutTransitions(width);

        // Determine layout mode
        final layoutMode = LayoutManager.modeFromWidth(width);

        // Build appropriate layout based on screen size
        switch (layoutMode) {
          case LayoutMode.tiny:
          case LayoutMode.small:
            return _buildMobileLayout(colorScheme);
          case LayoutMode.medium:
          case LayoutMode.desktop:
            return _buildDesktopLayout(width, colorScheme);
        }
      },
    );
  }

  void _handleLayoutTransitions(double width) {
    final oldWidth = _layoutManager.lastWidth;

    // Auto-close drawer/dialogs on screen expansion
    if (_layoutManager.shouldCloseDrawersOnExpand(oldWidth, width)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          Navigator.of(context).pop();
        }
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    }

    // Close child drawer when shrinking from desktop to medium
    if (_layoutManager.shouldCloseChildDrawerOnShrink(oldWidth, width) &&
        _navStateManager.showChildDrawer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _navStateManager.closeChildDrawer();
        }
      });
    }

    _layoutManager.updateLayout(width);
  }

  Widget _buildMobileLayout(ColorScheme colorScheme) {
    return MobileLayoutBuilder.build(
      context: context,
      scaffoldKey: _scaffoldKey,
      isScrolled: _scrollHandler.isScrolled,
      networkType: widget.networkType,
      networkLoaded: widget.networkLoaded,
      onRefreshNetwork: widget.onRefreshNetwork,
      onBrandTap: () => _navHandler.onBrandTap(context),
      navItems: _navItems,
      selectedIndex: _navStateManager.selectedIndex,
      themeMode: widget.themeMode,
      onNavTap: _onNavTap,
      onThemeToggle: _toggleThemeMode,
      body: _buildBodyWithFooter(),
    );
  }

  Widget _buildDesktopLayout(double width, ColorScheme colorScheme) {
    return DesktopLayoutBuilder.build(
      context: context,
      width: width,
      navItems: _navItems,
      selectedIndex: _navStateManager.selectedIndex,
      themeMode: widget.themeMode,
      onDestinationSelected: (index) =>
          _navHandler.onNavTapWithDrawer(index, context, width),
      onThemeToggle: _toggleThemeMode,
      networkType: widget.networkType,
      networkLoaded: widget.networkLoaded,
      onRefreshNetwork: widget.onRefreshNetwork,
      shouldShowChildDrawer: _shouldShowChildDrawer(width),
      selectedChildIndex: _navStateManager.selectedCCChild,
      selectedGrandchildIndex: _navStateManager.selectedGrandchild,
      expandedChildren: _navStateManager.expandedChildren,
      onChildTap: (index) => _navHandler.onChildTap(index, context),
      onGrandchildTap: (childIndex, grandchildIndex) =>
          _navHandler.onGrandchildTap(childIndex, grandchildIndex, context),
      onChildDrawerBack:
          width >= Breakpoints.mobileSmall && width < Breakpoints.desktop
              ? () => _navStateManager.closeChildDrawer()
              : null,
      body: Listener(
        onPointerSignal: (event) {
          print(
              '[POINTER] Pointer signal detected (desktop): ${event.runtimeType}');
          _scrollHandler.handlePointerScroll();
        },
        child: _buildBodyWithFooter(),
      ),
    );
  }

  bool _shouldShowChildDrawer(double width) {
    return (width >= Breakpoints.mobileSmall &&
            width < Breakpoints.desktop &&
            _navStateManager.showChildDrawer) ||
        (width >= Breakpoints.desktop && _navStateManager.selectedIndex == 2);
  }

  Widget _buildBodyWithFooter() {
    return ContentBuilder.buildWithFooter(
      child: widget.child,
      footerController: _footerController,
      selectedIndex: _navStateManager.selectedIndex,
      selectedChild: _navStateManager.selectedCCChild,
      selectedGrandchild: _navStateManager.selectedGrandchild,
      layoutMode: _layoutManager.currentMode,
      scrollHandler: _scrollHandler,
    );
  }
}
