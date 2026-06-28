# Sync-With-Upstream.ps1
# ============================================================================
# Скрипт для синхронизации вашего форка с оригинальным репозиторием meshtastic/firmware
# Источник обновлений: ветка "develop" из upstream (или указанная через параметр)
# Приоритет: ваши изменения > изменения из upstream
# При конфликтах: интерактивное решение с приоритетом ваших файлов
# ============================================================================

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Merge', 'Rebase')]
    [string]$Strategy = 'Merge',

    [Parameter(Mandatory=$false)]
    [string]$UpstreamBranch = 'develop'
)

# Цвета для вывода
$Colors = @{
    Info = 'Cyan'
    Success = 'Green'
    Warning = 'Yellow'
    Error = 'Red'
    Question = 'Magenta'
}

Write-Host "========================================" -ForegroundColor $Colors.Info
Write-Host "Meshtastic Firmware Sync Script" -ForegroundColor $Colors.Info
Write-Host "========================================" -ForegroundColor $Colors.Info
Write-Host ""

# ============================================================================
# ПРОВЕРКА 1: Находимся ли мы в Git-репозитории
# ============================================================================
if (-not (Test-Path .git)) {
    Write-Error "Текущая папка не является Git-репозиторием!"
    exit 1
}

# ============================================================================
# ПРОВЕРКА 2: Нет ли незавершённого слияния или rebase
# ============================================================================
$IsMergeInProgress = Test-Path .git/MERGE_HEAD
$IsRebaseInProgress = (Test-Path .git/rebase-merge) -or (Test-Path .git/rebase-apply)

if ($IsMergeInProgress -or $IsRebaseInProgress) {
    Write-Host "========================================" -ForegroundColor $Colors.Error
    Write-Host "ОБНАРУЖЕНО НЕЗАВЕРШЁННОЕ СЛИЯНИЕ!" -ForegroundColor $Colors.Error
    Write-Host "========================================" -ForegroundColor $Colors.Error
    Write-Host ""
    Write-Host "Git находится в состоянии незавершённого слияния или rebase." -ForegroundColor $Colors.Warning
    Write-Host "Скрипт не может работать в этом состоянии." -ForegroundColor $Colors.Warning
    Write-Host ""
    Write-Host "Выберите действие:" -ForegroundColor $Colors.Question
    Write-Host "  [A] - Отменить слияние (git merge --abort) — РЕКОМЕНДУЕТСЯ" -ForegroundColor $Colors.Success
    Write-Host "  [C] - Завершить слияние, оставив ваши версии файлов" -ForegroundColor $Colors.Warning
    Write-Host "  [X] - Выйти без действий" -ForegroundColor $Colors.Error
    Write-Host ""

    $Choice = Read-Host "Ваш выбор (A/C/X) [по умолчанию: A]"

    if ([string]::IsNullOrWhiteSpace($Choice)) {
        $Choice = 'A'
    } else {
        $Choice = $Choice.ToUpper()
    }

    switch ($Choice) {
        'A' {
            Write-Host "Отмена слияния..." -ForegroundColor $Colors.Info
            if ($IsMergeInProgress) {
                git merge --abort
            } else {
                git rebase --abort
            }
            Write-Host "? Слияние отменено. Продолжаем работу." -ForegroundColor $Colors.Success
        }
        'C' {
            Write-Host "Завершение слияния с приоритетом ваших файлов..." -ForegroundColor $Colors.Info
            $ConflictFiles = git diff --name-only --diff-filter=U
            foreach ($File in ($ConflictFiles -split "`n")) {
                if (-not [string]::IsNullOrWhiteSpace($File)) {
                    git checkout --ours $File
                    git add $File
                    Write-Host "  ? Оставлена ваша версия: $File" -ForegroundColor $Colors.Success
                }
            }
            if ($IsMergeInProgress) {
                git commit --no-edit
            } else {
                git rebase --continue
            }
            Write-Host "? Слияние завершено." -ForegroundColor $Colors.Success
            Write-Host ""
            Write-Host "Слияние завершено. Запустите скрипт заново для синхронизации." -ForegroundColor $Colors.Info
            exit 0
        }
        'X' {
            Write-Host "Выход из скрипта." -ForegroundColor $Colors.Warning
            exit 0
        }
        default {
            Write-Host "Неверный выбор. Отмена слияния..." -ForegroundColor $Colors.Warning
            if ($IsMergeInProgress) {
                git merge --abort
            } else {
                git rebase --abort
            }
        }
    }

    Write-Host ""
}

