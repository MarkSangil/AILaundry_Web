import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final supabase = Supabase.instance.client;
  String _search = '';
  List<Map<String, dynamic>> _clothes = [];

  @override
  void initState() {
    super.initState();
    _fetchClothes();
  }

  Future<void> _fetchClothes() async {
    final response = await supabase
        .from('clothes')
        .select('id, brand, color, type, image_url')
        .ilike('brand', '%$_search%')
        .limit(50);

    setState(() => _clothes = List<Map<String, dynamic>>.from(response));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Inventory Dashboard"),
        actions: [
          IconButton(
            onPressed: () async {
              await supabase.auth.signOut();
              if (mounted) Navigator.of(context).pop();
            },
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search by brand',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                setState(() => _search = val);
                _fetchClothes();
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _clothes.length,
              itemBuilder: (context, index) {
                final item = _clothes[index];
                return ListTile(
                  leading: item['image_url'] != null
                      ? Image.network(item['image_url'], width: 40, height: 40, fit: BoxFit.cover)
                      : const Icon(Icons.image_not_supported),
                  title: Text("${item['brand']} - ${item['type']}"),
                  subtitle: Text("Color: ${item['color']}"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
