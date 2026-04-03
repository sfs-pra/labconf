# Labconf

GTK3 приложение для настройки тем и параметров labwc (аналог obconf для Openbox).

## Скриншоты

![Главное окно](screenshots/main.png)
![Настройки](screenshots/settings.png)

## Возможности

- Вкладки для темы, внешнего вида, фокуса, окон, мыши, рабочих столов, полей, OSD и environment-переменных
- Live-preview изменений (`Preview`) с `labwc -r`
- Безопасный откат после предпросмотра через `Cancel`
- Проверка совместимости конфига через CLI: `labconf -t`

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
cd /path/to/labconf
meson setup build --prefix=/usr
ninja -C build
sudo ninja -C build install
```

## Запуск

```bash
labconf
```

Или через меню приложений: "Labconf"

## Проверка конфигурации

- `labconf -t` — проверяет текущий `rc.xml` на пригодность для labconf и завершает работу
- `labconf -t -c ~/.config/labwc/rc.xml` — проверка явного файла
- Формат результата: `PASS` / `WARN` / `FAIL`

## Тесты

```bash
tests/run-config-tests.sh
```

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
├── screenshots/
│   ├── main.png
│   └── settings.png
└── README.md
```

## Конфигурационные файлы

- `~/.config/labwc/rc.xml` - основная конфигурация labwc
- `~/.config/gtk-3.0/settings.ini` - GTK3 тема

## Настройки по умолчанию

| Параметр | Значение |
|----------|----------|
| Placement Policy | Cascade |
| Resize Popup | Never |
| WindowSwitcher OSD Style | thumbnail |
| Theme | Greybird |
| Font | DejaVu Sans 10 |

## Примечания

- `Cancel` после `Preview` откатывает `rc.xml` и `environment` к исходному состоянию
- Для применения настроек используется `labwc -r`

## Лицензия

GPL-3.0+

---

[English version](README.md)