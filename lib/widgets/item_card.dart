import 'package:flutter/material.dart';

import '../models/item.dart';
import '../theme/app_theme.dart';

class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.item,
    required this.onAdd,
  });

  final Item item;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          item.name,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.title,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'R\$ ${item.price.toStringAsFixed(2).replaceAll('.', ',')}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.title,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.category} • cadastrado por ${item.createdBy}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.subtitle,
                ),
              ),
            ],
          ),
        ),
        trailing: Container(
          decoration: const BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: onAdd,
          ),
        ),
      ),
    );
  }
}
