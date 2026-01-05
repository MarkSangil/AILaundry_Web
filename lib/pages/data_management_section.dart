import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/clothes_item.dart';
import '../models/washer.dart';
import '../models/status_history.dart';
import '../services/clothes_services.dart';
import '../services/customer_service.dart';
import '../services/washer_service.dart';
import '../services/status_history_service.dart';
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

class _ItemsManagementTabState extends State<ItemsManagementTab> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final ClothesService _clothesService = ClothesService(Supabase.instance.client);
  final WasherService _washerService = WasherService(Supabase.instance.client);
  final StatusHistoryService _statusHistoryService = StatusHistoryService(Supabase.instance.client);
  late TabController _archiveTabController;
  
  List<ClothesItem> _allItems = []; // All items from database
  List<ClothesItem> _allArchivedItems = []; // All archived items from database
  List<ClothesItem> _filteredItems = []; // Items after filtering
  List<ClothesItem> _displayedItems = []; // Items for current page
  List<Washer> _washers = [];
  bool _isLoading = true;
  String? _error;
  bool _sortAscending = false; // Default to descending (newest first)
  int _currentPage = 1;
  static const int _itemsPerPage = 5;
  bool _showArchived = false; // Track which tab is active
  
  // Bulk editing
  Set<String> _selectedItemIds = {}; // Selected item IDs for bulk operations
  bool _isSelectionMode = false; // Whether selection mode is active
  
  // Filter values
  String? _selectedColor;
  String? _selectedBrand;
  String? _selectedType;
  String? _selectedWasherId;

  @override
  void initState() {
    super.initState();
    _archiveTabController = TabController(length: 2, vsync: this);
    _archiveTabController.addListener(() {
      if (_archiveTabController.indexIsChanging) {
        setState(() {
          _showArchived = _archiveTabController.index == 1;
          _currentPage = 1;
          _applyFilters();
        });
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _archiveTabController.dispose();
    super.dispose();
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
      // Load both active and archived items
      final activeItems = await _clothesService.fetchClothes(
        limit: 1000,
        ascending: _sortAscending,
        includeArchived: false,
      );
      final archivedItems = await _clothesService.fetchClothes(
        limit: 1000,
        ascending: _sortAscending,
        includeArchived: true,
      );
      if (mounted) {
        setState(() {
          _allItems = activeItems;
          _allArchivedItems = archivedItems;
          _isLoading = false;
        });
        // Apply filters after state is updated
        _applyFilters();
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
    // Use the appropriate list based on active/archived tab
    var sourceList = _showArchived ? _allArchivedItems : _allItems;
    var filtered = List<ClothesItem>.from(sourceList);
    
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
    final sourceList = _showArchived ? _allArchivedItems : _allItems;
    return sourceList.map((item) => item.color).where((color) => color.isNotEmpty).toSet().toList()..sort();
  }
  
  List<String> get _uniqueBrands {
    final sourceList = _showArchived ? _allArchivedItems : _allItems;
    return sourceList.map((item) => item.brand).where((brand) => brand.isNotEmpty).toSet().toList()..sort();
  }
  
  List<String> get _uniqueTypes {
    final sourceList = _showArchived ? _allArchivedItems : _allItems;
    return sourceList.map((item) => item.type).where((type) => type.isNotEmpty).toSet().toList()..sort();
  }

  void _updateDisplayedItems() {
    if (_filteredItems.isEmpty) {
      _displayedItems = [];
    } else {
      final startIndex = (_currentPage - 1) * _itemsPerPage;
      final endIndex = startIndex + _itemsPerPage;
      _displayedItems = _filteredItems.sublist(
        startIndex,
        endIndex > _filteredItems.length ? _filteredItems.length : endIndex,
      );
    }
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
      case 'pending_check':
        return Colors.orange;
      case 'voided':
      case 'returned':
        return Colors.red;
      case 'archived':
      case 'deleted':
        return Colors.orange.shade700; // Different shade for archived items
      default:
        return Colors.grey;
    }
  }

  Future<void> _archiveItem(String itemId) async {
    try {
      await _clothesService.updateItem(itemId, {'status': 'archived'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item archived successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadItems();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error archiving item: ${safeErrorToString(e)}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _unarchiveItem(String itemId) async {
    await _restoreItem(itemId);
  }

  Future<void> _restoreItem(String itemId) async {
    try {
      // Get current user for audit trail
      final currentUser = supabase.auth.currentUser;
      final userId = currentUser?.id;
      
      // Check if this is the last archived item
      final wasLastArchivedItem = _showArchived && _allArchivedItems.length == 1;
      
      // Restore the item
      await _clothesService.restoreItem(itemId);
      
      // Log to audit trail (if audit table exists)
      if (userId != null) {
        try {
          // Try to insert audit log - silently fail if table doesn't exist
          await supabase.from('item_audit_log').insert({
            'item_id': itemId,
            'action': 'restore',
            'user_id': userId,
            'metadata': {
              'restored_at': DateTime.now().toIso8601String(),
              'restored_by': userId,
            },
            'created_at': DateTime.now().toIso8601String(),
          }).catchError((e) {
          });
        } catch (e) {
        }
      }
      
      if (mounted) {
        // Reload items to get updated lists
        await _loadItems();
        
        // If this was the last archived item and we're on the archived tab,
        // switch to the active tab to show the restored item
        if (wasLastArchivedItem && _showArchived) {
          // Wait a bit for state to update, then switch tabs
          await Future.delayed(const Duration(milliseconds: 50));
          if (mounted && _allArchivedItems.isEmpty) {
            // Switch to Active tab
            _archiveTabController.animateTo(0);
            // Update state to reflect tab change and refresh display
            setState(() {
              _showArchived = false;
              _currentPage = 1;
            });
            // Re-apply filters for active items
            _applyFilters();
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item restored successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restoring item: ${safeErrorToString(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditItemDialog(ClothesItem item) async {
    final typeController = TextEditingController(text: item.type);
    final brandController = TextEditingController(text: item.brand);
    final colorController = TextEditingController(text: item.color);
    
    // Get all valid status options
    final validStatuses = [
      null,
      'approved',
      'pending',
      'pending_check',
      'voided',
      'returned',
      'archived',
      'deleted',
    ];
    
    // Ensure selectedStatus is in the valid list, otherwise set to null
    String? selectedStatus = validStatuses.contains(item.status) ? item.status : null;
    String? selectedWasherId = item.washerId;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: typeController,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: brandController,
                  decoration: const InputDecoration(
                    labelText: 'Brand',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: colorController,
                  decoration: const InputDecoration(
                    labelText: 'Color',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('No Status')),
                    DropdownMenuItem(value: 'approved', child: Text('Approved')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'pending_check', child: Text('Pending Check')),
                    DropdownMenuItem(value: 'voided', child: Text('Voided')),
                    DropdownMenuItem(value: 'returned', child: Text('Returned')),
                    DropdownMenuItem(value: 'archived', child: Text('Archived')),
                    DropdownMenuItem(value: 'deleted', child: Text('Deleted')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedStatus = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedWasherId,
                  decoration: const InputDecoration(
                    labelText: 'Washer (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('No Washer'),
                    ),
                    ..._washers.map((washer) => DropdownMenuItem<String>(
                      value: washer.id,
                      child: Text(washer.name),
                    )),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedWasherId = value;
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
                try {
                  // Build updates map - only include non-empty values
                  final updates = <String, dynamic>{};
                  
                  final type = typeController.text.trim();
                  final brand = brandController.text.trim();
                  final color = colorController.text.trim();
                  
                  if (type.isNotEmpty) updates['type'] = type;
                  if (brand.isNotEmpty) updates['brand'] = brand;
                  if (color.isNotEmpty) updates['color'] = color;
                  if (selectedStatus != null) updates['status'] = selectedStatus;
                  if (selectedWasherId != null) updates['washer_id'] = selectedWasherId;

                  if (updates.isEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No changes to save'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                    return;
                  }
                  await _clothesService.updateItem(item.id, updates);
                  
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Item updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    await _loadItems();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating item: ${safeErrorToString(e)}'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
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

  Future<void> _showStatusHistoryDialog(ClothesItem item) async {
    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Fetch status history
      final history = await _statusHistoryService.getStatusHistory(item.id);

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Show history dialog
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Status History: ${item.type} - ${item.brand}'),
            content: SizedBox(
              width: double.maxFinite,
              child: history.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'No status history found for this item.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final entry = history[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getStatusColor(entry.newStatus),
                              child: const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                            ),
                            title: Row(
                              children: [
                                if (entry.oldStatus != null) ...[
                                  Chip(
                                    label: Text(
                                      entry.oldStatus!.toUpperCase(),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    backgroundColor: Colors.grey.shade300,
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(Icons.arrow_forward, size: 16),
                                  ),
                                ],
                                Chip(
                                  label: Text(
                                    entry.newStatus.toUpperCase(),
                                    style: const TextStyle(fontSize: 10, color: Colors.white),
                                  ),
                                  backgroundColor: _getStatusColor(entry.newStatus),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (entry.createdAt != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDateTime(entry.createdAt!),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                                if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Note: ${entry.notes}',
                                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ],
                            ),
                            isThreeLine: entry.notes != null && entry.notes!.isNotEmpty,
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading status history: ${safeErrorToString(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeString;
    }
  }

  Future<void> _deleteItem(String itemId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item Permanently'),
        content: const Text(
          'Are you sure you want to permanently delete this item? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _clothesService.deleteItem(itemId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item deleted permanently'),
            backgroundColor: Colors.red,
          ),
        );
        await _loadItems();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting item: ${safeErrorToString(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Bulk editing methods
  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedItemIds.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedItemIds.clear();
    });
  }

  void _selectAllOnPage() {
    setState(() {
      for (var item in _displayedItems) {
        _selectedItemIds.add(item.id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedItemIds.clear();
    });
  }

  Future<void> _bulkArchive() async {
    if (_selectedItemIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Items'),
        content: Text('Are you sure you want to archive ${_selectedItemIds.length} item(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      int successCount = 0;
      int failCount = 0;

      for (var itemId in _selectedItemIds) {
        try {
          // Use updateItem directly to ensure status is updated
          await _clothesService.updateItem(itemId, {'status': 'archived'});
          successCount++;
        } catch (e) {
          failCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failCount > 0
                  ? 'Archived $successCount item(s). $failCount failed.'
                  : 'Successfully archived $successCount item(s).',
            ),
            backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        _exitSelectionMode();
        await _loadItems();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during bulk archive: ${safeErrorToString(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _bulkRestore() async {
    if (_selectedItemIds.isEmpty) return;

    // One-click bulk restore - no confirmation needed for restore
    try {
      final currentUser = supabase.auth.currentUser;
      final userId = currentUser?.id;
      
      int successCount = 0;
      int failCount = 0;

      for (var itemId in _selectedItemIds) {
        try {
          await _clothesService.restoreItem(itemId);
          
          // Log to audit trail
          if (userId != null) {
            try {
              await supabase.from('item_audit_log').insert({
                'item_id': itemId,
                'action': 'restore',
                'user_id': userId,
                'metadata': {
                  'restored_at': DateTime.now().toIso8601String(),
                  'restored_by': userId,
                  'bulk_operation': true,
                },
                'created_at': DateTime.now().toIso8601String(),
              }).catchError((e) {
              });
            } catch (e) {
            }
          }
          
          successCount++;
        } catch (e) {
          failCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failCount > 0
                  ? 'Restored $successCount item(s). $failCount failed.'
                  : 'Successfully restored $successCount item(s).',
            ),
            backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        _exitSelectionMode();
        await _loadItems();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during bulk restore: ${safeErrorToString(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _bulkDelete() async {
    if (_selectedItemIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Items Permanently'),
        content: Text(
          'Are you sure you want to permanently delete ${_selectedItemIds.length} item(s)?\n\n'
          'This action cannot be undone. Items will be permanently removed from the database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      int successCount = 0;
      int failCount = 0;

      for (var itemId in _selectedItemIds) {
        try {
          await _clothesService.deleteItem(itemId);
          successCount++;
        } catch (e) {
          failCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failCount > 0
                  ? 'Deleted $successCount item(s). $failCount failed.'
                  : 'Successfully deleted $successCount item(s) permanently.',
            ),
            backgroundColor: failCount > 0 ? Colors.orange : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        _exitSelectionMode();
        await _loadItems();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during bulk delete: ${safeErrorToString(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showBulkEditDialog() async {
    if (_selectedItemIds.isEmpty) return;
    final widgetContext = context;
    
    String? selectedStatus;
    String? selectedWasherId;
    await showDialog(
      context: widgetContext,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Bulk Edit ${_selectedItemIds.length} Item(s)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Update the following fields for all selected items. Leave unchanged to keep current values.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status (Optional)',
                    border: OutlineInputBorder(),
                    helperText: 'Leave unchanged to keep current status',
                  ),
                  items: const [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text('Keep Current Status'),
                    ),
                    DropdownMenuItem(value: 'approved', child: Text('Approved')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'pending_check', child: Text('Pending Check')),
                    DropdownMenuItem(value: 'voided', child: Text('Voided')),
                    DropdownMenuItem(value: 'returned', child: Text('Returned')),
                    DropdownMenuItem(value: 'archived', child: Text('Archived')),
                    DropdownMenuItem(value: 'deleted', child: Text('Deleted')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedStatus = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedWasherId,
                  decoration: const InputDecoration(
                    labelText: 'Washer (Optional)',
                    border: OutlineInputBorder(),
                    helperText: 'Leave unchanged to keep current washer',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Keep Current Washer / No Washer'),
                    ),
                    ..._washers.map((washer) => DropdownMenuItem<String>(
                      value: washer.id,
                      child: Text(washer.name),
                    )),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedWasherId = value;
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
                // Build updates map - only include fields that were changed
                final updates = <String, dynamic>{};
                if (selectedStatus != null) {
                  updates['status'] = selectedStatus;
                }
                if (selectedWasherId != null) {
                  updates['washer_id'] = selectedWasherId;
                }

                // If no changes, just close
                if (updates.isEmpty) {
                  Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(widgetContext).showSnackBar(
                      const SnackBar(
                        content: Text('No changes to apply'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                  return;
                }

                // Close the bulk edit dialog first
                Navigator.pop(context);

                // Show progress dialog using widget's context
                if (!mounted) return;
                showDialog(
                  context: widgetContext,
                  barrierDismissible: false,
                  builder: (dialogContext) => WillPopScope(
                    onWillPop: () async => false,
                    child: AlertDialog(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text('Updating ${_selectedItemIds.length} item(s)...'),
                        ],
                      ),
                    ),
                  ),
                );

                try {
                  int successCount = 0;
                  int failCount = 0;

                  for (var itemId in _selectedItemIds) {
                    try {
                      await _clothesService.updateItem(itemId, updates);
                      successCount++;
                    } catch (e) {
                      failCount++;
                    }
                  }

                  if (mounted) {
                    Navigator.of(widgetContext, rootNavigator: true).pop();
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(widgetContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          failCount > 0
                              ? 'Updated $successCount item(s). $failCount failed.'
                              : 'Successfully updated $successCount item(s).',
                        ),
                        backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                    _exitSelectionMode();
                    await _loadItems();
                  }
                } catch (e) {
                  // Close progress dialog using widget's context
                  if (mounted) {
                    Navigator.of(widgetContext, rootNavigator: true).pop();
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(widgetContext).showSnackBar(
                      SnackBar(
                        content: Text('Error during bulk edit: ${safeErrorToString(e)}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Apply Changes'),
            ),
          ],
        ),
      ),
    );
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

    final sourceList = _showArchived ? _allArchivedItems : _allItems;
    if (sourceList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showArchived ? Icons.archive_outlined : Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _showArchived ? 'No archived items found' : 'No items found',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              _showArchived
                  ? 'Archived items will appear here'
                  : 'Items will appear here once they are added to the system',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Active/Archived Tab Bar
        TabBar(
          controller: _archiveTabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.inventory_2),
              text: 'Active (${_allItems.length})',
            ),
            Tab(
              icon: const Icon(Icons.archive),
              text: 'Archived (${_allArchivedItems.length})',
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isSelectionMode
                        ? '${_selectedItemIds.length} selected'
                        : '${_showArchived ? "Archived" : "Active"} Items (${_filteredItems.length}${_filteredItems.length != (_showArchived ? _allArchivedItems.length : _allItems.length) ? ' of ${_showArchived ? _allArchivedItems.length : _allItems.length}' : ''})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Row(
                    children: [
                      if (_isSelectionMode) ...[
                        // Bulk action buttons
                        TextButton.icon(
                          onPressed: _selectedItemIds.isEmpty ? null : _selectAllOnPage,
                          icon: const Icon(Icons.select_all, size: 18),
                          label: const Text('Select All'),
                        ),
                        TextButton.icon(
                          onPressed: _selectedItemIds.isEmpty ? null : _clearSelection,
                          icon: const Icon(Icons.clear_all, size: 18),
                          label: const Text('Clear'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _selectedItemIds.isEmpty ? null : _showBulkEditDialog,
                          icon: const Icon(Icons.edit, size: 18),
                          label: Text('Bulk Edit (${_selectedItemIds.length})'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!_showArchived)
                          ElevatedButton.icon(
                            onPressed: _selectedItemIds.isEmpty ? null : _bulkArchive,
                            icon: const Icon(Icons.archive, size: 18),
                            label: Text('Archive (${_selectedItemIds.length})'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        if (_showArchived) ...[
                          ElevatedButton.icon(
                            onPressed: _selectedItemIds.isEmpty ? null : _bulkRestore,
                            icon: const Icon(Icons.restore, size: 18),
                            label: Text('Restore (${_selectedItemIds.length})'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _selectedItemIds.isEmpty ? null : _bulkDelete,
                            icon: const Icon(Icons.delete_forever, size: 18),
                            label: Text('Delete (${_selectedItemIds.length})'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _exitSelectionMode,
                          tooltip: 'Exit Selection',
                        ),
                      ] else ...[
                        // Normal mode buttons
                        IconButton(
                          icon: const Icon(Icons.checklist),
                          onPressed: _enterSelectionMode,
                          tooltip: 'Bulk Edit',
                        ),
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
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // Calculate responsive widths based on available space
                          final availableWidth = constraints.maxWidth;
                          final isWideScreen = availableWidth > 800;
                          final isMediumScreen = availableWidth > 600;
                          
                          // Use flexible widths that adapt to screen size
                          final colorWidth = isWideScreen ? 140.0 : isMediumScreen ? 120.0 : double.infinity;
                          final brandWidth = isWideScreen ? 140.0 : isMediumScreen ? 120.0 : double.infinity;
                          final typeWidth = isWideScreen ? 140.0 : isMediumScreen ? 120.0 : double.infinity;
                          final washerWidth = isWideScreen ? 180.0 : isMediumScreen ? 160.0 : double.infinity;
                          
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              // Color filter
                              SizedBox(
                                width: colorWidth == double.infinity ? null : colorWidth,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedColor,
                                  decoration: InputDecoration(
                                    labelText: 'Color',
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    isDense: true,
                                    isCollapsed: false,
                                  ),
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('All Colors', overflow: TextOverflow.ellipsis),
                                    ),
                                    ..._uniqueColors.map((color) => DropdownMenuItem<String>(
                                      value: color,
                                      child: Text(color, overflow: TextOverflow.ellipsis),
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
                                width: brandWidth == double.infinity ? null : brandWidth,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedBrand,
                                  decoration: InputDecoration(
                                    labelText: 'Brand',
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    isDense: true,
                                    isCollapsed: false,
                                  ),
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('All Brands', overflow: TextOverflow.ellipsis),
                                    ),
                                    ..._uniqueBrands.map((brand) => DropdownMenuItem<String>(
                                      value: brand,
                                      child: Text(brand, overflow: TextOverflow.ellipsis),
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
                                width: typeWidth == double.infinity ? null : typeWidth,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedType,
                                  decoration: InputDecoration(
                                    labelText: 'Type',
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    isDense: true,
                                    isCollapsed: false,
                                  ),
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('All Types', overflow: TextOverflow.ellipsis),
                                    ),
                                    ..._uniqueTypes.map((type) => DropdownMenuItem<String>(
                                      value: type,
                                      child: Text(type, overflow: TextOverflow.ellipsis),
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
                                width: washerWidth == double.infinity ? null : washerWidth,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedWasherId,
                                  decoration: InputDecoration(
                                    labelText: 'Washer',
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    isDense: true,
                                    isCollapsed: false,
                                  ),
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('All Washers', overflow: TextOverflow.ellipsis),
                                    ),
                                    ..._washers.map((washer) => DropdownMenuItem<String>(
                                      value: washer.id,
                                      child: Text(washer.name, overflow: TextOverflow.ellipsis),
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
                          );
                        },
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
                    final isArchived = item.status == 'archived' || 
                                      item.status == 'voided' || 
                                      item.status == 'deleted';
                    final isSelected = _selectedItemIds.contains(item.id);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3) : null,
                      child: ListTile(
                        leading: _isSelectionMode
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedItemIds.add(item.id);
                                    } else {
                                      _selectedItemIds.remove(item.id);
                                    }
                                  });
                                },
                              )
                            : (item.imageUrl != null
                                ? Image.network(
                                    item.imageUrl!,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.image_not_supported),
                                  )
                                : const Icon(Icons.inventory_2)),
                        title: Text('${item.type} - ${item.brand}'),
                        onTap: _isSelectionMode
                            ? () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedItemIds.remove(item.id);
                                  } else {
                                    _selectedItemIds.add(item.id);
                                  }
                                });
                              }
                            : null,
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
                        trailing: _isSelectionMode
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (item.createdAt != null)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(
                                        DateTime.parse(item.createdAt!)
                                            .toString()
                                            .split(' ')[0],
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ),
                                  // One-click restore button for archived items
                                  if (isArchived && !_isSelectionMode)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: IconButton(
                                        icon: const Icon(Icons.restore, color: Colors.green),
                                        onPressed: () => _restoreItem(item.id),
                                        tooltip: 'Restore Item',
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.green.withOpacity(0.1),
                                        ),
                                      ),
                                    ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) async {
                                      if (value == 'edit') {
                                        await _showEditItemDialog(item);
                                      } else if (value == 'history') {
                                        await _showStatusHistoryDialog(item);
                                      } else if (value == 'archive') {
                                        await _archiveItem(item.id);
                                      } else if (value == 'restore' || value == 'unarchive') {
                                        await _restoreItem(item.id);
                                      } else if (value == 'delete') {
                                        await _deleteItem(item.id);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 20, color: Colors.blue),
                                            SizedBox(width: 8),
                                            Text('Edit'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'history',
                                        child: Row(
                                          children: [
                                            Icon(Icons.history, size: 20, color: Colors.purple),
                                            SizedBox(width: 8),
                                            Text('View History'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuDivider(),
                                      if (isArchived) ...[
                                        const PopupMenuItem(
                                          value: 'restore',
                                          child: Row(
                                            children: [
                                              Icon(Icons.restore, size: 20, color: Colors.green),
                                              SizedBox(width: 8),
                                              Text('Restore'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuDivider(),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_forever, size: 20, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Delete Permanently'),
                                            ],
                                          ),
                                        ),
                                      ] else ...[
                                        const PopupMenuItem(
                                          value: 'archive',
                                          child: Row(
                                            children: [
                                              Icon(Icons.archive, size: 20, color: Colors.orange),
                                              SizedBox(width: 8),
                                              Text('Archive'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
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