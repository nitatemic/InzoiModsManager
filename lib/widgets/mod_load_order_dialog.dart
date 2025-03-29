import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;

import '../models/mod.dart';
import '../providers/mods_provider.dart';
import '../localization/app_localizations.dart';
import '../constants/app_theme.dart';

class ModLoadOrderDialog extends StatelessWidget {
  const ModLoadOrderDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final modsProvider = Provider.of<ModsProvider>(context);
    final enabledMods = modsProvider.sortedEnabledMods;
    
    return AlertDialog(
      title: Text(localizations.modLoadOrder),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.modLoadOrderDescription,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: enabledMods.isEmpty
                  ? Center(
                      child: Text(localizations.noEnabledMods),
                    )
                  : ListView.builder(
                      itemCount: enabledMods.length,
                      itemBuilder: (context, index) {
                        final mod = enabledMods[index];
                        return ModOrderItem(
                          mod: mod,
                          index: index,
                          isFirst: index == 0,
                          isLast: index == enabledMods.length - 1,
                          onMoveUp: () async {
                            await modsProvider.moveModUp(mod.id);
                          },
                          onMoveDown: () async {
                            await modsProvider.moveModDown(mod.id);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            // Обновляем порядок загрузки всех модов
            await modsProvider.reorderAllMods();
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          child: Text(localizations.applyOrder),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localizations.cancel),
        ),
      ],
    );
  }
}

class ModOrderItem extends StatelessWidget {
  final Mod mod;
  final int index;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const ModOrderItem({
    Key? key,
    required this.mod,
    required this.index,
    required this.isFirst,
    required this.isLast,
    required this.onMoveUp,
    required this.onMoveDown,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryLight,
          child: Text('${index + 1}'),
        ),
        title: Text(
          mod.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          path.basename(mod.mainFilePath),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Кнопка "Вверх"
            Tooltip(
              message: localizations.moveUp,
              child: IconButton(
                icon: const Icon(Icons.arrow_upward),
                onPressed: isFirst ? null : onMoveUp,
                color: isFirst ? Colors.grey : AppTheme.primaryLight,
              ),
            ),
            // Кнопка "Вниз"
            Tooltip(
              message: localizations.moveDown,
              child: IconButton(
                icon: const Icon(Icons.arrow_downward),
                onPressed: isLast ? null : onMoveDown,
                color: isLast ? Colors.grey : AppTheme.primaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 