# ============================================================================
# ПОЛУЧЕНИЕ ТЕКУЩЕЙ ВЕТКИ
# ============================================================================
$CurrentBranch = git rev-parse --abbrev-ref HEAD
Write-Host "Локальная ветка: $CurrentBranch" -ForegroundColor $Colors.Info
Write-Host "Целевая ветка upstream: $UpstreamBranch" -ForegroundColor $Colors.Info

# ============================================================================
# ПРОВЕРКА 3: Наличие upstream remote
# ============================================================================
$Remotes = git remote -v
if (-not ($Remotes -match "upstream")) {
    Write-Error "Remote 'upstream' не найден! Добавьте его командой:"
    Write-Host "git remote add upstream https://github.com/meshtastic/firmware.git" -ForegroundColor $Colors.Warning
    exit 1
}

# ============================================================================
# СОХРАНЕНИЕ НЕСОХРАНЁННЫХ ИЗМЕНЕНИЙ В STASH
# ============================================================================
$Status = git status --porcelain
$StashCreated = $false

if ($Status) {
    Write-Host ""
    Write-Host "Обнаружены несохраненные изменения. Сохранение во временное хранилище (stash)..." -ForegroundColor $Colors.Warning
    git stash push -u -m "Auto-stash before sync with upstream"

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Не удалось сохранить изменения в stash!"
        exit $LASTEXITCODE
    }

    $StashCreated = $true
    Write-Host "? Изменения сохранены в stash" -ForegroundColor $Colors.Success
}

# ============================================================================
# ПОЛУЧЕНИЕ ИЗМЕНЕНИЙ ИЗ UPSTREAM
# ============================================================================
Write-Host ""
Write-Host "Получение изменений из upstream..." -ForegroundColor $Colors.Info
git fetch upstream

if ($LASTEXITCODE -ne 0) {
    Write-Error "Не удалось получить изменения из upstream!"
    if ($StashCreated) { git stash pop }
    exit $LASTEXITCODE
}

# ============================================================================
# ПРОВЕРКА 4: Существует ли указанная ветка в upstream
# ============================================================================
$UpstreamRefExists = git branch -r | Select-String "upstream/$UpstreamBranch"
if (-not $UpstreamRefExists) {
    Write-Error "Ветка 'upstream/$UpstreamBranch' не найдена в upstream!"
    Write-Host "Доступные ветки upstream:" -ForegroundColor $Colors.Warning
    git branch -r | Select-String "upstream/"
    if ($StashCreated) { git stash pop }
    exit 1
}

# ============================================================================
# ПРОВЕРКА 5: Есть ли новые коммиты для слияния
# ============================================================================
$CommitsBehind = git rev-list --left-right --count HEAD...upstream/$UpstreamBranch
$BehindCount = ($CommitsBehind -split '\s+')[1]

if ($BehindCount -eq '0') {
    Write-Host ""
    Write-Host "? Ваш репозиторий уже синхронизирован с upstream/$UpstreamBranch. Новых изменений нет." -ForegroundColor $Colors.Success

    if ($StashCreated) {
        Write-Host ""
        Write-Host "Восстановление сохраненных изменений..." -ForegroundColor $Colors.Info
        git stash pop
    }

    exit 0
}

Write-Host "Найдено $BehindCount новых коммитов в upstream/$UpstreamBranch для слияния." -ForegroundColor $Colors.Info

# ============================================================================
# ВЫПОЛНЕНИЕ СЛИЯНИЯ ИЛИ ПЕРЕБАЗИРОВАНИЯ
# ============================================================================
Write-Host ""
Write-Host "Выполнение $Strategy с upstream/$UpstreamBranch..." -ForegroundColor $Colors.Info

if ($Strategy -eq 'Merge') {
    # --no-commit останавливает слияние при конфликтах и не создаёт коммит автоматически
    git merge upstream/$UpstreamBranch --no-commit --no-ff
} else {
    git rebase upstream/$UpstreamBranch
}

# ============================================================================
# ПРОВЕРКА НАЛИЧИЯ КОНФЛИКТОВ
# ============================================================================
$Conflicts = git diff --name-only --diff-filter=U

