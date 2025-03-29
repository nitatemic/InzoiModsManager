import 'dart:io';
import 'package:path/path.dart' as path;

class Mod {
  String id; // Уникальный идентификатор мода
  String name; // Отображаемое имя (может быть переименовано пользователем)
  String originalName; // Оригинальное имя
  String mainFilePath; // Путь к основному файлу .pak
  bool enabled; // Включен ли мод
  List<String> associatedFiles; // Пути к связанным файлам (.ucas, .utoc)
  int loadOrder; // Порядок загрузки (чем меньше, тем раньше загружается)

  Mod({
    required this.id,
    required this.name,
    required this.originalName,
    required this.mainFilePath,
    this.enabled = false,
    this.associatedFiles = const [],
    this.loadOrder = 0,
  });

  // Получить имя мода из пути к файлу
  static String getModNameFromPath(String filePath) {
    final fileName = path.basename(filePath);
    // Убираем префикс порядка загрузки, если он есть (формат: 001_ModName_P.pak)
    final withoutOrderPrefix = fileName.replaceFirst(RegExp(r'^\d{3}_'), '');
    final nameMatch = RegExp(r'([^_]+_.+)_P\.pak$').firstMatch(withoutOrderPrefix);
    return nameMatch?.group(1) ?? path.basenameWithoutExtension(withoutOrderPrefix);
  }

  // Найти связанные файлы для .pak файла
  static List<String> findAssociatedFiles(String pakFilePath) {
    final directory = Directory(path.dirname(pakFilePath));
    final baseName = path.basenameWithoutExtension(pakFilePath);
    // Удаляем префикс порядка, если он есть
    final baseNameWithoutOrder = baseName.replaceFirst(RegExp(r'^\d{3}_'), '');
    final relatedExtensions = ['.ucas', '.utoc'];
    final result = <String>[];

    if (directory.existsSync()) {
      for (var file in directory.listSync()) {
        if (file is File) {
          final fileName = path.basename(file.path);
          final extension = path.extension(fileName).toLowerCase();
          
          // Проверяем, есть ли префикс порядка в имени файла и соответствует ли он базовому имени
          final fileNameWithoutOrder = fileName.replaceFirst(RegExp(r'^\d{3}_'), '');
          
          if (relatedExtensions.contains(extension) && 
              fileNameWithoutOrder.startsWith(baseNameWithoutOrder)) {
            result.add(file.path);
          }
        }
      }
    }

    return result;
  }

  // Создать новый мод из пути к .pak файлу
  static Mod fromPakFile(String pakFilePath) {
    final originalName = getModNameFromPath(pakFilePath);
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final associatedFiles = findAssociatedFiles(pakFilePath);
    
    return Mod(
      id: id,
      name: originalName,
      originalName: originalName,
      mainFilePath: pakFilePath,
      associatedFiles: associatedFiles,
      loadOrder: 0, // По умолчанию порядок загрузки 0
    );
  }
  
  // Конвертировать в Map для сохранения в настройках
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'originalName': originalName,
      'mainFilePath': mainFilePath,
      'enabled': enabled,
      'associatedFiles': associatedFiles,
      'loadOrder': loadOrder,
    };
  }
  
  // Создать из сохраненного Map
  factory Mod.fromJson(Map<String, dynamic> json) {
    return Mod(
      id: json['id'],
      name: json['name'],
      originalName: json['originalName'],
      mainFilePath: json['mainFilePath'],
      enabled: json['enabled'] ?? false,
      associatedFiles: List<String>.from(json['associatedFiles'] ?? []),
      loadOrder: json['loadOrder'] ?? 0,
    );
  }
  
  // Копировать мод с новыми свойствами
  Mod copyWith({
    String? id,
    String? name,
    String? originalName,
    String? mainFilePath,
    bool? enabled,
    List<String>? associatedFiles,
    int? loadOrder,
  }) {
    return Mod(
      id: id ?? this.id,
      name: name ?? this.name,
      originalName: originalName ?? this.originalName,
      mainFilePath: mainFilePath ?? this.mainFilePath,
      enabled: enabled ?? this.enabled,
      associatedFiles: associatedFiles ?? this.associatedFiles,
      loadOrder: loadOrder ?? this.loadOrder,
    );
  }
} 