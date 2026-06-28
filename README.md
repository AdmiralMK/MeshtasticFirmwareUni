<div align="center" markdown="1">

<img src=".github/meshtastic_logo.png" alt="Meshtastic Logo" width="80"/>
<h1>Meshtastic Firmware</h1>

![GitHub release downloads](https://img.shields.io/github/downloads/meshtastic/firmware/total)
[![CI](https://img.shields.io/github/actions/workflow/status/meshtastic/firmware/main_matrix.yml?branch=master&label=actions&logo=github&color=yellow)](https://github.com/meshtastic/firmware/actions/workflows/ci.yml)
[![CLA assistant](https://cla-assistant.io/readme/badge/meshtastic/firmware)](https://cla-assistant.io/meshtastic/firmware)
[![Fiscal Contributors](https://opencollective.com/meshtastic/tiers/badge.svg?label=Fiscal%20Contributors&color=deeppink)](https://opencollective.com/meshtastic/)
[![Vercel](https://img.shields.io/static/v1?label=Powered%20by&message=Vercel&style=flat&logo=vercel&color=000000)](https://vercel.com?utm_source=meshtastic&utm_campaign=oss)

></a>

</div>

</div>

## 🔄 Автоматическая синхронизация с оригинальным репозиторием

Этот проект является модифицированным форком оригинальной прошивки [Meshtastic](https://github.com/meshtastic/firmware). Для получения свежих изменений из оригинального репозитория используется PowerShell-скрипт `Sync-With-Upstream.ps1`, который:

- ✅ Вытягивает новые коммиты из ветки `develop` оригинального репозитория
- ✅ **Сохраняет приоритет ваших локальных изменений** (ваши файлы не перезаписываются автоматически)
- ✅ При возникновении конфликтов — **интерактивно спрашивает**, что делать с каждым файлом
- ✅ По умолчанию оставляет вашу версию файла
- ✅ Позволяет открыть конфликтный файл в VS Code для ручного редактирования
- ✅ Сохраняет несохранённые изменения в `git stash` перед началом работы и восстанавливает их после

### 📋 Требования

- Windows с PowerShell 5.1+ или PowerShell Core 7+
- Установленный и авторизованный [GitHub CLI](https://cli.github.com/) (`gh`)
- Установленный [Git](https://git-scm.com/) с доступностью команды `git` из PATH
- Установленный [Visual Studio Code](https://code.visualstudio.com/) с командой `code` в PATH
- Настроенные remote:
  - `origin` → `https://github.com/AdmiralMK/MeshtasticFirmwareUni.git` (ваш форк)
  - `upstream` → `https://github.com/meshtastic/firmware.git` (оригинал)

Проверить настройку remote:
```powershell
git remote -v
```

Если `upstream` отсутствует, добавьте его:
```powershell
git remote add upstream https://github.com/meshtastic/firmware.git
```

### 🚀 Использование скрипта

#### Базовый запуск (синхронизация с веткой `develop` из upstream):
```powershell
.\Sync-With-Upstream.ps1
```

#### Параметры скрипта:

| Параметр | Значения | По умолчанию | Описание |
|----------|----------|--------------|----------|
| `-Strategy` | `Merge`, `Rebase` | `Merge` | Стратегия слияния. `Merge` создаёт коммит слияния, `Rebase` перебазирует ваши коммиты поверх upstream |
| `-UpstreamBranch` | имя ветки | `develop` | Ветка оригинального репозитория, из которой тянутся изменения |

#### Примеры запуска:

```powershell
# Синхронизация с веткой develop (по умолчанию)
.\Sync-With-Upstream.ps1

# Использовать стратегию Rebase для более чистой истории
.\Sync-With-Upstream.ps1 -Strategy Rebase

# Потянуть изменения из ветки master оригинала
.\Sync-With-Upstream.ps1 -UpstreamBranch master

# Комбинированный запуск
.\Sync-With-Upstream.ps1 -Strategy Rebase -UpstreamBranch develop
```

### ⚔️ Разрешение конфликтов

При возникновении конфликтов скрипт **приостанавливается** и выводит список конфликтующих файлов. Для каждого файла предлагается выбор:

| Клавиша | Действие | Описание |
|---------|----------|----------|
| **N** (по умолчанию) | Оставить вашу версию | Ваша версия файла сохраняется без изменений |
| **Y** | Заменить на версию из upstream | Берётся новая версия из оригинального репозитория |
| **V** | Открыть в VS Code | Открывается встроенный merge-редактор VS Code для ручного разрешения |
| **A** | Прервать слияние | Отменяет всю операцию, возвращает всё как было |

Пример диалога:
```
Файл: src/mesh/MeshService.cpp
Ваш выбор (N/Y/V/A) [по умолчанию: N]: _
```

> 💡 **Совет:** просто нажимайте `Enter` — это эквивалентно выбору `N` и сохранит вашу версию файла.


### 📝 Фиксация изменений в репозитории

Если вы вручную изменили файлы в папке проекта (через VS Code, проводник Windows или другой редактор) и хотите сохранить эти изменения в вашем репозитории на GitHub, выполните следующие шаги.

#### Шаг 1: Проверьте, какие файлы были изменены

```powershell
git status
```

Вы увидите список изменённых файлов:
```
On branch develop
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
        modified:   src/main.cpp
        modified:   variants/my_board/variant.h

Untracked files:
  (use "git add <file>..." to include in what will be committed)
        src/modules/NewModule.cpp
```

**Обозначения:**
- `modified:` — файл был изменён
- `Untracked files:` — новый файл, который Git ещё не отслеживает

#### Шаг 2: Посмотрите, что именно изменилось (опционально)

```powershell
# Посмотреть изменения в конкретном файле
git diff src/main.cpp

# Посмотреть изменения во всех файлах
git diff

# Посмотреть изменения в новом файле (если он уже добавлен в индекс)
git diff --cached
```

#### Шаг 3: Добавьте изменения в индекс (staging)

Выберите один из вариантов:

```powershell
# Вариант А: Добавить конкретный файл
git add src/main.cpp

# Вариант Б: Добавить несколько конкретных файлов
git add src/main.cpp variants/my_board/variant.h

# Вариант В: Добавить все изменённые и новые файлы
git add .

# Вариант Г: Добавить все изменённые файлы, но НЕ новые (untracked)
git add -u
```

#### Шаг 4: Создайте коммит

```powershell
# Простой коммит с сообщением
git commit -m "feat: add new module for temperature monitoring"

# Коммит с подробным описанием (откроется редактор)
git commit
```

**Рекомендуемый формат сообщений коммитов:**
- `feat:` — новая функция
- `fix:` — исправление ошибки
- `docs:` — изменение документации
- `style:` — форматирование, без изменения логики
- `refactor:` — рефакторинг кода
- `test:` — добавление тестов
- `chore:` — обновление зависимостей, конфигурации

Примеры:
```powershell
git commit -m "feat: add support for ESP32-S3 custom board"
git commit -m "fix: correct I2C address for sensor"
git commit -m "docs: update README with new module description"
```

#### Шаг 5: Отправьте изменения в ваш репозиторий на GitHub

```powershell
# Отправить текущую ветку в origin
git push origin develop
```

Если вы работали в feature-ветке:
```powershell
git push origin feature/my-new-module
```

#### Шаг 6: Проверьте результат

```powershell
# Убедитесь, что всё синхронизировано
git status

# Должно быть:
# On branch develop
# Your branch is up to date with 'origin/develop'.
# nothing to commit, working tree clean
```

### 📋 Полный пример: от изменения файла до push

```powershell
# 1. Вы изменили файл src/main.cpp в VS Code

# 2. Проверили статус
git status

# 3. Посмотрели изменения
git diff src/main.cpp

# 4. Добавили файл в индекс
git add src/main.cpp

# 5. Создали коммит
git commit -m "feat: add custom initialization for new sensor"

# 6. Отправили на GitHub
git push origin develop

# 7. Проверили результат
git status
```

### 📋 Пример с несколькими файлами и новым модулем

```powershell
# Вы создали новый модуль и изменили конфигурацию

# 1. Проверили статус
git status
# Видим:
#   modified:   platformio.ini
#   modified:   src/main.cpp
#   Untracked files:
#     src/modules/TemperatureModule.cpp
#     src/modules/TemperatureModule.h

# 2. Добавили все изменения
git add .

# 3. Создали коммит
git commit -m "feat: add temperature monitoring module"

# 4. Отправили на GitHub
git push origin develop
```

### 🔄 Если нужно отменить изменения

#### Отменить изменения в конкретном файле (вернуть к последнему коммиту):
```powershell
git restore src/main.cpp
```

#### Отменить все изменения в рабочей директории (ОПАСНО!):
```powershell
git restore .
```

#### Отменить последний коммит (сохранить изменения в файлах):
```powershell
git reset --soft HEAD~1
```

#### Отменить последний коммит (удалить изменения):
```powershell
git reset --hard HEAD~1
```

### 💡 Рекомендации

1. **Коммитьте часто.** Делайте небольшие логические коммиты — каждый коммит должен решать одну конкретную задачу.

2. **Пишите понятные сообщения.** Сообщение коммита должно объяснять, **что** было изменено и **почему**.

3. **Не коммитьте временные файлы.** Добавьте в `.gitignore` всё, что не должно попадать в репозиторий:
   ```
   # Пример .gitignore
   *.log
   .vscode/
   .pio/
   build/
   ```

4. **Перед push проверяйте сборку.** Убедитесь, что проект собирается без ошибок:
   ```powershell
   pio run -e <ваша_плата>
   ```

5. **Используйте feature-ветки для больших изменений.** Если вы работаете над крупной функцией, создайте отдельную ветку:
   ```powershell
   git checkout -b feature/temperature-module
   # Работаете, коммитите
   git push origin feature/temperature-module
   ```

6. **Синхронизируйтесь перед началом работы.** Если вы работали на другом устройстве или кто-то ещё имеет доступ к репозиторию:
   ```powershell
   git pull --rebase origin develop
   ```



### 📌 Рекомендации по рабочему процессу

1. **Периодичность синхронизации.** Запускайте скрипт раз в 1–2 недели, чтобы не накапливать большой объём изменений для слияния. Чем меньше изменений — тем проще разрешать конфликты.

2. **Работайте в отдельных ветках.** Для разработки новых модулей создавайте feature-ветки:
   ```powershell
   git checkout -b feature/my-new-module
   ```
   Синхронизацию с upstream выполняйте из основной ветки (`develop` или `master`).

3. **Коммитьте часто.** Делайте небольшие логические коммиты с понятными сообщениями — это упростит откат при необходимости.

4. **Перед запуском скрипта** убедитесь, что проект собирается и работает. Скрипт сохранит ваши изменения в `stash`, но лучше не рисковать.

5. **После синхронизации** всегда проверяйте сборку проекта:
   ```powershell
   pio run -e <ваша_плата>
   ```

6. **Не редактируйте скрипт в рабочей директории без коммита.** Если нужно внести изменения в сам `Sync-With-Upstream.ps1`, сразу коммитьте его, иначе при следующем запуске он будет сохранён в `stash`.

### 🛠️ Дополнительные полезные команды

#### Работа с Git

```powershell
# Посмотреть статус репозитория
git status

# Посмотреть все локальные и удалённые ветки
git branch -a

# Посмотреть только ветки upstream
git branch -r

# Переключиться на другую ветку
git checkout <имя_ветки>

# Создать новую ветку и переключиться на неё
git checkout -b feature/my-feature

# Посмотреть историю коммитов в виде графа
git log --oneline --graph --all -20

# Отменить последнее слияние (если что-то пошло не так)
git reset --hard HEAD~1

# Посмотреть список сохранённых stash
git stash list

# Восстановить последний stash вручную
git stash pop

# Удалить все stash
git stash clear
```

#### Работа с GitHub CLI

```powershell
# Проверить статус авторизации
gh auth status

# Обновить права доступа (если нужна новая scope)
gh auth refresh -h github.com -s delete_repo

# Посмотреть информацию о текущем репозитории
gh repo view

# Открыть репозиторий в браузере
gh repo view --web

# Посмотреть список pull requests
gh pr list
```

#### Работа с PlatformIO

```powershell
# Проверить версию PlatformIO
pio --version

# Установить зависимости для конкретной платы
pio pkg install -e <имя_платы>

# Собрать прошивку
pio run -e <имя_платы>

# Собрать и загрузить на устройство
pio run -e <имя_платы> --target upload

# Очистить результаты сборки
pio run -e <имя_платы> --target clean
```

### ⚠️ Типичные проблемы и решения

| Проблема | Решение |
|----------|---------|
| `execution of scripts is disabled on this system` | Выполнить: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| `HTTP 403: Must have admin rights` | Выполнить: `gh auth refresh -h github.com -s delete_repo` |
| `detected dubious ownership in repository` | Выполнить: `git config --global --add safe.directory <путь_к_проекту>` |
| `upstream/develop not found` | Проверить: `git branch -r`. Возможно, нужно использовать `-UpstreamBranch master` |
| Конфликт после `stash pop` | Открыть VS Code: `code .`, разрешить конфликты, выполнить `git add .` |
| Ошибки сети при `git fetch` | Проверить настройки прокси: `git config --global http.proxy` |

### 🔗 Полезные ссылки

- [Оригинальный репозиторий Meshtastic Firmware](https://github.com/meshtastic/firmware)
- [Документация Meshtastic](https://meshtastic.org/docs/)
- [GitHub CLI Documentation](https://cli.github.com/manual/)
- [PlatformIO Documentation](https://docs.platformio.org/)
- [Git Tools — Stashing and Cleaning](https://git-scm.com/book/en/v2/Git-Tools-Stashing-and-Cleaning)