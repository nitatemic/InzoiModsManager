import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../models/mod.dart';
import '../localization/app_localizations.dart';
import '../constants/app_theme.dart';

class ModItem extends StatelessWidget {
  final Mod mod;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const ModItem({
    Key? key,
    required this.mod,
    required this.onRename,
    required this.onDelete,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок мода
          ListTile(
            title: Text(
              mod.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              path.basename(mod.mainFilePath),
              overflow: TextOverflow.ellipsis,
            ),
            leading: Icon(
              Icons.extension,
              color: mod.enabled ? AppTheme.primaryLight : Colors.grey,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Кнопка переименования
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  tooltip: localizations.rename,
                  onPressed: onRename,
                ),
                // Кнопка удаления
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  tooltip: localizations.delete,
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
          // Кнопка включения/выключения
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                icon: Icon(mod.enabled ? Icons.clear : Icons.check),
                label: Text(mod.enabled ? localizations.disable : localizations.enable),
                onPressed: onToggle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: mod.enabled 
                      ? Colors.red.withOpacity(0.7) 
                      : AppTheme.primaryLight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 