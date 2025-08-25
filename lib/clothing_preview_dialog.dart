import 'package:ailaundry_web/models/clothes_item.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClothingPreviewDialog extends StatefulWidget {
  final ClothesItem item;
  final SupabaseClient supabase;

  const ClothingPreviewDialog({
    super.key,
    required this.item,
    required this.supabase,
  });

  @override
  State<ClothingPreviewDialog> createState() => _ClothingPreviewDialogState();
}

class _ClothingPreviewDialogState extends State<ClothingPreviewDialog> {
  List<Map<String, dynamic>> duplicates = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadDuplicates();
  }

  Future<void> _loadDuplicates() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await widget.supabase
          .from('duplicate_clothes')
          .select('id, brand, type, color, image_url, created_at')
          .eq('original_clothes_id', widget.item.id)
          .order('created_at', ascending: false);

      setState(() {
        duplicates = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load duplicates: $e';
        isLoading = false;
      });
    }
  }

  Color _getColorFromName(String? colorName) {
    if (colorName == null) return Colors.grey;
    final colorMap = {
      'red': Colors.red,
      'blue': Colors.blue,
      'green': Colors.green,
      'yellow': Colors.yellow,
      'orange': Colors.orange,
      'purple': Colors.purple,
      'pink': Colors.pink,
      'brown': Colors.brown,
      'black': Colors.black,
      'white': Colors.white,
      'grey': Colors.grey,
      'gray': Colors.grey,
    };
    return colorMap[colorName.toLowerCase()] ?? Colors.grey;
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.checkroom_rounded, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Clothing Details',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(color: theme.primaryColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey[100],
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: widget.item.imageUrl != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(widget.item.imageUrl!, fit: BoxFit.cover),
                        )
                            : Icon(Icons.checkroom_rounded, color: Colors.grey[400], size: 48),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Text('Brand: ${widget.item.brand}', style: theme.textTheme.bodyMedium),
                    Text('Type: ${widget.item.type}', style: theme.textTheme.bodyMedium),
                    Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _getColorFromName(widget.item.color),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Color: ${widget.item.color}', style: theme.textTheme.bodyMedium),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (widget.item.createdAt != null)
                      Text('Added: ${_formatDate(widget.item.createdAt)}',
                          style: theme.textTheme.bodyMedium),

                    const SizedBox(height: 20),
                    Text('Duplicates', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _buildDuplicatesSection(theme),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loadDuplicates,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDuplicatesSection(ThemeData theme) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Text(error!, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red));

    if (duplicates.isEmpty) return Text('No duplicates found', style: theme.textTheme.bodyMedium);

    return Column(
      children: [
        for (var i = 0; i < duplicates.length && i < 3; i++)
          ListTile(
            leading: duplicates[i]['image_url'] != null
                ? Image.network(duplicates[i]['image_url'], width: 32, height: 32, fit: BoxFit.cover)
                : Icon(Icons.checkroom_rounded, size: 16, color: Colors.grey[400]),
            title: Text('${duplicates[i]['brand']} - ${duplicates[i]['type']}', style: theme.textTheme.bodySmall),
            subtitle: Text(_formatDate(duplicates[i]['created_at']), style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
          ),
        if (duplicates.length > 3)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('and ${duplicates.length - 3} more...', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }
}
