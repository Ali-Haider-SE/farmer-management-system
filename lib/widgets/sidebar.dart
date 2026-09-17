import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  final List<String> menuItems;
  final List<IconData> menuIcons;
  final int selectedIndex;
  final Future<void> Function(int index) onItemTap;
  final VoidCallback onLogout;

  const Sidebar({
    super.key,
    required this.menuItems,
    required this.menuIcons,
    required this.selectedIndex,
    required this.onItemTap,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: const Color(0xFF1B5E20),
      child: Column(
        children: [
          const SizedBox(height: 30),

          const Icon(Icons.agriculture, color: Colors.white, size: 48),

          const SizedBox(height: 10),

          const Text(
            'Farmer Management',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 25),

          Expanded(
            child: ListView.builder(
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final selected = selectedIndex == index;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  child: Material(
                    color: selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: Icon(
                        menuIcons[index],
                        color: selected
                            ? const Color(0xFF1B5E20)
                            : Colors.white,
                      ),
                      title: Text(
                        menuItems[index],
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF1B5E20)
                              : Colors.white,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      onTap: () => onItemTap(index),
                    ),
                  ),
                );
              },
            ),
          ),

          // =================================================
          // LOGOUT
          // =================================================
          const Divider(color: Colors.white24, height: 1),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.white),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: onLogout,
              ),
            ),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
