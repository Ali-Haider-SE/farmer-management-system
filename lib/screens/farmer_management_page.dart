import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/farmer_model.dart';
import '../providers/farmer_provider.dart';

class FarmerManagementPage extends StatelessWidget {
  const FarmerManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FarmerProvider(),
      child: const _FarmerManagementContent(),
    );
  }
}

class _FarmerManagementContent extends StatefulWidget {
  const _FarmerManagementContent();

  @override
  State<_FarmerManagementContent> createState() => _FarmerManagementPageState();
}

class _FarmerManagementPageState extends State<_FarmerManagementContent> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context.read<FarmerProvider>().loadFarmers();
    });

    _searchController.addListener(() {
      if (!mounted) return;

      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FarmerModel> _filteredFarmers(FarmerProvider provider) {
    final query = _searchQuery;

    if (query.isEmpty) {
      return provider.farmers;
    }

    return provider.farmers.where((farmer) {
      return farmer.name.toLowerCase().contains(query) ||
          farmer.fatherName.toLowerCase().contains(query) ||
          farmer.phone.toLowerCase().contains(query) ||
          farmer.address.toLowerCase().contains(query) ||
          (farmer.cnic ?? '').toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _showFarmerDialog({FarmerModel? farmer}) async {
    final nameController = TextEditingController(text: farmer?.name ?? '');

    final fatherNameController = TextEditingController(
      text: farmer?.fatherName ?? '',
    );

    final phoneController = TextEditingController(text: farmer?.phone ?? '');

    final addressController = TextEditingController(
      text: farmer?.address ?? '',
    );

    final cnicController = TextEditingController(text: farmer?.cnic ?? '');

    bool isActive = farmer?.isActive ?? true;

    final formKey = GlobalKey<FormState>();

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(farmer == null ? 'Add Farmer' : 'Edit Farmer'),
                content: SizedBox(
                  width: 500,
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: nameController,
                            autofocus: true,
                            decoration: const InputDecoration(
                              labelText: 'Farmer Name *',
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Farmer name is required';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: fatherNameController,
                            decoration: const InputDecoration(
                              labelText: 'Father Name',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                              prefixIcon: Icon(Icons.phone),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: addressController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Address',
                              prefixIcon: Icon(Icons.location_on),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: cnicController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'CNIC',
                              prefixIcon: Icon(Icons.badge),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Active Farmer'),
                            value: isActive,
                            onChanged: (value) {
                              setDialogState(() {
                                isActive = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    icon: Icon(farmer == null ? Icons.add : Icons.save),
                    label: Text(farmer == null ? 'Add Farmer' : 'Save Changes'),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }

                      final provider = context.read<FarmerProvider>();

                      final newFarmer = FarmerModel(
                        id: farmer?.id ?? '',
                        name: nameController.text.trim(),
                        fatherName: fatherNameController.text.trim(),
                        phone: phoneController.text.trim(),
                        address: addressController.text.trim(),
                        cnic: cnicController.text.trim().isEmpty
                            ? null
                            : cnicController.text.trim(),
                        isActive: isActive,
                      );

                      bool success;

                      if (farmer == null) {
                        success = await provider.addFarmer(newFarmer);
                      } else {
                        success = await provider.updateFarmer(newFarmer);
                      }

                      if (!dialogContext.mounted) {
                        return;
                      }

                      if (success) {
                        Navigator.of(dialogContext).pop();

                        if (!mounted) {
                          return;
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              farmer == null
                                  ? 'Farmer added successfully'
                                  : 'Farmer updated successfully',
                            ),
                          ),
                        );
                      } else {
                        if (!mounted) {
                          return;
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(provider.error ?? 'Operation failed'),
                          ),
                        );
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      fatherNameController.dispose();
      phoneController.dispose();
      addressController.dispose();
      cnicController.dispose();
    }
  }

  Future<void> _deleteFarmer(FarmerModel farmer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Farmer'),
          content: Text('Are you sure you want to delete "${farmer.name}"?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final provider = context.read<FarmerProvider>();

    final success = await provider.deleteFarmer(farmer.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Farmer deleted successfully'
              : provider.error ?? 'Failed to delete farmer',
        ),
      ),
    );
  }

  Widget _buildFarmerCard(FarmerModel farmer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: farmer.isActive
                  ? const Color(0xFF1B5E20)
                  : Colors.grey,
              child: Text(
                farmer.name.isEmpty ? '?' : farmer.name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    farmer.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (farmer.fatherName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Father: ${farmer.fatherName}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  if (farmer.phone.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text('Phone: ${farmer.phone}'),
                    ),
                  if (farmer.address.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        'Address: ${farmer.address}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if ((farmer.cnic ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text('CNIC: ${farmer.cnic}'),
                    ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: farmer.isActive
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      farmer.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: farmer.isActive
                            ? Colors.green.shade800
                            : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showFarmerDialog(farmer: farmer);
                } else if (value == 'delete') {
                  _deleteFarmer(farmer);
                }
              },
              itemBuilder: (context) {
                return const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Edit'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('Delete'),
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FarmerProvider>(
      builder: (context, provider, _) {
        final farmers = _filteredFarmers(provider);

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Farmer Management',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Manage farmer records',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          _showFarmerDialog();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Farmer'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name, father name, phone or CNIC...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (provider.error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              provider.error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                          IconButton(
                            onPressed: provider.clearError,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: provider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : farmers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 70,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'No farmers found'
                                      : 'No matching farmers found',
                                  style: TextStyle(
                                    fontSize: 17,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (_searchQuery.isEmpty)
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      _showFarmerDialog();
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add First Farmer'),
                                  ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: provider.loadFarmers,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: farmers.length,
                              itemBuilder: (context, index) {
                                return _buildFarmerCard(farmers[index]);
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