if ($Conflicts) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor $Colors.Error
    Write-Host "ОБНАРУЖЕНЫ КОНФЛИКТЫ!" -ForegroundColor $Colors.Error
    Write-Host "========================================" -ForegroundColor $Colors.Error
    Write-Host ""
    Write-Host "Следующие файлы имеют конфликты:" -ForegroundColor $Colors.Warning

    $ConflictFiles = @($Conflicts -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $TotalConflicts = $ConflictFiles.Count
    
    for ($i = 0; $i -lt $TotalConflicts; $i++) {
        Write-Host "  $($i + 1). $($ConflictFiles[$i])" -ForegroundColor $Colors.Warning
    }

    Write-Host ""
    Write-Host "Всего конфликтных файлов: $TotalConflicts" -ForegroundColor $Colors.Info
    Write-Host ""

    # Флаг для выхода из внешнего цикла при выборе опции "все ваши"
    $ApplyAllOurs = $false

    # Используем метку для выхода из внешнего foreach из внутреннего switch
    :outerForeach foreach ($File in $ConflictFiles) {
        Write-Host "========================================" -ForegroundColor $Colors.Info
        Write-Host "Обработка файла: $File" -ForegroundColor $Colors.Info
        Write-Host "========================================" -ForegroundColor $Colors.Info
        Write-Host ""
        
        # Подсказки выводятся ПРИ КАЖДОМ запросе
        Write-Host "Выберите действие:" -ForegroundColor $Colors.Question
        Write-Host "  [N] - Оставить ВАШУ версию для этого файла (по умолчанию)" -ForegroundColor $Colors.Success
        Write-Host "  [Y] - Заменить на версию из UPSTREAM для этого файла" -ForegroundColor $Colors.Warning
        Write-Host "  [V] - Открыть файл в VS Code для ручного разрешения" -ForegroundColor $Colors.Info
        Write-Host "  [L] - Оставить ВАШУ версию для ВСЕХ оставшихся конфликтов (автоматически)" -ForegroundColor $Colors.Success
        Write-Host "  [A] - Прервать слияние и выйти" -ForegroundColor $Colors.Error
        Write-Host ""

        do {
            $Choice = Read-Host "Ваш выбор (N/Y/V/L/A) [по умолчанию: N]"

            if ([string]::IsNullOrWhiteSpace($Choice)) {
                $Choice = 'N'
            } else {
                $Choice = $Choice.ToUpper()
            }

            switch ($Choice) {
                'N' {
                    # Оставить нашу версию для текущего файла
                    git checkout --ours $File
                    git add $File
                    Write-Host "  ? Оставлена ваша версия: $File" -ForegroundColor $Colors.Success
                    break
                }
                'Y' {
                    # Взять версию из upstream для текущего файла
                    git checkout --theirs $File
                    git add $File
                    Write-Host "  ? Заменена на версию из upstream: $File" -ForegroundColor $Colors.Warning
                    break
                }
                'V' {
                    # Открыть в VS Code
                    Write-Host "  Открывается VS Code для файла: $File" -ForegroundColor $Colors.Info
                    code --wait $File
                    Write-Host ""
                    Write-Host "  После разрешения конфликта в VS Code:" -ForegroundColor $Colors.Warning
                    Write-Host "    1. Сохраните файл (Ctrl+S)" -ForegroundColor $Colors.Warning
                    Write-Host "    2. Закройте вкладку merge-редактора" -ForegroundColor $Colors.Warning
                    Write-Host ""
                    Read-Host "  Нажмите Enter после выполнения этих действий"
                    
                    # Проверяем, был ли файл добавлен
                    $FileStatus = git status --porcelain $File
                    if ($FileStatus -match "^[MARC]") {
                        Write-Host "  ? Файл добавлен в индекс" -ForegroundColor $Colors.Success
                    } else {
                        Write-Host "  ? Файл не добавлен в индекс. Добавляем автоматически..." -ForegroundColor $Colors.Warning
                        git add $File
                    }
                    break
                }
                'L' {
                    # Оставить нашу версию для ВСЕХ оставшихся файлов
                    Write-Host ""
                    Write-Host "Применение вашей версии для всех оставшихся конфликтов..." -ForegroundColor $Colors.Info
                    
                    # Обрабатываем текущий файл
                    git checkout --ours $File
                    git add $File
                    Write-Host "  ? Оставлена ваша версия: $File" -ForegroundColor $Colors.Success
                    
                    # Обрабатываем все остальные конфликтные файлы
                    foreach ($RemainingFile in $ConflictFiles) {
                        if ($RemainingFile -eq $File) { continue }
                        
                        # Проверяем, не был ли файл уже разрешён
                        $RemainingStatus = git diff --name-only --diff-filter=U $RemainingFile
                        if ($RemainingStatus) {
                            git checkout --ours $RemainingFile
                            git add $RemainingFile
                            Write-Host "  ? Оставлена ваша версия: $RemainingFile" -ForegroundColor $Colors.Success
                        }
                    }
                    
                    $ApplyAllOurs = $true
                    Write-Host ""
                    Write-Host "? Все конфликты разрешены в пользу вашей версии" -ForegroundColor $Colors.Success
                    break outerForeach
                }
                'A' {
                    # Прервать слияние
                    Write-Host ""
                    Write-Host "Слияние прервано пользователем." -ForegroundColor $Colors.Error

                    if ($Strategy -eq 'Merge') {
                        git merge --abort
                    } else {
                        git rebase --abort
                    }

                    if ($StashCreated) {
                        Write-Host "Восстановление сохраненных изменений..." -ForegroundColor $Colors.Info
                        git stash pop
                    }

                    exit 1
                }
                default {
                    Write-Host ""
                    Write-Host "  ? Неверный выбор. Пожалуйста, введите N, Y, V, L или A." -ForegroundColor $Colors.Error
                    Write-Host ""
                    # Повторно выводим подсказки при неверном выборе
                    Write-Host "Выберите действие:" -ForegroundColor $Colors.Question
                    Write-Host "  [N] - Оставить ВАШУ версию для этого файла (по умолчанию)" -ForegroundColor $Colors.Success
                    Write-Host "  [Y] - Заменить на версию из UPSTREAM для этого файла" -ForegroundColor $Colors.Warning
                    Write-Host "  [V] - Открыть файл в VS Code для ручного разрешения" -ForegroundColor $Colors.Info
                    Write-Host "  [L] - Оставить ВАШУ версию для ВСЕХ оставшихся конфликтов (автоматически)" -ForegroundColor $Colors.Success
                    Write-Host "  [A] - Прервать слияние и выйти" -ForegroundColor $Colors.Error
                    Write-Host ""
                }
            }
        } while ($true)

        Write-Host ""
    }

    # Завершаем слияние
    Write-Host ""
    Write-Host "Все конфликты обработаны. Завершение слияния..." -ForegroundColor $Colors.Info

    if ($Strategy -eq 'Merge') {
        git commit --no-edit
    } else {
        git rebase --continue
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Не удалось завершить слияние!"
        if ($StashCreated) { git stash pop }
        exit $LASTEXITCODE
    }

} else {
    # Конфликтов нет, просто коммитим (если merge --no-commit)
    if ($Strategy -eq 'Merge') {
        git commit --no-edit
    }

    Write-Host "? $Strategy выполнен успешно без конфликтов!" -ForegroundColor $Colors.Success
}

