# Labconf

GTK3 приложение для настройки тем и параметров labwc (аналог obconf для Openbox).

## Возможности

- Вкладки для темы, внешнего вида, фокуса, окон, мыши, рабочих столов, полей, OSD и environment-переменных.
- Live-preview изменений (`Preview`) с `labwc -r`.
- Безопасный откат после предпросмотра через `Cancel`.
- Проверка совместимости конфига через CLI: `labconf -t`.

## Зависимости

- vala >= 0.56
- gtk3 >= 3.22
- libxml2
- meson
- ninja

## Установка зависимостей (Arch Linux)

```bash
sudo pacman -S vala gtk3 libxml2 meson ninja
```

## Сборка и установка

```bash
cd /home/ai/labconf-qwen
meson setup build --prefix=/home/ai/.local
ninja -C build
ninja -C build install
```

## Запуск

```bash
~/.local/bin/labconf
```

Или через меню приложений: "Labconf"

## Проверка конфигурации

- `labconf -t` — проверяет текущий `rc.xml` на пригодность для labconf и завершает работу.
- `labconf -t -c ~/.config/labwc/rc.xml` — проверка явного файла.
- Формат результата: `PASS` / `WARN` / `FAIL`.

## Тесты

- `tests/run-config-tests.sh` компилирует и запускает:
  - matrix-тест `Config`,
  - smoke-набор fixture для `Config`,
  - unit-тест логики layout migration,
  - unit-тест логики `EnvironmentConfig` (CSV normalize + unmanaged merge).
- Тест выполняется в изолированном окружении (`/tmp/labconf-config-matrix-home`) и использует fixture `rc.xml`.
- Реальный `~/.config/labwc/rc.xml` тестом не изменяется и не используется напрямую.
- Для проверки конкретного реального файла используйте `labconf -t -c <path-to-rc.xml>`.

## Preview state machine

- `clean`: изменений нет, `Preview` неактивен.
- `changed`: есть несохраненные изменения, `Preview` активен.
- `preview_active`: preview применен и новых изменений нет.
- `preview_outdated`: preview применен, затем внесены новые изменения.
- Переходы:
  - `changed -> preview_active`: нажать `Preview`.
  - `preview_active -> preview_outdated`: изменить любое поле.
  - `preview_* -> clean`: `Cancel` (откат к исходному состоянию без закрытия).
  - `preview_* -> exit`: `OK` (сохранение и выход).

## Структура проекта

```
labconf/
├── meson.build
├── src/
│   ├── main.vala          # Главное окно, вкладки
│   ├── config.vala        # Чтение/запись rc.xml
│   ├── backup.vala        # Резервное копирование
│   ├── themes.vala        # Сканирование тем
│   └── fonts.vala         # Сканирование шрифтов
├── data/
│   └── labconf.desktop
└── README.md
```

## Конфигурационные файлы

- `~/.config/labwc/rc.xml` - основная конфигурация labwc
- `~/.config/gtk-3.0/settings.ini` - GTK3 тема

## Настройки по умолчанию

| Параметр | Значение |
|---|---|
| Placement Policy | Cascade |
| Resize Popup | Never |
| WindowSwitcher OSD Style | thumbnail |
| Theme | Greybird |
| Font | DejaVu Sans 10 |

## Примечания

- `Cancel` после `Preview` откатывает `rc.xml` и `environment` к исходному состоянию.
- Для применения настроек используется `labwc -r`.

## Лицензия

GPL-3.0+
