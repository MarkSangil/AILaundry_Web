import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dispute.dart';
import '../services/dispute_service.dart';
import '../utils/error_utils.dart';

class DisputeResolutionCenter extends StatefulWidget {
  const DisputeResolutionCenter({super.key});

  @override
  State<DisputeResolutionCenter> createState() => _DisputeResolutionCenterState();
}

class _DisputeResolutionCenterState extends State<DisputeResolutionCenter> {
  final supabase = Supabase.instance.client;
  final DisputeService _disputeService = DisputeService(Supabase.instance.client);
  
  List<Dispute> _disputes = [];
  List<Dispute> _filteredDisputes = [];
  bool _isLoading = true;
  String _sortBy = 'age'; // age or urgency
  String _statusFilter = 'all'; // all, pending, resolved, rejected
  Dispute? _selectedDispute;
  List<Map<String, dynamic>> _similarItems = [];
  Map<String, dynamic>? _disputedItem; // The disputed item details
  Map<String, dynamic>? _relatedWasher; // The washer who handled the item
  bool _loadingItemDetails = false;

  @override
  void initState() {
    super.initState();
    _loadDisputes();
  }

  Future<void> _loadDisputes() async {
    setState(() => _isLoading = true);
    try {
      final disputes = await _disputeService.fetchDisputes();
      setState(() {
        _disputes = disputes;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading disputes: ${safeErrorToString(e)}')),
        );
      }
    }
  }

  void _applyFilters() {
    var filtered = _disputes;

    if (_statusFilter != 'all') {
      filtered = filtered.where((d) => d.status == _statusFilter).toList();
    }

    if (_sortBy == 'age') {
      filtered.sort((a, b) {
        final aDate = a.createdAt ?? '';
        final bDate = b.createdAt ?? '';
        return bDate.compareTo(aDate); // Newest first
      });
    }

    setState(() => _filteredDisputes = filtered);
  }

