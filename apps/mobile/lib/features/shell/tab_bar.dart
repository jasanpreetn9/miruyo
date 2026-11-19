import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/auth/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

class TabSpec {
  const TabSpec(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The five tabs. The third is Seasonal in anime mode and Releases in manga
/// mode (AniList has no manga schedule).
List<TabSpec> tabsFor({required bool isAnime}) => [
  const TabSpec('Home', Symbols.home_rounded),
  const TabSpec('Browse', Symbols.explore_rounded),
  isAnime
      ? const TabSpec('Seasonal', Symbols.calendar_month_rounded)
      : const TabSpec('Releases', Symbols.new_releases_rounded),
  const TabSpec('My List', Symbols.bookmarks_rounded),
  const TabSpec('Profile', Symbols.person_rounded),
];

/// The phone tab bar (TabBar.dc.html): 52px tabs over a blurred bar, the
/// active one with a tinted pill, a filled icon and the mode accent.
class AppTabBar extends ConsumerWidget {
  const AppTabBar({super.key, required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      // fixed-height tabs: their labels don't grow (as iOS's own tab bars)
      MediaQuery.withNoTextScaling(child: _build(context, ref));

  Widget _build(BuildContext context, WidgetRef ref) {
    final isAnime = ref.watch(modeProvider).isAnime;
    final mode = context.mode;
    final tabs = tabsFor(isAnime: isAnime);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.fromLTRB(8, 6, 8, bottom > 0 ? bottom : 8),
          decoration: const BoxDecoration(
            color: Color(0xEB0C0E15), // rgba(12,14,21,.92)
            border: Border(top: BorderSide(color: Color(0x12FFFFFF))),
          ),
          child: Row(
            children: [
              for (final (i, tab) in tabs.indexed)
                Expanded(
                  child: _Tab(
                    spec: tab,
                    active: i == index,
                    accent: mode.accentText,
                    tint: mode.tint,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.spec, required this.active, required this.accent, required this.tint, required this.onTap});

  final TabSpec spec;
  final bool active;
  final Color accent;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? accent : TextTone.mid;
    return Semantics(
      button: true,
      selected: active,
      label: spec.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: Motion.overlay,
                curve: Motion.enter,
                width: 56,
                height: 30,
                decoration: BoxDecoration(
                  color: active ? tint : Colors.transparent,
                  borderRadius: BorderRadius.circular(Corner.full),
                ),
                child: Icon(spec.icon, size: 24, color: color, fill: active ? 1 : 0),
              ),
              const SizedBox(height: 3),
              Text(
                spec.label,
                style: AppType.caption.copyWith(
                  fontSize: 11,
                  color: color,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
