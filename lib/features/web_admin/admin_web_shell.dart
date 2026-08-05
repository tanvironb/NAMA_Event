import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_web_theme.dart';
import 'screens/admin_web_dashboard_screen.dart';
import 'screens/admin_web_events_screen.dart';
import 'screens/admin_web_profile_settings_screen.dart';

class AdminWebShell extends StatefulWidget {
  final String adminUserId;
  final String adminName;
  final String adminEmail;
  final String profileImageUrl;

  const AdminWebShell({
    super.key,
    required this.adminUserId,
    required this.adminName,
    required this.adminEmail,
    required this.profileImageUrl,
  });

  @override
  State<AdminWebShell> createState() => _AdminWebShellState();
}

class _AdminWebShellState extends State<AdminWebShell> {
  int _selectedIndex = 0;

  static const int _dashboardIndex = 0;
  static const int _eventsIndex = 1;
  static const int _profileIndex = 2;

  static const List<_GlobalNavigationItem> _items = [
    _GlobalNavigationItem(
      label: 'Dashboard',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _GlobalNavigationItem(
      label: 'Events',
      icon: Icons.event_note_outlined,
      selectedIcon: Icons.event_note_rounded,
    ),
  ];

  String get _currentPageTitle {
    switch (_selectedIndex) {
      case _eventsIndex:
        return 'Events';
      case _profileIndex:
        return 'Profile & Settings';
      case _dashboardIndex:
      default:
        return 'Dashboard';
    }
  }

  Widget _buildCurrentScreen() {
    switch (_selectedIndex) {
      case _dashboardIndex:
        return AdminWebDashboardScreen(
          onNavigate: _selectPageByLabel,
        );

      case _eventsIndex:
        return const AdminWebEventsScreen();

      case _profileIndex:
        return AdminWebProfileSettingsScreen(
          adminUserId: widget.adminUserId,
          adminName: widget.adminName,
          adminEmail: widget.adminEmail,
          profileImageUrl: widget.profileImageUrl,
        );

      default:
        return AdminWebDashboardScreen(
          onNavigate: _selectPageByLabel,
        );
    }
  }

  void _selectPageByLabel(String label) {
    if (label == 'Profile & Settings') {
      _openProfileSettings();
      return;
    }

    final index = _items.indexWhere(
      (item) => item.label == label,
    );

    if (index < 0) return;

    setState(() {
      _selectedIndex = index;
    });
  }

  void _openProfileSettings() {
    setState(() {
      _selectedIndex = _profileIndex;
    });
  }

  void _selectNavigationItem(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;

        if (compact) {
          return Scaffold(
            backgroundColor: AdminWebTheme.background,
            appBar: AppBar(
              title: Text(
                _currentPageTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: _openProfileSettings,
                    borderRadius: BorderRadius.circular(30),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      child: _GlobalAvatar(
                        name: widget.adminName,
                        imageUrl: widget.profileImageUrl,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            drawer: Drawer(
              width: 280,
              child: _GlobalSidebar(
                items: _items,
                selectedIndex: _selectedIndex,
                adminName: widget.adminName,
                profileImageUrl: widget.profileImageUrl,
                onSelected: (index) {
                  _selectNavigationItem(index);
                  Navigator.of(context).pop();
                },
                onOpenProfile: () {
                  Navigator.of(context).pop();
                  _openProfileSettings();
                },
                onSignOut: _signOut,
              ),
            ),
            body: _buildCurrentScreen(),
          );
        }

        return Scaffold(
          backgroundColor: AdminWebTheme.background,
          body: Row(
            children: [
              SizedBox(
                width: 216,
                child: _GlobalSidebar(
                  items: _items,
                  selectedIndex: _selectedIndex,
                  adminName: widget.adminName,
                  profileImageUrl: widget.profileImageUrl,
                  onSelected: _selectNavigationItem,
                  onOpenProfile: _openProfileSettings,
                  onSignOut: _signOut,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    _GlobalTopBar(
                      pageTitle: _currentPageTitle,
                      adminName: widget.adminName,
                      profileImageUrl: widget.profileImageUrl,
                      onOpenProfile: _openProfileSettings,
                      onSignOut: _signOut,
                    ),
                    Expanded(
                      child: _buildCurrentScreen(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GlobalNavigationItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _GlobalNavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class _GlobalSidebar extends StatelessWidget {
  final List<_GlobalNavigationItem> items;
  final int selectedIndex;
  final String adminName;
  final String profileImageUrl;
  final ValueChanged<int> onSelected;
  final VoidCallback onOpenProfile;
  final VoidCallback onSignOut;

  const _GlobalSidebar({
    required this.items,
    required this.selectedIndex,
    required this.adminName,
    required this.profileImageUrl,
    required this.onSelected,
    required this.onOpenProfile,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AdminWebTheme.sidebar,
            AdminWebTheme.sidebarDark,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          const _GlobalBrand(),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'MAIN',
                style: TextStyle(
                  color: Color(0xFFA8B4CC),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final selected = selectedIndex == index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onSelected(index),
                      borderRadius: BorderRadius.circular(9),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        height: 42,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AdminWebTheme.selectedBlue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? item.selectedIcon
                                  : item.icon,
                              color: Colors.white,
                              size: 19,
                            ),
                            const SizedBox(width: 13),
                            Text(
                              item.label,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(10, 8, 10, 16),
            decoration: BoxDecoration(
              color: selectedIndex == _AdminWebShellState._profileIndex
                  ? AdminWebTheme.selectedBlue
                  : Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onOpenProfile,
                borderRadius: BorderRadius.circular(11),
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Row(
                    children: [
                      _GlobalAvatar(
                        name: adminName,
                        imageUrl: profileImageUrl,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              adminName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Super Admin',
                              style: TextStyle(
                                color: Color(0xFFBEC8DA),
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Profile options',
                        iconColor: Colors.white,
                        onSelected: (value) {
                          if (value == 'profile') {
                            onOpenProfile();
                          } else if (value == 'logout') {
                            onSignOut();
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'profile',
                            child: Row(
                              children: [
                                Icon(Icons.person_outline_rounded),
                                SizedBox(width: 10),
                                Text('Profile & Settings'),
                              ],
                            ),
                          ),
                          PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'logout',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.logout_rounded,
                                  color: Colors.redAccent,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Sign Out',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalBrand extends StatelessWidget {
  const _GlobalBrand();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Image.asset(
            'assets/images/logo.png',
            width: 42,
            height: 42,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) {
              return const Icon(
                Icons.auto_awesome_rounded,
                color: AdminWebTheme.gold,
                size: 38,
              );
            },
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NAMA EVENTS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'ADMIN PANEL',
                  style: TextStyle(
                    color: AdminWebTheme.gold,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalTopBar extends StatelessWidget {
  final String pageTitle;
  final String adminName;
  final String profileImageUrl;
  final VoidCallback onOpenProfile;
  final VoidCallback onSignOut;

  const _GlobalTopBar({
    required this.pageTitle,
    required this.adminName,
    required this.profileImageUrl,
    required this.onOpenProfile,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AdminWebTheme.border),
        ),
      ),
      child: Row(
        children: [
          Text(
            pageTitle,
            style: const TextStyle(
              color: AdminWebTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpenProfile,
              borderRadius: BorderRadius.circular(30),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                child: Row(
                  children: [
                    _GlobalAvatar(
                      name: adminName,
                      imageUrl: profileImageUrl,
                    ),
                    const SizedBox(width: 9),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          adminName,
                          style: const TextStyle(
                            color: AdminWebTheme.textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Administrator',
                          style: TextStyle(
                            color: AdminWebTheme.textSecondary,
                            fontSize: 8.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account menu',
            onSelected: (value) {
              if (value == 'profile') {
                onOpenProfile();
              } else if (value == 'logout') {
                onSignOut();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded),
                    SizedBox(width: 10),
                    Text('Profile & Settings'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: Colors.redAccent,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlobalAvatar extends StatelessWidget {
  final String name;
  final String imageUrl;

  const _GlobalAvatar({
    required this.name,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? 'A'
        : name.trim().substring(0, 1).toUpperCase();

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: AdminWebTheme.border,
        ),
      ),
      child: imageUrl.trim().isEmpty
          ? Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: AdminWebTheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : ClipOval(
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: AdminWebTheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
