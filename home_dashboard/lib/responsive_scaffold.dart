import 'package:flutter/material.dart';
import 'core/constants/navigation_config.dart';
import 'core/models/navigation_models.dart';
import 'core/models/network_type.dart';
import 'core/models/app_config.dart';
import 'core/layout/layout_manager.dart';
import 'core/navigation/navigation_state_manager.dart';
import 'shared/navigation/drawer_navigation.dart';
import 'shared/navigation/rail_navigation.dart';
import 'shared/navigation/child_drawer.dart';
import 'shared/widgets/footer_widget.dart';
import 'shared/widgets/footer_controller.dart';
import 'shared/widgets/responsive_app_bar.dart';

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
  late final ScrollController _scrollController;
  late final LayoutManager _layoutManager;
  late final NavigationStateManager _navStateManager;
  late final FooterController _footerController;
  bool _isScrolled = false;

  final List<NavItem> _navItems = NavigationConfig.items;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _layoutManager = LayoutManager();
    _navStateManager = NavigationStateManager();
    _footerController = FooterController();
  }

  @override
  void dispose() {
    _footerController.dispose();
    _navStateManager.dispose();
    _layoutManager.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Track scroll position for AppBar color change
    final isScrolled =
        _scrollController.hasClients && _scrollController.offset > 0;
    if (isScrolled != _isScrolled) {
      setState(() {
        _isScrolled = isScrolled;
      });
    }

    // Show footer with auto-hide timer
    _footerController.showFooterWithTimer();
  }

  void _onPointerScroll() {
    // Call scroll logic so pointer events also trigger footer
    _onScroll();
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
    if (_navItems[index].hasChildren) {
      // Show child menu in dialog for small screens
      _showChildMenuDialog(index);
    } else {
      _navStateManager.navigateTo(index, context, _navItems);
      _footerController.hideFooter();
      Navigator.of(context).pop(); // Close drawer
    }
  }

  void _onNavTapWithDrawer(int index, double width) {
    _navStateManager.navigateToWithDrawer(index, context, _navItems, width);
    _footerController.hideFooter();
  }

  void _onChildTap(int childIndex) {
    Navigator.of(context).pop(); // Close dialog/drawer
    _navStateManager.navigateToChild(childIndex, context);
    _footerController.hideFooter();
  }

  void _onGrandchildTap(int childIndex, int grandchildIndex) {
    Navigator.of(context).pop(); // Close dialog/drawer
    _navStateManager.navigateToGrandchild(childIndex, grandchildIndex, context);
    _footerController.hideFooter();
  }

  void _onBrandTap() {
    _navStateManager.navigateTo(0, context, _navItems);
    _footerController.hideFooter();
  }

  void _showChildMenuDialog(int parentIndex) {
    Navigator.pop(context); // Close main drawer first
    Future.delayed(const Duration(milliseconds: 100), () {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Dismiss',
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Material(
              elevation: 16,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: SizedBox(
                width: 304,
                height: double.infinity,
                child: ChildDrawer(
                  parentItem: _navItems[parentIndex],
                  parentIndex: parentIndex,
                  selectedChildIndex: _navStateManager.selectedCCChild,
                  selectedGrandchildIndex: _navStateManager.selectedGrandchild,
                  expandedChildren: _navStateManager.expandedChildren,
                  onChildTap: _onChildTap,
                  onGrandchildTap: _onGrandchildTap,
                  isDialog: true,
                  onBack: () {
                    Navigator.pop(context);
                    Future.delayed(const Duration(milliseconds: 100), () {
                      _scaffoldKey.currentState?.openDrawer();
                    });
                  },
                ),
              ),
            ),
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: child,
            ),
          );
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
    return Scaffold(
      key: _scaffoldKey,
      appBar: ResponsiveAppBar(
        isScrolled: _isScrolled,
        networkType: widget.networkType,
        networkLoaded: widget.networkLoaded,
        onRefreshNetwork: widget.onRefreshNetwork,
        onBrandTap: _onBrandTap,
      ),
      drawer: DrawerNavigation(
        navItems: _navItems,
        selectedIndex: _navStateManager.selectedIndex,
        themeMode: widget.themeMode,
        onNavTap: _onNavTap,
        onThemeToggle: _toggleThemeMode,
      ),
      body: _buildBodyWithFooter(),
    );
  }

  Widget _buildDesktopLayout(double width, ColorScheme colorScheme) {
    return Scaffold(
      body: Row(
        children: [
          RailNavigation(
            navItems: _navItems,
            selectedIndex: _navStateManager.selectedIndex,
            themeMode: widget.themeMode,
            onDestinationSelected: (index) => _onNavTapWithDrawer(index, width),
            onThemeToggle: _toggleThemeMode,
            networkType: widget.networkType,
            networkLoaded: widget.networkLoaded,
            onRefreshNetwork: widget.onRefreshNetwork,
          ),
          if (_shouldShowChildDrawer(width))
            SizedBox(
              width: 240,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: ChildDrawer(
                  parentItem: _navItems[2],
                  parentIndex: 2,
                  selectedChildIndex: _navStateManager.selectedCCChild,
                  selectedGrandchildIndex: _navStateManager.selectedGrandchild,
                  expandedChildren: _navStateManager.expandedChildren,
                  onChildTap: _onChildTap,
                  onGrandchildTap: _onGrandchildTap,
                  isDialog: false,
                  onBack: width >= Breakpoints.mobileSmall &&
                          width < Breakpoints.desktop
                      ? () => _navStateManager.closeChildDrawer()
                      : null,
                ),
              ),
            ),
          Expanded(
            child: Listener(
              onPointerSignal: (event) {
                print(
                    '[POINTER] Pointer signal detected (desktop): ${event.runtimeType}');
                _onPointerScroll();
              },
              child: _buildBodyWithFooter(),
            ),
          ),
        ],
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
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(child: _buildScrollableContent()),
        ListenableBuilder(
          listenable: _footerController,
          builder: (context, child) {
            final footerMode = _footerController.getCurrentFooterMode(
              selectedIndex: _navStateManager.selectedIndex,
              selectedChild: _navStateManager.selectedCCChild,
              selectedGrandchild: _navStateManager.selectedGrandchild,
            );
            final shouldShow = footerMode == FooterMode.defaultShow &&
                _footerController.showFooter;

            return AnimatedOpacity(
              opacity: shouldShow ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child:
                  shouldShow ? const FooterWidget() : const SizedBox.shrink(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildScrollableContent() {
    // For mobile: wrap in gesture detector to catch taps
    if (_layoutManager.currentMode == LayoutMode.tiny ||
        _layoutManager.currentMode == LayoutMode.small) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _onScroll(),
        onPanStart: (_) => _onScroll(),
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _onScroll();
            return false;
          },
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            child: widget.child,
          ),
        ),
      );
    }

    // For desktop: just use scroll view
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      child: widget.child,
    );
  }
}
