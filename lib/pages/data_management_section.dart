import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/clothes_item.dart';
import '../models/washer.dart';
import '../services/clothes_services.dart';
import '../services/customer_service.dart';
import '../services/washer_service.dart';
import '../utils/error_utils.dart';
// Data Management Section
class DataManagementSection extends StatefulWidget {
  const DataManagementSection({super.key});

  @override
  State<DataManagementSection> createState() => _DataManagementSectionState();
}

class _DataManagementSectionState extends State<DataManagementSection> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2), text: 'Items'),
            Tab(icon: Icon(Icons.people), text: 'Customers'),
            Tab(icon: Icon(Icons.local_laundry_service), text: 'Washers'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              ItemsManagementTab(),
              CustomersManagementTab(),
              WashersManagementTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class ItemsManagementTab extends StatefulWidget {
  const ItemsManagementTab({super.key});

  @override
  State<ItemsManagementTab> createState() => _ItemsManagementTabState();
}

class _ItemsManagementTabState extends State<ItemsManagementTab> {
  final ClothesService _clothesService = ClothesService(Supabase.instance.client);
  final WasherService _washerService = WasherService(Supabase.instance.client);
  List<ClothesItem> _allItems = []; // All items from database
  List<ClothesItem> _filteredItems = []; // Items after filtering
  List<ClothesItem> _displayedItems = []; // Items for current page
  List<Washer> _washers = [];
  bool _isLoading = true;
  String? _error;
  bool _sortAscending = false; // Default to descending (newest first)
  int _currentPage = 1;
  static const int _itemsPerPage = 5;
  
  // Filter values
  String? _selectedColor;
  String? _selectedBrand;
  String? _selectedType;
  String? _selectedWasherId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    await Future.wait([
      _loadItems(),
      _loadWashers(),
    ]);
  }

  Future<void> _loadItems() async {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final items = await _clothesService.fetchClothes(
        limit: 1000,
        ascending: _sortAscending,
      );
      if (mounted) {
        setState(() {
          _allItems = items;
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = safeErrorToString(e);
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadWashers() async {
    try {
      final washers = await _washerService.fetchWashers(role: 'washer');
      if (mounted) {
        setState(() {
          _washers = washers;
          if (!_isLoading) {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      // Silently fail - washers filter is optional
      if (mounted && !_isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _applyFilters() {
    var filtered = List<ClothesItem>.from(_allItems);
    
    // Filter by color
    if (_selectedColor != null && _selectedColor!.isNotEmpty) {
      filtered = filtered.where((item) => item.color == _selectedColor).toList();
    }
    
    // Filter by brand
    if (_selectedBrand != null && _selectedBrand!.isNotEmpty) {
      filtered = filtered.where((item) => item.brand == _selectedBrand).toList();
    }
    
    // Filter by type
    if (_selectedType != null && _selectedType!.isNotEmpty) {
      filtered = filtered.where((item) => item.type == _selectedType).toList();
    }
    
    // Filter by washer
    if (_selectedWasherId != null && _selectedWasherId!.isNotEmpty) {
      filtered = filtered.where((item) => item.washerId == _selectedWasherId).toList();
    }
    
    setState(() {
      _filteredItems = filtered;
      _currentPage = 1; // Reset to first page when filters change
      _updateDisplayedItems();
      _isLoading = false;
    });
  }
  
  List<String> get _uniqueColors {
    return _allItems.map((item) => item.color).where((color) => color.isNotEmpty).toSet().toList()..sort();
  }
  
  List<String> get _uniqueBrands {
    return _allItems.map((item) => item.brand).where((brand) => brand.isNotEmpty).toSet().toList()..sort();
  }
  
  List<String> get _uniqueTypes {
    return _allItems.map((item) => item.type).where((type) => type.isNotEmpty).toSet().toList()..sort();
  }

  void _updateDisplayedItems() {
    if (_filteredItems.isEmpty) {
      _displayedItems = [];
      return;
    }
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    _displayedItems = _filteredItems.sublist(
      startIndex,
      endIndex > _filteredItems.length ? _filteredItems.length : endIndex,
    );
  }

  int get _totalPages => _filteredItems.isEmpty ? 1 : (_filteredItems.length / _itemsPerPage).ceil();

  void _changePage(int page) {
    if (page >= 1 && page <= _totalPages) {
      setState(() {
        _currentPage = page;
        _updateDisplayedItems();
      });
    }
  }

  void _toggleSortOrder() {
    setState(() {
      _sortAscending = !_sortAscending;
      _currentPage = 1; // Reset to first page
    });
    _loadItems();
  }
  
  void _clearFilters() {
    setState(() {
      _selectedColor = null;
      _selectedBrand = null;
      _selectedType = null;
      _selectedWasherId = null;
      _applyFilters();
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'voided':
      case 'returned':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_allItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No items found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Items will appear here once they are added to the system',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Items (${_filteredItems.length}${_filteredItems.length != _allItems.length ? ' of ${_allItems.length}' : ''})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Row(
                    children: [
                      // Sort order button
                      Tooltip(
                        message: _sortAscending ? 'Sort: Oldest First' : 'Sort: Newest First',
                        child: IconButton(
                          icon: Icon(
                            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                          ),
                          onPressed: _toggleSortOrder,
                          tooltip: _sortAscending ? 'Sort: Oldest First' : 'Sort: Newest First',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadData,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Filters section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.filter_list, size: 20, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Filters',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (_selectedColor != null || _selectedBrand != null || 
                              _selectedType != null || _selectedWasherId != null)
                            TextButton.icon(
                              onPressed: _clearFilters,
                              icon: const Icon(Icons.clear, size: 16),
                              label: const Text('Clear'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          // Color filter
                          SizedBox(
                            width: 150,
                            child: DropdownButtonFormField<String>(
                              value: _selectedColor,
                              decoration: const InputDecoration(
                                labelText: 'Color',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('All Colors'),
                                ),
                                ..._uniqueColors.map((color) => DropdownMenuItem<String>(
                                  value: color,
                                  child: Text(color),
                                )),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedColor = value;
                                  _applyFilters();
                                });
                              },
                            ),
                          ),
                          // Brand filter
                          SizedBox(
                            width: 150,
                            child: DropdownButtonFormField<String>(
                              value: _selectedBrand,
                              decoration: const InputDecoration(
                                labelText: 'Brand',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('All Brands'),
                                ),
                                ..._uniqueBrands.map((brand) => DropdownMenuItem<String>(
                                  value: brand,
                                  child: Text(brand),
                                )),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedBrand = value;
                                  _applyFilters();
                                });
                              },
                            ),
                          ),
                          // Type filter
                          SizedBox(
                            width: 150,
                            child: DropdownButtonFormField<String>(
                              value: _selectedType,
                              decoration: const InputDecoration(
                                labelText: 'Type',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('All Types'),
                                ),
                                ..._uniqueTypes.map((type) => DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(type),
                                )),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedType = value;
                                  _applyFilters();
                                });
                              },
                            ),
                          ),
                          // Washer filter
                          SizedBox(
                            width: 200,
                            child: DropdownButtonFormField<String>(
                              value: _selectedWasherId,
                              decoration: const InputDecoration(
                                labelText: 'Washer',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('All Washers'),
                                ),
                                ..._washers.map((washer) => DropdownMenuItem<String>(
                                  value: washer.id,
                                  child: Text(washer.name),
                                )),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedWasherId = value;
                                  _applyFilters();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Pagination info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Page $_currentPage of $_totalPages',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'Showing ${_displayedItems.length} of ${_filteredItems.length} items',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _filteredItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.filter_alt_off, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No items match the selected filters',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _clearFilters,
                        child: const Text('Clear filters'),
                      ),
                    ],
                  ),
                )
              : _displayedItems.isEmpty
                  ? const Center(
                      child: Text('No items to display'),
                    )
                  : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _displayedItems.length,
                  itemBuilder: (context, index) {
                    final item = _displayedItems[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: item.imageUrl != null
                            ? Image.network(
                                item.imageUrl!,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.image_not_supported),
                              )
                            : const Icon(Icons.inventory_2),
                        title: Text('${item.type} - ${item.brand}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Color: ${item.color}'),
                            if (item.status != null) ...[
                              const SizedBox(height: 4),
                              Chip(
                                label: Text(
                                  item.status!.toUpperCase(),
                                  style: const TextStyle(fontSize: 11, color: Colors.white),
                                ),
                                backgroundColor: _getStatusColor(item.status!),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (item.createdAt != null)
                              Text(
                                DateTime.parse(item.createdAt!)
                                    .toString()
                                    .split(' ')[0],
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        // Pagination controls
        if (_totalPages > 1)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.first_page),
                  onPressed: _currentPage > 1
                      ? () => _changePage(1)
                      : null,
                  tooltip: 'First page',
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 1
                      ? () => _changePage(_currentPage - 1)
                      : null,
                  tooltip: 'Previous page',
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_currentPage / $_totalPages',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _currentPage < _totalPages
                      ? () => _changePage(_currentPage + 1)
                      : null,
                  tooltip: 'Next page',
                ),
                IconButton(
                  icon: const Icon(Icons.last_page),
                  onPressed: _currentPage < _totalPages
                      ? () => _changePage(_totalPages)
                      : null,
                  tooltip: 'Last page',
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class CustomersManagementTab extends StatefulWidget {
  const CustomersManagementTab({super.key});

  @override
  State<CustomersManagementTab> createState() => _CustomersManagementTabState();
}

class _CustomersManagementTabState extends State<CustomersManagementTab> {
  final supabase = Supabase.instance.client;
  final CustomerService _customerService = CustomerService(Supabase.instance.client);
  final WasherService _washerService = WasherService(Supabase.instance.client);
  List<Washer> _customers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final customers = await _customerService.fetchCustomers();
      if (mounted) {
        setState(() {
          _customers = customers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = safeErrorToString(e);
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCustomers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_customers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No customers found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Customers will appear here once they are added to the system',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Customers (${_customers.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadCustomers,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _customers.length,
            itemBuilder: (context, index) {
              final customer = _customers[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?'),
                  ),
                  title: Text(customer.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email: ${customer.email}'),
                      Text('Role: ${customer.role}'),
                      if (customer.phone != null && customer.phone!.isNotEmpty) 
                        Text('Phone: ${customer.phone}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        label: Text(customer.isActive ? 'Active' : 'Inactive'),
                        backgroundColor: customer.isActive ? Colors.green : Colors.grey,
                        labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditCustomerDialog(customer);
                          } else if (value == 'delete') {
                            _deleteCustomer(customer);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showEditCustomerDialog(Washer customer) async {
    final nameController = TextEditingController(text: customer.name);
    final emailController = TextEditingController(text: customer.email);
    final phoneController = TextEditingController(text: customer.phone ?? '');
    bool isActive = customer.isActive;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Customer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  enabled: false, // Email shouldn't be changed
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone (Optional)'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active'),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Prevent user from disabling themselves
                final currentUser = supabase.auth.currentUser;
                if (currentUser != null && customer.id == currentUser.id && !isActive) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You cannot disable your own account'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                  return;
                }

                try {
                  await _customerService.updateCustomer(customer.id!, {
                    'name': nameController.text.trim(),
                    'phone': phoneController.text.trim().isEmpty 
                        ? null 
                        : phoneController.text.trim(),
                    'is_active': isActive,
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Customer updated successfully')),
                    );
                    _loadCustomers();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating customer: ${safeErrorToString(e)}')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _deleteCustomer(Washer customer) async {
    if (customer.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Are you sure you want to delete ${customer.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _customerService.deleteCustomer(customer.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer deleted successfully')),
          );
          _loadCustomers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting customer: ${safeErrorToString(e)}')),
          );
        }
      }
    }
  }
}

class WashersManagementTab extends StatefulWidget {
  const WashersManagementTab({super.key});

  @override
  State<WashersManagementTab> createState() => _WashersManagementTabState();
}

class _WashersManagementTabState extends State<WashersManagementTab> {
  final supabase = Supabase.instance.client;
  final WasherService _washerService = WasherService(Supabase.instance.client);
  List<Washer> _washers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWashers();
  }

  Future<void> _loadWashers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final washers = await _washerService.fetchWashers(role: 'washer');
      if (mounted) {
        setState(() {
          _washers = washers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = safeErrorToString(e);
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadWashers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_washers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_laundry_service_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No washers found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Washers will appear here once they are added to the system',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Washers (${_washers.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadWashers,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _washers.length,
            itemBuilder: (context, index) {
              final washer = _washers[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(washer.name.isNotEmpty ? washer.name[0].toUpperCase() : '?'),
                  ),
                  title: Text(washer.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email: ${washer.email}'),
                      Text('Role: ${washer.role}'),
                      if (washer.createdAt != null)
                        Text(
                          'Created: ${DateTime.parse(washer.createdAt!).toString().split(' ')[0]}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        label: Text(washer.isActive ? 'Active' : 'Inactive'),
                        backgroundColor: washer.isActive ? Colors.green : Colors.grey,
                        labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem(
                            value: 'toggle',
                            child: Text('Toggle Status'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'edit') {
                            // TODO: Implement edit washer
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Edit washer feature coming soon')),
                            );
                          } else if (value == 'toggle') {
                            _toggleWasherStatus(washer);
                          } else if (value == 'delete') {
                            _deleteWasher(washer);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _toggleWasherStatus(Washer washer) async {
    if (washer.id == null) return;
    
    // Prevent user from disabling themselves
    final currentUser = supabase.auth.currentUser;
    if (currentUser != null && washer.id == currentUser.id) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You cannot disable your own account'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    try {
      await _washerService.toggleUserStatus(washer.id!, !washer.isActive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Washer ${washer.isActive ? "disabled" : "enabled"} successfully'),
          ),
        );
        _loadWashers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${safeErrorToString(e)}')),
        );
      }
    }
  }
  

  Future<void> _deleteWasher(Washer washer) async {
    if (washer.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Washer'),
        content: Text('Are you sure you want to delete ${washer.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _washerService.deleteWasher(washer.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Washer deleted successfully')),
          );
          _loadWashers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting washer: ${safeErrorToString(e)}')),
          );
        }
      }
    }
  }
}