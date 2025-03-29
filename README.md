# Inzoi Mods Manager

Менеджер модов для игры Inzoi, разработанный на Flutter для платформы Windows.

## Возможности

- Управление модами для игры Inzoi
- Поддержка форматов файлов .pak, .ucas и .utoc
- Автоматический поиск связанных файлов мода
- Настройка порядка загрузки модов
- Двуязычный интерфейс (русский и английский)
- Светлая и темная темы
- Переименование модов в интерфейсе
- Сохранение настроек между запусками
- Перетаскивание модов (drag-and-drop)

## Установка модов

Моды устанавливаются по пути: `{game}\BlueClient\Content\Paks\~mods`

## Использование

1. При первом запуске выберите папку с игрой
2. Используйте кнопку "+" для добавления модов
3. Перетаскивайте моды между колонками или используйте кнопки "Включить"/"Отключить"
4. Используйте кнопки "Переименовать" и "Удалить" для управления модами
5. Используйте кнопку "Порядок загрузки" для настройки очереди загрузки модов

## Сборка проекта

```bash
# Получить зависимости
flutter pub get

# Запустить в режиме отладки
flutter run -d windows

# Собрать релизную версию
flutter build windows
```

## Требования

- Flutter 3.0.0 или выше
- Windows 10 или выше 