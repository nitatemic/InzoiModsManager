import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'dart:convert';

import '../models/mod.dart';

// Глобальный контекст для отображения уведомлений
BuildContext? _globalContext;

class ModsProvider extends ChangeNotifier {
  List<Mod> _mods = [];
  String _gamePath = '';
  String _modsPath = '';
  String _disabledModsPath = '';
  bool _isLoading = false;

  List<Mod> get mods => _mods;
  List<Mod> get enabledMods => _mods.where((mod) => mod.enabled).toList();
  List<Mod> get disabledMods => _mods.where((mod) => !mod.enabled).toList();
  String get gamePath => _gamePath;
  String get modsPath => _modsPath;
  String get disabledModsPath => _disabledModsPath;
  bool get isLoading => _isLoading;
  
  // Устанавливаем глобальный контекст
  void setContext(BuildContext context) {
    _globalContext = context;
  }
  
  // Получаем глобальный контекст
  BuildContext? get globalContext => _globalContext;

  ModsProvider() {
    _loadSettings();
  }

  // Загрузить настройки из SharedPreferences
  Future<void> _loadSettings() async {
    _setLoading(true);
    try {
      // Создать папку для отключенных модов
      final appDir = await getApplicationDocumentsDirectory();
      _disabledModsPath = path.join(appDir.path, 'disabled_mods');
      final disabledDir = Directory(_disabledModsPath);
      if (!disabledDir.existsSync()) {
        await disabledDir.create(recursive: true);
      }
      
      final prefs = await SharedPreferences.getInstance();
      
      // Загрузить путь к игре
      _gamePath = prefs.getString('gamePath') ?? '';
      
      if (_gamePath.isNotEmpty) {
        _modsPath = path.join(_gamePath, 'BlueClient', 'Content', 'Paks', '~mods');
        
        // Загрузить сохраненные моды
        final modsJson = prefs.getString('mods');
        if (modsJson != null) {
          final List<dynamic> modsData = jsonDecode(modsJson);
          _mods = modsData.map((data) => Mod.fromJson(data)).toList();
        }
        
        // Проверить существующие моды в папках
        await _checkExistingMods();
      }
    } catch (e) {
      debugPrint('Ошибка при загрузке настроек: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Установить путь к игре
  Future<void> setGamePath(String newPath) async {
    if (_gamePath == newPath) return;
    
    _setLoading(true);
    try {
      _gamePath = newPath;
      _modsPath = path.join(_gamePath, 'BlueClient', 'Content', 'Paks', '~mods');
      
      // Создать папку для модов, если её нет
      final modsDir = Directory(_modsPath);
      if (!modsDir.existsSync()) {
        await modsDir.create(recursive: true);
      }
      
      // Сохранить путь к игре
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gamePath', _gamePath);
      
      // Проверить существующие моды
      await _checkExistingMods();
    } catch (e) {
      debugPrint('Ошибка при установке пути к игре: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Проверить существующие моды в папках
  Future<void> _checkExistingMods() async {
    try {
      // Найти файлы в папке включенных модов
      final List<String> enabledPakFiles = [];
      final modsDir = Directory(_modsPath);
      if (modsDir.existsSync()) {
        final enabledFiles = modsDir.listSync()
            .whereType<File>()
            .map((f) => f.path)
            .toList();
        
        enabledPakFiles.addAll(enabledFiles
            .where((f) => path.extension(f).toLowerCase() == '.pak')
            .toList());
      }
      
      // Найти файлы в папке отключенных модов
      final List<String> disabledPakFiles = [];
      final disabledDir = Directory(_disabledModsPath);
      if (disabledDir.existsSync()) {
        final disabledFiles = disabledDir.listSync()
            .whereType<File>()
            .map((f) => f.path)
            .toList();
        
        disabledPakFiles.addAll(disabledFiles
            .where((f) => path.extension(f).toLowerCase() == '.pak')
            .toList());
      }
      
      // Проверить существующие моды в памяти
      final List<Mod> modsToKeep = [];
      
      for (final mod in _mods) {
        final fileName = path.basename(mod.mainFilePath);
        final modEnabled = mod.mainFilePath.contains(_modsPath);
        final modDisabled = mod.mainFilePath.contains(_disabledModsPath);
        
        // Проверка, существует ли файл мода
        if (!File(mod.mainFilePath).existsSync()) {
          // Проверить, не перемещен ли он в другую папку
          String? newPath;
          
          if (modEnabled) {
            // Мод должен быть включен, но файла нет в папке включенных модов
            // Проверить, не находится ли он в папке отключенных модов
            final disabledPath = path.join(_disabledModsPath, fileName);
            if (File(disabledPath).existsSync()) {
              newPath = disabledPath;
              mod.enabled = false;
            }
          } else if (modDisabled) {
            // Мод должен быть отключен, но файла нет в папке отключенных модов
            // Проверить, не находится ли он в папке включенных модов
            final enabledPath = path.join(_modsPath, fileName);
            if (File(enabledPath).existsSync()) {
              newPath = enabledPath;
              mod.enabled = true;
            }
          }
          
          if (newPath != null) {
            // Обновить путь к файлу
            _updateModPath(mod, newPath);
            modsToKeep.add(mod);
          }
          // Если файл не найден ни в одной из папок, мод удаляется из списка
        } else {
          // Файл существует в одной из папок
          final actuallyEnabled = mod.mainFilePath.contains(_modsPath);
          if (mod.enabled != actuallyEnabled) {
            mod.enabled = actuallyEnabled;
          }
          modsToKeep.add(mod);
        }
      }
      
      _mods = modsToKeep;
      
      // Добавить новые моды, которые уже в папках
      // Сначала включенные моды
      for (final pakFile in enabledPakFiles) {
        final alreadyAdded = _mods.any((m) => 
            m.mainFilePath == pakFile || 
            path.basename(m.mainFilePath) == path.basename(pakFile));
        
        if (!alreadyAdded) {
          final newMod = Mod.fromPakFile(pakFile);
          newMod.enabled = true;
          _mods.add(newMod);
        }
      }
      
      // Затем отключенные моды
      for (final pakFile in disabledPakFiles) {
        final alreadyAdded = _mods.any((m) => 
            m.mainFilePath == pakFile || 
            path.basename(m.mainFilePath) == path.basename(pakFile));
        
        if (!alreadyAdded) {
          final newMod = Mod.fromPakFile(pakFile);
          newMod.enabled = false;
          _mods.add(newMod);
        }
      }
      
      await _saveModsToPrefs();
    } catch (e) {
      debugPrint('Ошибка при проверке модов: $e');
    }
  }

  // Добавить новый мод
  Future<void> addMod(String filePath) async {
    _setLoading(true);
    try {
      final fileExtension = path.extension(filePath).toLowerCase();
      
      // Проверяем, это ZIP-архив или PAK-файл
      if (fileExtension == '.zip') {
        // Если это ZIP-архив, распаковываем его и добавляем все PAK-файлы внутри
        await _addModFromZip(filePath);
      } else if (fileExtension == '.pak') {
        // Если это PAK-файл, добавляем его напрямую
        await _addModFromPak(filePath);
      } else {
        debugPrint('Неподдерживаемый тип файла: $fileExtension');
      }
    } catch (e) {
      debugPrint('Ошибка при добавлении мода: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Добавить мод из ZIP-архива
  Future<void> _addModFromZip(String zipFilePath) async {
    try {
      // Создаем временную директорию для распаковки архива
      final tempDir = await getTemporaryDirectory();
      final extractDirPath = path.join(tempDir.path, 'extract_${DateTime.now().millisecondsSinceEpoch}');
      final extractDir = Directory(extractDirPath);
      if (!extractDir.existsSync()) {
        await extractDir.create(recursive: true);
      }
      
      // Распаковываем архив с помощью пакета archive
      try {
        // Используем extractFileToDisk из пакета archive_io
        extractFileToDisk(zipFilePath, extractDirPath);
        debugPrint('Архив успешно распакован в $extractDirPath');
      } catch (e) {
        debugPrint('Ошибка при распаковке архива: $e');
        return;
      }
      
      // Ищем все PAK-файлы в распакованной директории
      final pakFiles = await _findPakFilesInDirectory(extractDir);
      
      if (pakFiles.isEmpty) {
        debugPrint('В архиве не найдено PAK-файлов');
        notifyListeners(); // Обновляем интерфейс, чтобы показать, что процесс завершен
        return;
      }
      
      debugPrint('Найдено ${pakFiles.length} PAK-файлов в архиве');
      
      // Добавляем каждый найденный PAK-файл
      for (var pakFile in pakFiles) {
        await _addModFromPak(pakFile.path);
      }
      
      // Очищаем временную директорию
      try {
        if (extractDir.existsSync()) {
          await extractDir.delete(recursive: true);
        }
      } catch (e) {
        debugPrint('Ошибка при удалении временной директории: $e');
      }
      
    } catch (e) {
      debugPrint('Ошибка при распаковке и добавлении мода из ZIP: $e');
    }
  }
  
  // Найти все PAK-файлы в директории рекурсивно
  Future<List<File>> _findPakFilesInDirectory(Directory directory) async {
    List<File> pakFiles = [];
    
    try {
      if (!directory.existsSync()) {
        debugPrint('Директория ${directory.path} не существует');
        return pakFiles;
      }
      
      debugPrint('Поиск PAK-файлов в директории ${directory.path}');
      
      try {
        final entities = directory.listSync(recursive: true);
        
        for (var entity in entities) {
          if (entity is File) {
            final extension = path.extension(entity.path).toLowerCase();
            if (extension == '.pak') {
              debugPrint('Найден PAK-файл: ${path.basename(entity.path)}');
              pakFiles.add(entity);
            }
          }
        }
      } catch (e) {
        debugPrint('Ошибка при сканировании директории: $e');
      }
      
      debugPrint('Всего найдено ${pakFiles.length} PAK-файлов');
    } catch (e) {
      debugPrint('Ошибка при поиске PAK-файлов: $e');
    }
    
    return pakFiles;
  }
  
  // Добавить мод из PAK-файла
  Future<void> _addModFromPak(String pakFilePath) async {
    try {
      // Логируем исходный путь к файлу
      debugPrint('Добавление мода из пути: $pakFilePath');
      
      // Проверить, уже ли добавлен этот мод
      final fileName = path.basename(pakFilePath);
      final exists = _mods.any((mod) => 
          path.basename(mod.mainFilePath) == fileName);
      
      if (!exists) {
        // По умолчанию новые моды добавляются как выключенные
        final newMod = Mod.fromPakFile(pakFilePath);
        debugPrint('Создан новый мод: ${newMod.name} с путем: ${newMod.mainFilePath}');
        
        // Скопировать мод в папку отключенных модов
        final destMainPath = path.join(_disabledModsPath, fileName);
        debugPrint('Целевой путь: $destMainPath');
        
        if (pakFilePath != destMainPath) {
          // Проверяем, существует ли исходный файл
          if (!File(pakFilePath).existsSync()) {
            debugPrint('Ошибка: Исходный файл не существует: $pakFilePath');
            return;
          }
          
          // Проверяем существование директории назначения
          if (!Directory(_disabledModsPath).existsSync()) {
            await Directory(_disabledModsPath).create(recursive: true);
            debugPrint('Создана папка для отключенных модов: $_disabledModsPath');
          }
          
          await File(pakFilePath).copy(destMainPath);
          debugPrint('Скопирован файл из $pakFilePath в $destMainPath');
          
          // Найдем связанные файлы
          final associatedFiles = newMod.associatedFiles;
          final newAssociatedFiles = <String>[];
          
          // Копировать связанные файлы
          for (var srcPath in associatedFiles) {
            final associatedFileName = path.basename(srcPath);
            final destPath = path.join(_disabledModsPath, associatedFileName);
            
            if (srcPath != destPath) {
              if (!File(srcPath).existsSync()) {
                debugPrint('Предупреждение: Связанный файл не существует: $srcPath');
                continue;
              }
              
              await File(srcPath).copy(destPath);
              debugPrint('Скопирован связанный файл из $srcPath в $destPath');
              newAssociatedFiles.add(destPath);
            }
          }
          
          // Добавляем мод с обновленными путями
          final updatedMod = newMod.copyWith(
            mainFilePath: destMainPath,
            associatedFiles: newAssociatedFiles,
          );
          _mods.add(updatedMod);
          await _saveModsToPrefs();
          debugPrint('Мод успешно добавлен в список: ${updatedMod.name}');
          debugPrint('Путь мода: ${updatedMod.mainFilePath}');
        } else {
          // Файл уже в нужной папке
          _mods.add(newMod);
          await _saveModsToPrefs();
          debugPrint('Мод успешно добавлен в список: ${newMod.name} (файл уже был в папке)');
        }
      } else {
        debugPrint('Мод уже существует: $fileName');
      }
    } catch (e) {
      debugPrint('Ошибка при добавлении мода из PAK-файла: $e');
    }
  }
  
  // Переименовать мод
  Future<void> renameMod(String id, String newName) async {
    final index = _mods.indexWhere((mod) => mod.id == id);
    if (index != -1) {
      _mods[index] = _mods[index].copyWith(name: newName);
      await _saveModsToPrefs();
      notifyListeners();
    }
  }

  // Удалить мод
  Future<void> removeMod(String id) async {
    await _removeMod(id);
  }
  
  Future<void> _removeMod(String id, {bool notify = true}) async {
    final index = _mods.indexWhere((mod) => mod.id == id);
    if (index != -1) {
      final mod = _mods[index];
      
      try {
        // Удалить файлы мода из соответствующей папки
        final mainFile = File(mod.mainFilePath);
        if (mainFile.existsSync()) {
          await mainFile.delete();
        }
        
        // Удалить связанные файлы (.ucas, .utoc)
        for (var filePath in mod.associatedFiles) {
          final file = File(filePath);
          if (file.existsSync()) {
            await file.delete();
          }
        }
      } catch (e) {
        debugPrint('Ошибка при удалении файлов мода: $e');
      }
      
      _mods.removeAt(index);
      await _saveModsToPrefs();
      
      if (notify) {
        notifyListeners();
      }
    }
  }

  // Переключить состояние мода (включить/выключить)
  Future<void> toggleMod(String id) async {
    await _toggleMod(id);
  }
  
  Future<void> _toggleMod(String id, {bool notify = true}) async {
    final index = _mods.indexWhere((mod) => mod.id == id);
    if (index != -1) {
      final mod = _mods[index];
      debugPrint('Переключение мода: ${mod.name}, текущий статус: ${mod.enabled ? "включен" : "отключен"}');
      debugPrint('Путь к файлу мода: ${mod.mainFilePath}');
      
      // Проверяем существование файла мода
      if (!File(mod.mainFilePath).existsSync()) {
        debugPrint('ОШИБКА: Файл мода не существует: ${mod.mainFilePath}');
        // Если мод помечен как включенный, но файл в отключенных...
        if (mod.enabled && mod.mainFilePath.contains(_modsPath)) {
          final fileName = path.basename(mod.mainFilePath);
          final disabledPath = path.join(_disabledModsPath, fileName);
          if (File(disabledPath).existsSync()) {
            // Файл находится в папке отключенных модов
            debugPrint('Файл найден в папке отключенных модов: $disabledPath');
            _updateModPath(mod, disabledPath);
            _mods[index] = _mods[index].copyWith(enabled: false);
            await _saveModsToPrefs();
            if (notify) notifyListeners();
            return;
          }
        } 
        // Если мод помечен как отключенный, но файл во включенных...
        else if (!mod.enabled && mod.mainFilePath.contains(_disabledModsPath)) {
          final fileName = path.basename(mod.mainFilePath);
          final enabledPath = path.join(_modsPath, fileName);
          if (File(enabledPath).existsSync()) {
            // Файл находится в папке включенных модов
            debugPrint('Файл найден в папке включенных модов: $enabledPath');
            _updateModPath(mod, enabledPath);
            _mods[index] = _mods[index].copyWith(enabled: true);
            await _saveModsToPrefs();
            if (notify) notifyListeners();
            return;
          }
        }
        
        // Если файл не найден ни в одной из папок, сообщаем об ошибке
        debugPrint('ОШИБКА: Файл мода не найден ни в какой папке');
        if (globalContext != null) {
          ScaffoldMessenger.of(globalContext!).showSnackBar(
            SnackBar(
              content: Text('Ошибка: файл мода не найден.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // Выполняем переключение мода
      if (mod.enabled) {
        await _disableMod(mod);
        debugPrint('Мод отключен: ${mod.name}');
      } else {
        await _enableMod(mod);
        debugPrint('Мод включен: ${mod.name}');
      }
      
      // Обновляем статус мода
      _mods[index] = _mods[index].copyWith(enabled: !mod.enabled);
      await _saveModsToPrefs();
      
      if (notify) {
        notifyListeners();
      }
    } else {
      debugPrint('ОШИБКА: Мод с ID $id не найден');
    }
  }
  
  // Получить отсортированный список модов по порядку загрузки
  List<Mod> get sortedEnabledMods {
    return enabledMods..sort((a, b) => a.loadOrder.compareTo(b.loadOrder));
  }
  
  // Изменить порядок загрузки мода
  Future<void> changeModLoadOrder(String id, int newOrder) async {
    final index = _mods.indexWhere((mod) => mod.id == id);
    if (index != -1) {
      // Обновляем порядок загрузки
      _mods[index] = _mods[index].copyWith(loadOrder: newOrder);
      
      // Если мод включен, нужно обновить префикс файла
      if (_mods[index].enabled) {
        await _updateModFilePrefix(_mods[index]);
      }
      
      await _saveModsToPrefs();
      notifyListeners();
    }
  }
  
  // Переместить мод вверх в списке загрузки (уменьшить порядковый номер)
  Future<void> moveModUp(String id) async {
    final enabledModsList = sortedEnabledMods;
    final index = enabledModsList.indexWhere((mod) => mod.id == id);
    
    if (index > 0) {
      // Обмениваем порядковые номера с предыдущим модом
      final currentOrder = enabledModsList[index].loadOrder;
      final previousOrder = enabledModsList[index - 1].loadOrder;
      
      await changeModLoadOrder(enabledModsList[index].id, previousOrder);
      await changeModLoadOrder(enabledModsList[index - 1].id, currentOrder);
    }
  }
  
  // Переместить мод вниз в списке загрузки (увеличить порядковый номер)
  Future<void> moveModDown(String id) async {
    final enabledModsList = sortedEnabledMods;
    final index = enabledModsList.indexWhere((mod) => mod.id == id);
    
    if (index < enabledModsList.length - 1 && index >= 0) {
      // Обмениваем порядковые номера со следующим модом
      final currentOrder = enabledModsList[index].loadOrder;
      final nextOrder = enabledModsList[index + 1].loadOrder;
      
      await changeModLoadOrder(enabledModsList[index].id, nextOrder);
      await changeModLoadOrder(enabledModsList[index + 1].id, currentOrder);
    }
  }
  
  // Обновить префикс файла в соответствии с порядком загрузки
  Future<void> _updateModFilePrefix(Mod mod) async {
    if (!mod.enabled) return;
    
    try {
      final fileName = path.basename(mod.mainFilePath);
      // Удаляем существующий префикс, если он есть
      final nameWithoutPrefix = fileName.replaceFirst(RegExp(r'^\d{3}_'), '');
      // Создаем новый префикс
      final newPrefix = '${mod.loadOrder.toString().padLeft(3, '0')}_';
      final newFileName = newPrefix + nameWithoutPrefix;
      
      final directory = path.dirname(mod.mainFilePath);
      final oldPath = mod.mainFilePath;
      final newPath = path.join(directory, newFileName);
      
      // Переименовываем файл .pak
      if (File(oldPath).existsSync() && oldPath != newPath) {
        await File(oldPath).rename(newPath);
        
        // Переименовываем связанные файлы
        final newAssociatedFiles = <String>[];
        for (final associatedFile in mod.associatedFiles) {
          final assocFileName = path.basename(associatedFile);
          final assocExtension = path.extension(assocFileName);
          final assocNameWithoutExt = path.basenameWithoutExtension(assocFileName);
          // Удаляем существующий префикс
          final assocNameWithoutPrefix = assocNameWithoutExt.replaceFirst(RegExp(r'^\d{3}_'), '');
          // Новое имя с префиксом
          final newAssocFileName = '$newPrefix$assocNameWithoutPrefix$assocExtension';
          final oldAssocPath = associatedFile;
          final newAssocPath = path.join(directory, newAssocFileName);
          
          if (File(oldAssocPath).existsSync() && oldAssocPath != newAssocPath) {
            await File(oldAssocPath).rename(newAssocPath);
            newAssociatedFiles.add(newAssocPath);
          } else {
            newAssociatedFiles.add(associatedFile);
          }
        }
        
        // Обновляем пути в моде
        _updateModPath(mod, newPath, newAssociatedFiles);
      }
    } catch (e) {
      debugPrint('Ошибка при обновлении префикса файла: $e');
    }
  }
  
  // Обновить путь к файлу мода
  void _updateModPath(Mod mod, String newPath, [List<String>? newAssociatedFiles]) {
    final index = _mods.indexWhere((m) => m.id == mod.id);
    if (index != -1) {
      // Находим новые связанные файлы, если не переданы
      final associatedFiles = newAssociatedFiles ?? Mod.findAssociatedFiles(newPath);
      _mods[index] = _mods[index].copyWith(
        mainFilePath: newPath,
        associatedFiles: associatedFiles,
      );
    }
  }

  // Включить мод (переместить файлы из disabled_mods в папку модов игры)
  Future<void> _enableMod(Mod mod) async {
    try {
      // Проверяем, существует ли папка для модов
      if (!Directory(_modsPath).existsSync()) {
        await Directory(_modsPath).create(recursive: true);
        debugPrint('Создана папка для модов: $_modsPath');
      }
      
      // Проверяем существование файла мода
      final sourcePath = mod.mainFilePath;
      if (!File(sourcePath).existsSync()) {
        debugPrint('ОШИБКА: Файл мода не существует: $sourcePath');
        return;
      }
      
      // Определяем следующий доступный порядковый номер
      int nextOrder = 0;
      if (enabledMods.isNotEmpty) {
        // Находим максимальный порядковый номер среди включенных модов
        nextOrder = enabledMods.fold(0, (max, m) => m.loadOrder > max ? m.loadOrder : max) + 1;
      }
      debugPrint('Следующий порядковый номер: $nextOrder');
      
      // Обновляем порядковый номер мода
      final index = _mods.indexWhere((m) => m.id == mod.id);
      if (index != -1) {
        _mods[index] = _mods[index].copyWith(loadOrder: nextOrder);
        mod = _mods[index]; // Обновляем локальную переменную с новым порядковым номером
      }
      
      // Перенести основной файл .pak с учетом порядка загрузки
      final mainFileName = path.basename(mod.mainFilePath);
      // Удаляем старый префикс, если есть
      final nameWithoutPrefix = mainFileName.replaceFirst(RegExp(r'^\d{3}_'), '');
      // Добавляем новый префикс
      final orderPrefix = '${mod.loadOrder.toString().padLeft(3, '0')}_';
      final newFileName = orderPrefix + nameWithoutPrefix;
      
      final destPath = path.join(_modsPath, newFileName);
      debugPrint('Перемещение мода из $sourcePath в $destPath');
      
      if (sourcePath != destPath) {
        try {
          // Используем copy + delete вместо rename для перемещения между разными дисками
          await File(sourcePath).copy(destPath);
          debugPrint('Файл скопирован в $destPath');
          await File(sourcePath).delete();
          debugPrint('Исходный файл удален: $sourcePath');
        } catch (e) {
          debugPrint('Ошибка при перемещении файла: $e');
          return;
        }
      }
      
      // Перенести связанные файлы с тем же префиксом
      final newAssociatedFiles = <String>[];
      for (var srcPath in mod.associatedFiles) {
        // Проверяем существование связанного файла
        if (!File(srcPath).existsSync()) {
          debugPrint('Предупреждение: Связанный файл не существует: $srcPath');
          continue;
        }
        
        final fileName = path.basename(srcPath);
        final fileExtension = path.extension(fileName);
        final fileNameWithoutExt = path.basenameWithoutExtension(fileName);
        // Удаляем старый префикс
        final nameWithoutPrefix = fileNameWithoutExt.replaceFirst(RegExp(r'^\d{3}_'), '');
        // Создаем новое имя с префиксом
        final newAssocFileName = '$orderPrefix$nameWithoutPrefix$fileExtension';
        final newDestPath = path.join(_modsPath, newAssocFileName);
        
        if (srcPath != newDestPath) {
          try {
            // Используем copy + delete вместо rename для перемещения между разными дисками
            await File(srcPath).copy(newDestPath);
            debugPrint('Связанный файл скопирован в $newDestPath');
            await File(srcPath).delete();
            debugPrint('Исходный связанный файл удален: $srcPath');
            newAssociatedFiles.add(newDestPath);
          } catch (e) {
            debugPrint('Ошибка при перемещении связанного файла: $e');
          }
        }
      }
      
      // Обновить путь к файлу мода
      _updateModPath(mod, destPath, newAssociatedFiles);
      debugPrint('Путь к файлу мода обновлен: $destPath');
    } catch (e) {
      debugPrint('Ошибка при включении мода: $e');
    }
  }
  
  // Отключить мод (переместить файлы из папки модов игры в disabled_mods)
  Future<void> _disableMod(Mod mod) async {
    try {
      // Проверяем, существует ли папка для отключенных модов
      if (!Directory(_disabledModsPath).existsSync()) {
        await Directory(_disabledModsPath).create(recursive: true);
        debugPrint('Создана папка для отключенных модов: $_disabledModsPath');
      }
      
      // Проверяем существование файла мода
      final sourcePath = mod.mainFilePath;
      if (!File(sourcePath).existsSync()) {
        debugPrint('ОШИБКА: Файл мода не существует: $sourcePath');
        return;
      }
      
      // Перенести основной файл .pak, удалив префикс порядка загрузки
      final mainFileName = path.basename(mod.mainFilePath);
      // Удаляем префикс, если он есть
      final nameWithoutPrefix = mainFileName.replaceFirst(RegExp(r'^\d{3}_'), '');
      
      final destPath = path.join(_disabledModsPath, nameWithoutPrefix);
      debugPrint('Перемещение мода из $sourcePath в $destPath');
      
      if (sourcePath != destPath) {
        try {
          // Используем copy + delete вместо rename для перемещения между разными дисками
          await File(sourcePath).copy(destPath);
          debugPrint('Файл скопирован в $destPath');
          await File(sourcePath).delete();
          debugPrint('Исходный файл удален: $sourcePath');
        } catch (e) {
          debugPrint('Ошибка при перемещении файла: $e');
          return;
        }
      }
      
      // Перенести связанные файлы, удалив префикс
      final newAssociatedFiles = <String>[];
      for (var srcPath in mod.associatedFiles) {
        // Проверяем существование связанного файла
        if (!File(srcPath).existsSync()) {
          debugPrint('Предупреждение: Связанный файл не существует: $srcPath');
          continue;
        }
        
        final fileName = path.basename(srcPath);
        final fileExtension = path.extension(fileName);
        final fileNameWithoutExt = path.basenameWithoutExtension(fileName);
        // Удаляем префикс, если он есть
        final nameWithoutPrefix = fileNameWithoutExt.replaceFirst(RegExp(r'^\d{3}_'), '');
        // Новое имя файла без префикса
        final newAssocFileName = '$nameWithoutPrefix$fileExtension';
        final newDestPath = path.join(_disabledModsPath, newAssocFileName);
        
        if (srcPath != newDestPath) {
          try {
            // Используем copy + delete вместо rename для перемещения между разными дисками
            await File(srcPath).copy(newDestPath);
            debugPrint('Связанный файл скопирован в $newDestPath');
            await File(srcPath).delete();
            debugPrint('Исходный связанный файл удален: $srcPath');
            newAssociatedFiles.add(newDestPath);
          } catch (e) {
            debugPrint('Ошибка при перемещении связанного файла: $e');
          }
        }
      }
      
      // Обновить путь к файлу мода
      _updateModPath(mod, destPath, newAssociatedFiles);
      debugPrint('Путь к файлу мода обновлен: $destPath');
    } catch (e) {
      debugPrint('Ошибка при отключении мода: $e');
    }
  }
  
  // Сохранить моды в SharedPreferences
  Future<void> _saveModsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modsJson = jsonEncode(_mods.map((mod) => mod.toJson()).toList());
      await prefs.setString('mods', modsJson);
    } catch (e) {
      debugPrint('Ошибка при сохранении модов: $e');
    }
  }
  
  // Установить состояние загрузки
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  // Обновить моды (перезагрузить из папок)
  Future<void> refreshMods() async {
    _setLoading(true);
    try {
      await _checkExistingMods();
    } finally {
      _setLoading(false);
    }
  }

  // Обновить порядок загрузки всех модов
  Future<void> reorderAllMods() async {
    // Получаем отсортированный список включенных модов
    final enabledModsList = sortedEnabledMods;
    
    // Обновляем порядок загрузки для каждого мода
    for (int i = 0; i < enabledModsList.length; i++) {
      await changeModLoadOrder(enabledModsList[i].id, i);
    }
  }

  // Включить поддержку модов от FrancisLouis
  Future<void> enableModsSupport() async {
    if (_gamePath.isEmpty) return;
    
    _setLoading(true);
    try {
      // Путь назначения - папка BlueClient в директории игры
      final String targetDir = path.join(_gamePath, 'BlueClient');
      
      // Создаем директорию назначения, если её нет
      final Directory targetDirectory = Directory(targetDir);
      if (!targetDirectory.existsSync()) {
        await targetDirectory.create(recursive: true);
      }
      
      // Создаем директории с подкаталогами
      final String binariesDir = path.join(targetDir, 'Binaries');
      final String win64Dir = path.join(binariesDir, 'Win64');
      final String bitfixDir = path.join(win64Dir, 'bitfix');
      
      for (final dir in [binariesDir, win64Dir, bitfixDir]) {
        final directory = Directory(dir);
        if (!directory.existsSync()) {
          await directory.create(recursive: true);
        }
      }
      
      // Создаем структуру папок для модов
      final String contentDir = path.join(targetDir, 'Content');
      final String paksDir = path.join(contentDir, 'Paks');
      final String modsDir = path.join(paksDir, '~mods');
      
      for (final dir in [contentDir, paksDir, modsDir]) {
        final directory = Directory(dir);
        if (!directory.existsSync()) {
          await directory.create(recursive: true);
        }
      }
      
      // 1. Копируем файл dsound.dll из assets в папку Win64
      try {
        final ByteData dsoundData = await rootBundle.load('assets/ModEnable/BlueClient/Binaries/Win64/dsound.dll');
        final dsoundBuffer = dsoundData.buffer;
        final dsoundFile = File(path.join(win64Dir, 'dsound.dll'));
        await dsoundFile.writeAsBytes(
          dsoundBuffer.asUint8List(dsoundData.offsetInBytes, dsoundData.lengthInBytes)
        );
        debugPrint('Файл dsound.dll успешно скопирован');
      } catch (e) {
        debugPrint('Ошибка при копировании dsound.dll: $e');
      }
      
      // 2. Копируем файл sig.lua из assets в папку bitfix
      try {
        final ByteData sigLuaData = await rootBundle.load('assets/ModEnable/BlueClient/Binaries/Win64/bitfix/sig.lua');
        final sigLuaBuffer = sigLuaData.buffer;
        final sigLuaFile = File(path.join(bitfixDir, 'sig.lua'));
        await sigLuaFile.writeAsBytes(
          sigLuaBuffer.asUint8List(sigLuaData.offsetInBytes, sigLuaData.lengthInBytes)
        );
        debugPrint('Файл sig.lua успешно скопирован');
      } catch (e) {
        debugPrint('Ошибка при копировании sig.lua: $e');
      }
      
      debugPrint('Поддержка модов включена');
    } catch (e) {
      debugPrint('Ошибка при включении поддержки модов: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Проверить, поддерживаются ли моды уже
  Future<bool> checkIfModsAlreadySupported() async {
    try {
      if (_gamePath.isEmpty) return false;
      
      // Проверяем наличие ключевых файлов для поддержки модов
      final String dsoundPath = path.join(_gamePath, 'BlueClient', 'Binaries', 'Win64', 'dsound.dll');
      final String sigLuaPath = path.join(_gamePath, 'BlueClient', 'Binaries', 'Win64', 'bitfix', 'sig.lua');
      
      // Проверяем существование обоих файлов
      final bool dsoundExists = File(dsoundPath).existsSync();
      final bool sigLuaExists = File(sigLuaPath).existsSync();
      
      // Если оба файла существуют, значит поддержка модов уже включена
      return dsoundExists && sigLuaExists;
    } catch (e) {
      debugPrint('Ошибка при проверке поддержки модов: $e');
      return false;
    }
  }
  
  // Убедиться, что папка для модов существует
  Future<void> ensureModsFolderExists() async {
    if (_gamePath.isEmpty) return;
    
    _setLoading(true);
    try {
      // Создаем структуру папок для модов
      final String contentDir = path.join(_gamePath, 'BlueClient', 'Content');
      final String paksDir = path.join(contentDir, 'Paks');
      final String modsDir = path.join(paksDir, '~mods');
      
      for (final dir in [contentDir, paksDir, modsDir]) {
        final directory = Directory(dir);
        if (!directory.existsSync()) {
          await directory.create(recursive: true);
        }
      }
      
      debugPrint('Папка для модов проверена и создана при необходимости');
    } catch (e) {
      debugPrint('Ошибка при создании папки для модов: $e');
    } finally {
      _setLoading(false);
    }
  }
} 