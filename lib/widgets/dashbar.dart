import 'package:flutter/material.dart';

class RoundedActionBar extends StatelessWidget {
  final VoidCallback onHome;
  final VoidCallback onSearch;
  final VoidCallback onFavorite;
  final VoidCallback onSettings;

  const RoundedActionBar({
    Key? key,
    required this.onHome,
    required this.onSearch,
    required this.onFavorite,
    required this.onSettings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionIcon(
            icon: Icons.home_rounded,
            tooltip: 'Home',
            onPressed: onHome,
          ),
          _ActionIcon(
            icon: Icons.search_rounded,
            tooltip: 'Search',
            onPressed: onSearch,
          ),
          _ActionIcon(
            icon: Icons.favorite_rounded,
            tooltip: 'Favorites',
            onPressed: onFavorite,
          ),
          _ActionIcon(
            icon: Icons.settings_rounded,
            tooltip: 'Settings',
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ActionIcon({
    Key? key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use Ink + IconButton for ripple clipped to rounded shape
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: const BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.rectangle,
          ),
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            icon: Icon(icon),
            color: Theme.of(context).colorScheme.primary,
            splashRadius: 22,
          ),
        ),
      ),
    );
  }
}
