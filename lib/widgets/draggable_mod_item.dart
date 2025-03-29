import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../models/mod.dart';
import '../localization/app_localizations.dart';
import '../constants/app_theme.dart';

class DraggableModItem extends StatelessWidget {
  final Mod mod;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const DraggableModItem({
    Key? key,
    required this.mod,
    required this.onRename,
    required this.onDelete,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    // Создаем перетаскиваемый виджет с подсказкой
    return Tooltip(
      message: localizations.dragToEnableDisable,
      child: Draggable<Mod>(
        // Данные для передачи
        data: mod,
        // Обратная связь при перетаскивании (уменьшенная копия)
        feedback: Material(
          elevation: 4.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Opacity(
              opacity: 0.8,
              child: _buildModCard(context, localizations, true),
            ),
          ),
        ),
        // Что отображается на месте в момент перетаскивания
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: _buildModCard(context, localizations, false),
        ),
        // Виджет в обычном состоянии
        child: _buildModCard(context, localizations, false),
      ),
    );
  }

  // Построение карточки мода
  Widget _buildModCard(BuildContext context, AppLocalizations localizations, bool isDragging) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок мода
          ListTile(
            title: Tooltip(
              message: mod.name,
              child: Text(
                mod.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            subtitle: Tooltip(
              message: path.basename(mod.mainFilePath),
              child: Text(
                path.basename(mod.mainFilePath),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            leading: Tooltip(
              message: mod.enabled 
                  ? localizations.enabledMods 
                  : localizations.disabledMods,
              child: Icon(
                Icons.extension,
                color: mod.enabled ? AppTheme.primaryLight : Colors.grey,
              ),
            ),
            trailing: !isDragging ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Кнопка переименования
                Tooltip(
                  message: localizations.rename,
                  child: IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: onRename,
                  ),
                ),
                // Кнопка удаления
                Tooltip(
                  message: localizations.delete,
                  child: IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    onPressed: onDelete,
                  ),
                ),
              ],
            ) : null,
          ),
          // Кнопка включения/выключения
          if (!isDragging)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Tooltip(
                  message: mod.enabled 
                      ? localizations.disable
                      : localizations.enable,
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
            ),
        ],
      ),
    );
  }
} 