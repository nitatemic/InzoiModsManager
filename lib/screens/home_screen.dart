import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/mods_provider.dart';
import '../providers/settings_provider.dart';
import '../localization/app_localizations.dart';
import '../widgets/mod_item.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/draggable_mod_item.dart';
import '../widgets/droppable_mods_list.dart';
import '../widgets/mod_load_order_dialog.dart';
import '../models/mod.dart';
import '../constants/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Удаляем автоматический выбор папки с игрой при старте
    
    // Устанавливаем контекст в ModsProvider для отображения уведомлений
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ModsProvider>(context, listen: false).setContext(context);
    });
  }

  // Выбор папки с игрой
  Future<void> _selectGamePath() async {
    final String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: AppLocalizations.of(context).selectGameFolder,
    );

    if (selectedDirectory != null) {
      if (mounted) {
        final modsProvider = Provider.of<ModsProvider>(context, listen: false);
        await modsProvider.setGamePath(selectedDirectory);
        
        // После выбора папки с игрой спрашиваем про включение поддержки модов FrancisLouis
        await _askAboutModsSupport();
      }
    }
  }
  
  // Диалог для включения поддержки модов FrancisLouis
  Future<void> _askAboutModsSupport() async {
    final localizations = AppLocalizations.of(context);
    final modsProvider = Provider.of<ModsProvider>(context, listen: false);
    
    // Сначала проверяем, существует ли уже поддержка модов
    final bool modsSupported = await modsProvider.checkIfModsAlreadySupported();
    
    // Если поддержка модов уже есть, просто показываем уведомление
    if (modsSupported) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Поддержка модов уже включена"),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    // Если поддержки нет, спрашиваем пользователя
    final bool? enableModsSupport = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Включить поддержку модов?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Включить поддержку модов от FrancisLouis с Nexus Mods?\nЭто установит необходимые файлы в папку игры."),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                // Открываем ссылку без закрытия диалога
                await launchNexusModsLink();
              },
              child: Text(
                "Подробнее на Nexus Mods",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(localizations.ok),
          ),
        ],
      ),
    );
    
    if (enableModsSupport == true) {
      // Если пользователь выбрал "Да", включаем полную поддержку модов
      await modsProvider.enableModsSupport();
    } else {
      // Если пользователь выбрал "Нет", просто проверяем наличие папки для модов
      await modsProvider.ensureModsFolderExists();
    }
  }

  // Добавление новых модов
  Future<void> _addMods() async {
    final localizations = AppLocalizations.of(context);
    final modsProvider = Provider.of<ModsProvider>(context, listen: false);
    
    // Проверяем, установлен ли путь к игре
    if (modsProvider.gamePath.isEmpty) {
      await _selectGamePath();
      if (modsProvider.gamePath.isEmpty) return;
    }
    
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pak', 'zip'],
      allowMultiple: true,
      dialogTitle: localizations.selectMod,
    );

    if (result != null && result.files.isNotEmpty) {
      // Показываем индикатор загрузки, если выбрано много файлов или ZIP-архивы
      if (result.files.length > 1 || 
          result.files.any((f) => path.extension(f.path ?? '').toLowerCase() == '.zip')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.importingMods),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      for (var file in result.files) {
        if (file.path != null) {
          await modsProvider.addMod(file.path!);
        }
      }
      
      // Показываем уведомление об успешном добавлении
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.modsAddedSuccess),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Переименование мода
  Future<void> _renameMod(Mod mod) async {
    final TextEditingController controller = TextEditingController(text: mod.name);
    
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).enterNewName),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).enterNewName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(AppLocalizations.of(context).ok),
          ),
        ],
      ),
    );
    
    if (newName != null && newName.isNotEmpty && newName != mod.name) {
      final modsProvider = Provider.of<ModsProvider>(context, listen: false);
      await modsProvider.renameMod(mod.id, newName);
    }
  }

  // Удаление мода
  Future<void> _deleteMod(Mod mod) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).confirmDelete),
        content: Text(AppLocalizations.of(context).confirmDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final modsProvider = Provider.of<ModsProvider>(context, listen: false);
      await modsProvider.removeMod(mod.id);
    }
  }

  // Включение/выключение мода
  Future<void> _toggleMod(Mod mod) async {
    final modsProvider = Provider.of<ModsProvider>(context, listen: false);
    await modsProvider.toggleMod(mod.id);
  }

  // Показать диалог настроек
  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => const SettingsDialog(),
    );
  }

  // Показать диалог управления порядком загрузки
  void _showLoadOrderDialog() {
    showDialog(
      context: context,
      builder: (context) => const ModLoadOrderDialog(),
    );
  }
  
  // Открыть ссылку на Nexus Mods
  Future<void> launchNexusModsLink() async {
    final Uri url = Uri.parse('https://www.nexusmods.com/inzoi/mods/1');
    
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось открыть ссылку: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Обработка перетаскиваемых файлов
  Future<void> _handleDroppedFiles(DropDoneDetails details) async {
    final localizations = AppLocalizations.of(context);
    final modsProvider = Provider.of<ModsProvider>(context, listen: false);
    
    // Проверяем, установлен ли путь к игре
    if (modsProvider.gamePath.isEmpty) {
      await _selectGamePath();
      if (modsProvider.gamePath.isEmpty) return;
    }
    
    // Получаем список файлов
    final files = details.files;
    if (files.isEmpty) return;
    
    // Фильтруем только .pak и .zip файлы
    final validFiles = files.where((file) {
      final extension = path.extension(file.path).toLowerCase();
      return extension == '.pak' || extension == '.zip';
    }).toList();
    
    if (validFiles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.invalidFileFormat),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    // Показываем индикатор загрузки, если файлов много или есть ZIP-архивы
    if (validFiles.length > 1 || 
        validFiles.any((file) => path.extension(file.path).toLowerCase() == '.zip')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.importingMods),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
    
    // Добавляем каждый файл как мод
    for (final file in validFiles) {
      await modsProvider.addMod(file.path);
    }
    
    // Показываем уведомление об успешном добавлении
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.modsAddedSuccess),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final modsProvider = Provider.of<ModsProvider>(context);
    
    if (modsProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localizations.appTitle),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.appTitle),
        actions: [
          // Кнопка "Порядок загрузки" - показываем только если есть включенные моды
          if (modsProvider.enabledMods.isNotEmpty)
            Tooltip(
              message: localizations.manageLoadOrder,
              child: IconButton(
                icon: const Icon(Icons.sort),
                onPressed: _showLoadOrderDialog,
              ),
            ),
          // Кнопка "Обновить"
          Tooltip(
            message: localizations.refresh,
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await modsProvider.refreshMods();
              },
            ),
          ),
          // Кнопка "Настройки"
          Tooltip(
            message: localizations.settings,
            child: IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showSettings,
            ),
          ),
        ],
      ),
      body: modsProvider.gamePath.isEmpty
          ? _buildGamePathSelector(context)
          : _buildModsInterface(context),
      floatingActionButton: modsProvider.gamePath.isEmpty
          ? null
          : Tooltip(
              message: localizations.addMods,
              child: FloatingActionButton(
                onPressed: _addMods,
                child: const Icon(Icons.add),
              ),
            ),
    );
  }

  // Виджет для выбора пути к игре
  Widget _buildGamePathSelector(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    return DropTarget(
      onDragDone: _handleDroppedFiles,
      onDragEntered: (_) {
        // При входе курсора с файлом можно показать подсказку
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.dropToAddMods),
              duration: const Duration(milliseconds: 500),
            ),
          );
        }
      },
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.folder_open,
              size: 64,
              color: AppTheme.primaryLight,
            ),
            const SizedBox(height: 16),
            Text(
              localizations.gamePathNotSet,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            Tooltip(
              message: localizations.gamePathDescription,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.folder),
                label: Text(localizations.selectGameFolder),
                onPressed: _selectGamePath,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              localizations.dropModsHere,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Интерфейс с двумя колонками модов
  Widget _buildModsInterface(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final modsProvider = Provider.of<ModsProvider>(context);
    
    // Оборачиваем основной интерфейс в DropTarget для поддержки drag-and-drop
    return DropTarget(
      onDragDone: _handleDroppedFiles,
      onDragEntered: (_) {
        // При входе курсора с файлом можно показать подсказку
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.dropToAddMods),
              duration: const Duration(milliseconds: 500),
            ),
          );
        }
      },
      child: Row(
        children: [
          // Левая колонка: выключенные моды
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    localizations.disabledMods,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: DroppableModsList(
                    isEmpty: modsProvider.disabledMods.isEmpty,
                    emptyText: localizations.noModsFound,
                    onWillAcceptMod: (mod) => mod.enabled, // Принимаем только включенные моды
                    onAcceptMod: (mod) async {
                      if (mod.enabled) {
                        await modsProvider.toggleMod(mod.id);
                      }
                    },
                    child: modsProvider.disabledMods.isEmpty
                        ? Center(
                            child: Text(localizations.noModsFound),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: modsProvider.disabledMods.length,
                            itemBuilder: (context, index) {
                              final mod = modsProvider.disabledMods[index];
                              return DraggableModItem(
                                mod: mod,
                                onRename: () => _renameMod(mod),
                                onDelete: () => _deleteMod(mod),
                                onToggle: () => _toggleMod(mod),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
          // Разделитель между колонками
          const VerticalDivider(width: 1),
          // Правая колонка: включенные моды
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    localizations.enabledMods,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: DroppableModsList(
                    isEmpty: modsProvider.enabledMods.isEmpty,
                    emptyText: localizations.noModsFound,
                    onWillAcceptMod: (mod) => !mod.enabled, // Принимаем только выключенные моды
                    onAcceptMod: (mod) async {
                      if (!mod.enabled) {
                        await modsProvider.toggleMod(mod.id);
                      }
                    },
                    child: modsProvider.enabledMods.isEmpty
                        ? Center(
                            child: Text(localizations.noModsFound),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: modsProvider.enabledMods.length,
                            itemBuilder: (context, index) {
                              final mod = modsProvider.enabledMods[index];
                              return DraggableModItem(
                                mod: mod,
                                onRename: () => _renameMod(mod),
                                onDelete: () => _deleteMod(mod),
                                onToggle: () => _toggleMod(mod),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 