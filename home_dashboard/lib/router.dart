import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'responsive_scaffold.dart';
import 'features/home/home_page.dart';
import 'features/welcome/welcome_page.dart';
import 'features/video/video_page.dart';
import 'core/models/network_type.dart';

GoRouter createAppRouter({
  required ThemeMode themeMode,
  required ValueChanged<ThemeMode> onThemeModeChanged,
  required NetworkType networkType,
  required bool networkLoaded,
  required VoidCallback? onRefreshNetwork,
}) {
  return GoRouter(
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return ResponsiveScaffold(
            themeMode: themeMode,
            onThemeModeChanged: onThemeModeChanged,
            networkType: networkType,
            networkLoaded: networkLoaded,
            onRefreshNetwork: onRefreshNetwork,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: '/welcome',
            builder: (context, state) => const WelcomePage(),
          ),
          GoRoute(
            path: '/video',
            builder: (context, state) => const VideoPage(),
          ),
        ],
      ),
    ],
  );
}
