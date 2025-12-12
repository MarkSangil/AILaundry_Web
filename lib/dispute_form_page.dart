import 'package:ailaundry_web/models/dispute.dart';
import 'package:ailaundry_web/services/dispute_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DisputeFormPage extends StatefulWidget {
  const DisputeFormPage({super.key});

  @override
  State<DisputeFormPage> createState() => _DisputeFormPageState();
}

class _DisputeFormPageState extends State<DisputeFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _itemIdController = TextEditingController();
  
  String _selectedType = 'missing';
  bool _isLoading = false;
  String? _error;
  String? _success;

  // Database constraint: type must be 'missing', 'duplicate', or 'wrong_clothes'
  final List<String> _disputeTypes = ['missing', 'duplicate', 'wrong_clothes'];

  @override
  void dispose() {
    _notesController.dispose();
    _itemIdController.dispose();
    super.dispose();
  }

  Future<void> _submitDispute() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });

    try {
      // Get the current authenticated user's ID if available
      // Allow submission even without authentication
      final currentUser = Supabase.instance.client.auth.currentUser;
      final customerId = currentUser?.id;

      final dispute = Dispute(
        type: _selectedType,
        notes: _notesController.text.trim(),
        status: 'pending',
        customerId: customerId, // Will be null if user is not authenticated
        itemId: _itemIdController.text.trim().isEmpty 
            ? null 
            : _itemIdController.text.trim(),
      );

      final service = DisputeService(Supabase.instance.client);
      await service.createDispute(dispute);

      // Clear form
      _notesController.clear();
      _itemIdController.clear();
      _selectedType = 'missing';

      // Show success modal
      if (mounted) {
        _showSuccessModal(context);
      }
    } catch (e) {
      setState(() {
        _error = 'Error submitting dispute: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Dispute Submitted',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'We will email you back',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please message alaundryai@gmail.com',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close modal
                Navigator.of(context).pop(); // Go back to previous page
              },
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
              ),
              child: const Text(
                'OK',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('File a Dispute'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withOpacity(0.1),
              theme.colorScheme.secondary.withOpacity(0.05),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: size.width > 600 ? 600 : size.width * 0.9,
              ),
              child: Card(
                elevation: 12,
                shadowColor: theme.colorScheme.primary.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.report_problem_rounded,
                            size: 40,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          "File a Dispute",
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Report missing, duplicate, or incorrect items",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // Dispute Type
                        Text(
                          "Dispute Type *",
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _selectedType,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.category_outlined),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            items: _disputeTypes.map((type) {
                              // Map database values to user-friendly labels
                              String label;
                              switch (type) {
                                case 'missing':
                                  label = 'Missing';
                                  break;
                                case 'duplicate':
                                  label = 'Duplicate';
                                  break;
                                case 'wrong_clothes':
                                  label = 'Wrong Clothes';
                                  break;
                                default:
                                  label = type[0].toUpperCase() + type.substring(1);
                              }
                              return DropdownMenuItem(
                                value: type,
                                child: Text(
                                  label,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedType = value;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Notes
                        TextFormField(
                          controller: _notesController,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please provide details about the dispute';
                            }
                            return null;
                          },
                          maxLines: 5,
                          decoration: InputDecoration(
                            labelText: "Notes *",
                            hintText: "Describe the issue in detail...",
                            prefixIcon: const Icon(Icons.note_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Item ID (Optional)
                        TextFormField(
                          controller: _itemIdController,
                          decoration: InputDecoration(
                            labelText: "Item ID (Optional)",
                            hintText: "Enter the item ID if applicable",
                            prefixIcon: const Icon(Icons.inventory_2_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Customer ID is automatically set from authenticated user if logged in
                        // Disputes can be submitted without authentication

                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: theme.colorScheme.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],


                        const SizedBox(height: 24),

                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitDispute,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        theme.colorScheme.onPrimary,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    "Submit Dispute",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

