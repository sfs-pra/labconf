# Установка labconf

## Через PKGBUILD (Arch Linux)

### 1. Установка зависимостей

```bash
sudo pacman -S --needed base-devel vala gtk3 meson ninja
```

### 2. Сборка пакета

```bash
cd /home/ai/labconf-qwen

# Сборка пакета
makepkg -si

# Или без установки (только создание пакета)
makepkg -s

# Пропустить этап check (не рекомендуется)
makepkg -s --nocheck
```

Примечание: в `PKGBUILD` включен этап `check()`, который запускает `./tests/run-config-tests.sh`.

### 3. Установка созданного пакета

Если использовали `makepkg -s`, установите созданный `.pkg.tar.zst`:

```bash
sudo pacman -U labconf-1.0.0-1-x86_64.pkg.tar.zst
```

## Ручная установка (без PKGBUILD)

```bash
cd /home/ai/labconf-qwen

# Сборка
meson setup build --prefix=/usr
ninja -C build

# Установка
sudo ninja -C build install
```

## Запуск

После установки:

```bash
labconf

# Проверить совместимость текущего rc.xml и выйти
labconf -t

# Проверить явный файл rc.xml
labconf -t -c ~/.config/labwc/rc.xml
```

Или через меню приложений: **Labconf**

## Удаление

```bash
sudo pacman -R labconf
```

## Зависимости

### Обязательные
- **gtk3** - GTK+ 3 toolkit
- **glib2** - Low level core library
- **pango** - Text layout library

### Для сборки
- **vala** - Vala compiler
- **meson** - Build system
- **ninja** - Build tool

### Опциональные
- **labwc** - Оконный менеджер Wayland
- **labwc-themes** - Темы для labwc

## Структура установки

```
/usr/
├── bin/
│   └── labconf                   # Исполняемый файл
├── share/
│   ├── applications/
│   │   └── labconf.desktop       # Ярлык в меню
│   ├── doc/labconf/
│   │   └── README.md             # Документация
│   └── licenses/labconf/
│       └── README.md             # Лицензия
```

## Конфигурационные файлы

Приложение работает с файлами:
- `~/.config/labwc/rc.xml` - основная конфигурация labwc
- `~/.config/gtk-3.0/settings.ini` - GTK3 тема

## Применение настроек

После изменения настроек в приложении:

```bash
labwc --reconfigure
```

Или перезапустите labwc.

## О тестах

- `run-config-tests.sh` запускает matrix-тест, smoke fixture-набор, unit-тест layout migration и unit-тест `EnvironmentConfig` в изолированном HOME (`/tmp`).
- Тест не проверяет автоматически ваш реальный `~/.config/labwc/rc.xml`.
- Для валидации реального файла используйте `labconf -t -c <path>`.

## Preview state machine

- `clean`: изменений нет.
- `changed`: появились несохраненные изменения.
- `preview_active`: `Preview` применен и новых изменений нет.
- `preview_outdated`: после `Preview` внесены новые изменения.
- `Cancel` после preview выполняет откат к исходным `rc.xml`/`environment` без закрытия окна.
- `OK` фиксирует текущее состояние и завершает работу.

## Поддержка тем

Приложение сканирует темы из:
- `/usr/share/themes/` - системные темы
- `~/.themes/` - пользовательские темы

Поддерживаются темы с:
- `openbox-3/themerc` - Openbox темы
- `gtk-3.0/gtk.css` - GTK3 темы

## Известные темы

- **Greybird** - тема по умолчанию
- **Numix-SX-FullDark** - тёмная тема
- **PRA** - светлая тема

## Лицензия

GPL-3.0-or-later