# ============================================================================
# ОТПРАВКА ИЗМЕНЕНИЙ В ORIGIN
# ============================================================================
Write-Host ""
Write-Host "Отправка изменений в ваш репозиторий..." -ForegroundColor $Colors.Info

if ($Strategy -eq 'Rebase') {
    git push --force-with-lease origin $CurrentBranch
} else {
    git push origin $CurrentBranch
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "? Изменения отправлены в origin" -ForegroundColor $Colors.Success
} else {
    Write-Error "Не удалось отправить изменения в origin!"
    Write-Host ""
    Write-Host "Возможные причины:" -ForegroundColor $Colors.Warning
    Write-Host "  1. В origin есть коммиты, которых нет локально" -ForegroundColor $Colors.Warning
    Write-Host "  2. Решите проблему командой: git pull --rebase origin $CurrentBranch" -ForegroundColor $Colors.Warning
    Write-Host "  3. Или (с осторожностью): git push --force-with-lease origin $CurrentBranch" -ForegroundColor $Colors.Warning
    
    if ($StashCreated) { git stash pop }
    exit $LASTEXITCODE
}

# ============================================================================
# ВОССТАНОВЛЕНИЕ СОХРАНЁННЫХ ИЗМЕНЕНИЙ ИЗ STASH
# ============================================================================
if ($StashCreated) {
    Write-Host ""
    Write-Host "Восстановление сохраненных изменений..." -ForegroundColor $Colors.Info
    git stash pop

    if ($LASTEXITCODE -eq 0) {
        Write-Host "? Изменения восстановлены из stash" -ForegroundColor $Colors.Success
    } else {
        Write-Warning "Не удалось автоматически восстановить изменения из stash. Используйте: git stash pop"
    }
}

# ============================================================================
# ФИНАЛЬНОЕ СООБЩЕНИЕ
# ============================================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor $Colors.Success
Write-Host "? Синхронизация завершена успешно!" -ForegroundColor $Colors.Success
Write-Host "========================================" -ForegroundColor $Colors.Success