  Future<void> _selectDispute(Dispute dispute) async {
    setState(() {
      _selectedDispute = dispute;
      _disputedItem = null;
      _relatedWasher = null;
      _similarItems = [];
      _loadingItemDetails = true;
    });

    if (dispute.itemId != null && dispute.id != null) {
      try {
        // Load disputed item details
        final itemResponse = await supabase
            .from('clothes')
            .select()
            .eq('id', dispute.itemId!)
            .maybeSingle();
        
        Map<String, dynamic>? washerData;
        
        if (itemResponse != null) {
          setState(() => _disputedItem = itemResponse);
          
          // Load washer information if washer_id exists
          if (itemResponse['washer_id'] != null) {
            try {
              final washerResponse = await supabase
                  .from('laundry_users')
                  .select()
                  .eq('id', itemResponse['washer_id'])
                  .maybeSingle();
              
              if (washerResponse != null) {
                washerData = washerResponse;
              }
            } catch (e) {
            }
          }
        }
        
        // Load similar items
        final similar = await _disputeService.getSimilarItems(dispute.id!);
        
        // Reload dispute to get latest matched_item_id
        final updatedDisputeResponse = await supabase
            .from('disputes')
            .select()
            .eq('id', dispute.id!)
            .maybeSingle();
        
        Dispute? updatedDispute;
        if (updatedDisputeResponse != null) {
          updatedDispute = Dispute.fromMap(updatedDisputeResponse);
        }
        
        setState(() {
          _similarItems = similar;
          _relatedWasher = washerData;
          _selectedDispute = updatedDispute ?? dispute;
          _loadingItemDetails = false;
        });
      } catch (e) {
        setState(() => _loadingItemDetails = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading item details: ${safeErrorToString(e)}')),
          );
        }
      }
    } else {
      setState(() => _loadingItemDetails = false);
    }
  }

  Future<void> _resolveDispute(String id, String status, String? notes) async {
    try {
      // Get the dispute before updating to get customer_id
      final dispute = _disputes.firstWhere((d) => d.id == id);
      
      await _disputeService.updateDisputeStatus(id, status, resolutionNotes: notes);
      
      // Automatically create notification for the customer
      if (dispute.customerId != null) {
        try {
          String disputeTypeLabel;
          switch (dispute.type) {
            case 'missing':
              disputeTypeLabel = 'Missing Item';
              break;
            case 'duplicate':
              disputeTypeLabel = 'Duplicate Item';
              break;
            case 'wrong_clothes':
              disputeTypeLabel = 'Wrong Clothes';
              break;
            default:
              disputeTypeLabel = dispute.type;
          }

          String statusLabel;
          switch (status) {
            case 'pending':
              statusLabel = 'Pending Review';
              break;
            case 'reviewing':
              statusLabel = 'Under Review';
              break;
            case 'resolved':
              statusLabel = 'Resolved';
              break;
            case 'rejected':
              statusLabel = 'Rejected';
              break;
            default:
              statusLabel = status;
          }

          String notificationMessage;
          if (notes != null && notes.isNotEmpty) {
            notificationMessage = 'Your dispute "${disputeTypeLabel}" has been updated to ${statusLabel}. $notes';
          } else {
            notificationMessage = 'Your dispute "${disputeTypeLabel}" status has been updated to ${statusLabel}.';
          }

          await supabase.from('notifications').insert({
            'user_id': dispute.customerId!,
            'title': 'Dispute Update',
            'message': notificationMessage,
            'type': 'dispute',
            'related_id': id,
            'related_type': 'dispute',
            'is_read': false,
          });
        } catch (e) {
        }
      }
      
      await _loadDisputes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dispute $status successfully. Customer has been notified.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${safeErrorToString(e)}')),
        );
      }
    }
  }

  void _showImageDialog(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('Image not available'),
                        ],
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _matchItemToDispute(String matchedItemId) async {
    if (_selectedDispute == null || _selectedDispute!.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No dispute selected'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Match the item to the dispute
      final updatedDispute = await _disputeService.matchItemToDispute(
        _selectedDispute!.id!,
        matchedItemId,
        resolutionNotes: 'Item matched by admin',
      );

      // Update the selected dispute
      setState(() {
        _selectedDispute = updatedDispute;
      });

      // Reload disputes list to show updated match status
      await _loadDisputes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item matched successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error matching item: ${safeErrorToString(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _notifyCustomer(Dispute dispute) async {
    if (dispute.customerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This dispute is from an unauthenticated user. Please contact them via alaundryai@gmail.com'),
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    try {
      // Fetch customer information
      final customerResponse = await supabase
          .from('laundry_users')
          .select('id, name, email')
          .eq('id', dispute.customerId!)
          .maybeSingle();

      if (customerResponse == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer not found')),
          );
        }
        return;
      }

      final customerName = customerResponse['name'] as String? ?? 'Customer';
      final customerEmail = customerResponse['email'] as String? ?? '';

      // Show notification dialog with customer info
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Notify Customer'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer: $customerName'),
                const SizedBox(height: 16),
                const Text(
                  'An in-app notification will be sent to the customer about this dispute update.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The customer will see this notification when they open the mobile app.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _sendCustomerNotification(dispute, customerEmail, customerName);
                },
                child: const Text('Send Notification'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching customer info: ${safeErrorToString(e)}')),
        );
      }
    }
  }

  Future<void> _sendCustomerNotification(
    Dispute dispute,
    String customerEmail,
    String customerName,
  ) async {
    if (dispute.customerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot send notification: Customer ID not found'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // Get dispute type label
      String disputeTypeLabel;
      switch (dispute.type) {
        case 'missing':
          disputeTypeLabel = 'Missing Item';
          break;
        case 'duplicate':
          disputeTypeLabel = 'Duplicate Item';
          break;
        case 'wrong_clothes':
          disputeTypeLabel = 'Wrong Clothes';
          break;
        default:
          disputeTypeLabel = dispute.type;
      }

      // Get status label
      String statusLabel;
      switch (dispute.status) {
        case 'pending':
          statusLabel = 'Pending Review';
          break;
        case 'reviewing':
          statusLabel = 'Under Review';
          break;
        case 'resolved':
          statusLabel = 'Resolved';
          break;
        case 'rejected':
          statusLabel = 'Rejected';
          break;
        default:
          statusLabel = dispute.status;
      }

      // Create notification message
      String notificationMessage;
      if (dispute.resolutionNotes != null && dispute.resolutionNotes!.isNotEmpty) {
        notificationMessage = 'Your dispute "${disputeTypeLabel}" has been updated to ${statusLabel}. ${dispute.resolutionNotes}';
      } else {
        notificationMessage = 'Your dispute "${disputeTypeLabel}" status has been updated to ${statusLabel}.';
      }

      // Create in-app notification record
      await supabase.from('notifications').insert({
        'user_id': dispute.customerId!,
        'title': 'Dispute Update',
        'message': notificationMessage,
        'type': 'dispute',
        'related_id': dispute.id,
        'related_type': 'dispute',
        'is_read': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification sent to $customerName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending notification: ${safeErrorToString(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showResolutionDialog(Dispute dispute) {
    final notesController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Resolve Dispute: ${dispute.type}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Resolution Status'),
              items: const [
                DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                DropdownMenuItem(value: 'pending', child: Text('Pending Info')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
              ],
              onChanged: (value) {
                if (value != null && dispute.id != null) {
                  _resolveDispute(dispute.id!, value, notesController.text);
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Resolution Notes'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        // Disputes List
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: colorScheme.outline.withOpacity(0.2))),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _statusFilter,
                          decoration: const InputDecoration(
                            labelText: 'Filter by Status',
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All')),
                            DropdownMenuItem(value: 'pending', child: Text('Pending')),
                            DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                            DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _statusFilter = value;
                                _applyFilters();
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _sortBy,
                          decoration: const InputDecoration(
                            labelText: 'Sort by',
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'age', child: Text('Age')),
                            DropdownMenuItem(value: 'urgency', child: Text('Urgency')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _sortBy = value;
                                _applyFilters();
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredDisputes.isEmpty
                          ? const Center(child: Text('No disputes found'))
                          : ListView.builder(
                              itemCount: _filteredDisputes.length,
                              itemBuilder: (context, index) {
                                final dispute = _filteredDisputes[index];
                                final isUnauthenticated = dispute.customerId == null;
                                return ListTile(
                                  title: Text(
                                    dispute.type.toUpperCase(),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(dispute.notes),
                                          ),
                                          if (isUnauthenticated)
                                            Container(
                                              margin: const EdgeInsets.only(left: 8),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.blue,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.person_off,
                                                    size: 12,
                                                    color: Colors.blue.shade700,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    'Guest',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.blue.shade700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (isUnauthenticated)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'No account - Contact via email',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: Chip(
                                    label: Text(dispute.status),
                                    backgroundColor: dispute.status == 'pending'
                                        ? Colors.orange
                                        : dispute.status == 'resolved'
                                            ? Colors.green
                                            : Colors.red,
                                  ),
                                  onTap: () => _selectDispute(dispute),
                                  selected: _selectedDispute?.id == dispute.id,
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
        // Dispute Details & Matching Tool
        Expanded(
          flex: 2,
          child: _selectedDispute == null
              ? const Center(child: Text('Select a dispute to view details'))
              : _buildDisputeDetails(theme, colorScheme, _selectedDispute!),
        ),
      ],
    );
  }

  Widget _buildDisputeDetails(ThemeData theme, ColorScheme colorScheme, Dispute dispute) {
    if (_loadingItemDetails) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Header with dispute info and actions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Dispute: ${dispute.type.toUpperCase()}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Chip(
                          label: Text(dispute.status.toUpperCase()),
                          backgroundColor: dispute.status == 'pending'
                              ? Colors.orange
                              : dispute.status == 'resolved'
                                  ? Colors.green
                                  : Colors.red,
                          labelStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showResolutionDialog(dispute),
                        icon: const Icon(Icons.check_circle, size: 16),
                        label: const Text('Resolve', style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _notifyCustomer(dispute),
                        icon: const Icon(Icons.notifications, size: 16),
                        label: const Text('Notify', style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                dispute.notes,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Side-by-side matching tool
        Expanded(
          child: _disputedItem == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No item information available',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      if (dispute.itemId == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'This dispute has no associated item',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    // Responsive layout: stack vertically on small screens
                    if (constraints.maxWidth < 1200) {
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            // Disputed Item
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
                                ),
                              ),
                              child: _buildDisputedItemView(theme, colorScheme),
                            ),
                            // Related Washer and Similar Items side by side
                            Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
                                      ),
                                    ),
                                    child: _buildWasherView(theme, colorScheme),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: _buildSimilarItemsView(theme, colorScheme),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }
                    // Horizontal layout for larger screens
                    return Row(
                      children: [
                        // Left: Disputed Item
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
                              ),
                            ),
                            child: _buildDisputedItemView(theme, colorScheme),
                          ),
                        ),
                        // Middle: Related Washer
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
                              ),
                            ),
                            child: _buildWasherView(theme, colorScheme),
                          ),
                        ),
                        // Right: Similar Items - More space
                        Expanded(
                          flex: 4,
                          child: _buildSimilarItemsView(theme, colorScheme),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDisputedItemView(ThemeData theme, ColorScheme colorScheme) {
    if (_disputedItem == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Disputed Item',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          // Image and Details side by side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item Image - Fixed size, no wasted space
              if (_disputedItem!['image_url'] != null)
                GestureDetector(
                  onTap: () => _showImageDialog(_disputedItem!['image_url'], 'Disputed Item'),
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        children: [
                          Image.network(
                            _disputedItem!['image_url'],
                            fit: BoxFit.contain,
                            width: 180,
                            height: 180,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image, size: 32, color: Colors.grey),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Image not available',
                                      style: TextStyle(color: Colors.grey, fontSize: 11),
                                    ),
                                  ],
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                          ),
                          // Click indicator
                          Positioned(
                            bottom: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.zoom_in,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported, size: 32, color: Colors.grey),
                        const SizedBox(height: 4),
                        Text(
                          'No image',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              // Item Details - Beside the image
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDetailRow('Type', _disputedItem!['type'] ?? 'N/A', isCompact: true),
                        const Divider(height: 1),
                        _buildDetailRow('Brand', _disputedItem!['brand'] ?? 'N/A', isCompact: true),
                        const Divider(height: 1),
                        _buildDetailRow('Color', _disputedItem!['color'] ?? 'N/A', isCompact: true),
                        if (_disputedItem!['status'] != null) ...[
                          const Divider(height: 1),
                          _buildDetailRow('Status', _disputedItem!['status'] ?? 'N/A', isCompact: true),
                        ],
                        if (_disputedItem!['created_at'] != null) ...[
                          const Divider(height: 1),
                          _buildDetailRow(
                            'Scanned',
                            _formatDate(_disputedItem!['created_at']),
                            isCompact: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWasherView(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Related Washer',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_relatedWasher == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.person_off, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text(
                      'No washer assigned',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        (_relatedWasher!['name'] ?? '?')[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _relatedWasher!['name'] ?? 'Unknown',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Chip(
                      label: Text(
                        (_relatedWasher!['role'] ?? 'washer').toUpperCase(),
                        style: const TextStyle(fontSize: 10),
                      ),
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 6),
                    _buildDetailRow(
                      'Email',
                      _relatedWasher!['email'] ?? 'N/A',
                      isCompact: true,
                      allowWrap: true,
                    ),
                    if (_relatedWasher!['created_at'] != null) ...[
                      const SizedBox(height: 4),
                      _buildDetailRow(
                        'Joined',
                        _formatDate(_relatedWasher!['created_at']),
                        isCompact: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSimilarItemsView(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Similar Items',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_similarItems.isNotEmpty)
                Chip(
                  label: Text('${_similarItems.length}'),
                  backgroundColor: colorScheme.primaryContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_similarItems.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.search_off, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No similar items found',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try adjusting search criteria',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                // Calculate responsive cross axis count - show more items
                final crossAxisCount = constraints.maxWidth > 900 
                    ? 3 
                    : constraints.maxWidth > 600 
                        ? 2 
                        : 1;
                // Aspect ratio for horizontal layout - much more compact (wider/shorter cards)
                final aspectRatio = constraints.maxWidth > 900 
                    ? 5.0 
                    : constraints.maxWidth > 600 
                        ? 5.5 
                        : 6.0; // Very compact on all screens
                
                // Responsive image size - much smaller
                final imageSize = constraints.maxWidth > 900 
                    ? 50.0 
                    : constraints.maxWidth > 600 
                        ? 45.0 
                        : 40.0;
                
                // Responsive padding - minimal
                final horizontalPadding = constraints.maxWidth > 900 
                    ? 6.0 
                    : constraints.maxWidth > 600 
                        ? 4.0 
                        : 3.0;
                final verticalPadding = constraints.maxWidth > 900 
                    ? 4.0 
                    : constraints.maxWidth > 600 
                        ? 2.0 
                        : 1.0;
                
                // Responsive spacing between cards - minimal
                final cardSpacing = constraints.maxWidth > 600 ? 4.0 : 2.0;
                
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: cardSpacing,
                    mainAxisSpacing: cardSpacing,
                    childAspectRatio: aspectRatio,
                  ),
                  itemCount: _similarItems.length,
                  itemBuilder: (context, index) {
                    final item = _similarItems[index];
                    final itemId = item['id'] as String?;
                    final isMatched = _selectedDispute?.matchedItemId == itemId;
                    
                    return Card(
                      elevation: isMatched ? 3 : 1,
                      clipBehavior: Clip.antiAlias,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: isMatched 
                            ? BorderSide(color: Colors.green, width: 2)
                            : BorderSide.none,
                      ),
                      color: isMatched ? Colors.green.shade50 : null,
                      child: Column(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                if (item['image_url'] != null) {
                                  _showImageDialog(
                                    item['image_url'],
                                    '${item['type'] ?? 'Item'} - ${item['brand'] ?? 'Unknown'}',
                                  );
                                }
                              },
                              child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Item Image - Responsive size
                            Container(
                              width: imageSize,
                              height: imageSize,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceVariant,
                              ),
                              child: Stack(
                                children: [
                                  item['image_url'] != null
                                      ? Image.network(
                                          item['image_url'],
                                          fit: BoxFit.contain,
                                          width: imageSize,
                                          height: imageSize,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Center(
                                              child: Icon(
                                                Icons.broken_image,
                                                color: Colors.grey,
                                                size: imageSize * 0.23,
                                              ),
                                            );
                                          },
                                        )
                                      : Center(
                                          child: Icon(
                                            Icons.image_not_supported,
                                            color: Colors.grey,
                                            size: imageSize * 0.23,
                                          ),
                                        ),
                                  // Click indicator
                                  Positioned(
                                    bottom: 2,
                                    right: 2,
                                    child: Container(
                                      padding: const EdgeInsets.all(1.5),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: Icon(
                                        Icons.zoom_in,
                                        color: Colors.white,
                                        size: imageSize * 0.14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Item Details - Responsive padding
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: horizontalPadding, 
                                  vertical: verticalPadding,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      item['type'] ?? 'Unknown',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: constraints.maxWidth > 600 ? 10 : 9,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 1),
                                    Text(
                                      item['brand'] ?? 'N/A',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontSize: constraints.maxWidth > 600 ? 9 : 8,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 0.5),
                                    Text(
                                      item['color'] ?? 'N/A',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.grey,
                                        fontSize: constraints.maxWidth > 600 ? 8 : 7,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Match button
                    Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isMatched 
                                  ? Colors.green.shade100 
                                  : colorScheme.primaryContainer,
                              border: Border(
                                top: BorderSide(
                                  color: colorScheme.outline.withOpacity(0.2),
                                ),
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _matchItemToDispute(itemId ?? ''),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isMatched ? Icons.check_circle : Icons.link,
                                        size: 16,
                                        color: isMatched 
                                            ? Colors.green.shade700 
                                            : colorScheme.onPrimaryContainer,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isMatched ? 'Matched' : 'Match Item',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isMatched 
                                              ? Colors.green.shade700 
                                              : colorScheme.onPrimaryContainer,
                                        ),
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
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isCompact = false,
    bool allowWrap = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 4 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isCompact ? 60 : 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isCompact ? 12 : 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isCompact ? 12 : 14,
              ),
              maxLines: allowWrap ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              softWrap: allowWrap,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}
