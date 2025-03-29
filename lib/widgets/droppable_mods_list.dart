import 'package:flutter/material.dart';
import '../models/mod.dart';
import '../constants/app_theme.dart';
import '../localization/app_localizations.dart';

class DroppableModsList extends StatelessWidget {
  final Widget child;
  final bool isEmpty;
  final String emptyText;
  final bool Function(Mod) onWillAcceptMod;
  final Future<void> Function(Mod) onAcceptMod;

  const DroppableModsList({
    Key? key,
    required this.child,
    required this.isEmpty,
    required this.onWillAcceptMod,
    required this.onAcceptMod,
    required this.emptyText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    // Область для приема перетаскиваемых модов
    return DragTarget<Mod>(
      // Проверка, можно ли принять этот мод
      onWillAccept: (mod) {
        return mod != null && onWillAcceptMod(mod);
      },
      
      // Когда мод "сброшен" в область
      onAccept: (mod) async {
        await onAcceptMod(mod);
      },
      
      // Построение области для перетаскивания
      builder: (context, candidateData, rejectedData) {
        // Когда мод наведен и может быть сброшен
        final bool isHovering = candidateData.isNotEmpty;
        
        return Stack(
          children: [
            // Основной список - мы удаляем дублирующийся текст "Моды не найдены", 
            // так как он уже отображается в child виджете
            child,
            
            // Если пусто, показываем только иконку для перетаскивания
            if (isEmpty && !isHovering)
              Positioned.fill(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Текст "Моды не найдены" уже отображается в child, поэтому здесь не дублируем
                      const SizedBox(height: 50), // Отступ для избежания наложения текстов
                      const Icon(
                        Icons.drag_indicator,
                        size: 32,
                        color: Colors.grey,
                      ),
                      Text(
                        localizations.dragModHere,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Подсветка при наведении для перетаскивания
            if (isHovering)
              Tooltip(
                message: localizations.dragAndDropModsHere,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppTheme.primaryLight,
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                    color: AppTheme.primaryLight.withOpacity(0.1),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
} 