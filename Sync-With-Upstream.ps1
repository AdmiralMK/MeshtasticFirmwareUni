# Sync-With-Upstream.ps1
# Скрипт для синхронизации вашего форка с оригинальным репозиторием meshtastic/firmware
# Источник обновлений: ветка "develop" из upstream (или указанная через параметр)
# Приоритет: ваши изменения > изменения из upstream
# При конфликтах: интерактивное решение с приоритетом ваших файлов

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


# Проверяем, нет ли незавершённого слияния или rebase
$IsMergeInProgress = Test-Path .git/MERGE_HEAD
$IsRebaseInProgress = (Test-Path .git/rebase-merge) -or (Test-Path .git/rebase-apply)

if ($IsMergeInProgress -or $IsRebaseInProgress) {
    Write-Host ""
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
            Write-Host "? Слияние отменено. Можно продолжить работу." -ForegroundColor $Colors.Success
        }
        'C' {
            Write-Host "Завершение слияния с приоритетом ваших файлов..." -ForegroundColor $Colors.Info
            $ConflictFiles = git diff --name-only --diff-filter=U
            foreach ($File in ($ConflictFiles -split "`n")) {
                if (-not [string]::IsNullOrWhiteSpace($File)) {
                    git checkout --ours $File
                    git add $File
                }
            }
            if ($IsMergeInProgress) {
                git commit --no-edit
            } else {
                git rebase --continue
            }
            Write-Host "? Слияние завершено." -ForegroundColor $Colors.Success
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


# Проверяем, находимся ли мы в Git-репозитории
if (-not (Test-Path .git)) {
    Write-Error "Текущая папка не является Git-репозиторием!"
    exit 1
}

# Получаем текущую локальную ветку
$CurrentBranch = git rev-parse --abbrev-ref HEAD
Write-Host "Локальная ветка: $CurrentBranch" -ForegroundColor $Colors.Info
Write-Host "Целевая ветка upstream: $UpstreamBranch" -ForegroundColor $Colors.Info

# Проверяем наличие upstream remote
$Remotes = git remote -v
if (-not ($Remotes -match "upstream")) {
    Write-Error "Remote 'upstream' не найден! Добавьте его командой:"
    Write-Host "git remote add upstream https://github.com/meshtastic/firmware.git" -ForegroundColor $Colors.Warning
    exit 1
}

# Сохраняем несохраненные изменения в stash
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

# Получаем последние изменения из upstream
Write-Host ""
Write-Host "Получение изменений из upstream..." -ForegroundColor $Colors.Info
git fetch upstream

if ($LASTEXITCODE -ne 0) {
    Write-Error "Не удалось получить изменения из upstream!"
    if ($StashCreated) { git stash pop }
    exit $LASTEXITCODE
}

# Проверяем, существует ли указанная ветка в upstream
$UpstreamRefExists = git branch -r | Select-String "upstream/$UpstreamBranch"
if (-not $UpstreamRefExists) {
    Write-Error "Ветка 'upstream/$UpstreamBranch' не найдена в upstream!"
    Write-Host "Доступные ветки upstream:" -ForegroundColor $Colors.Warning
    git branch -r | Select-String "upstream/"
    if ($StashCreated) { git stash pop }
    exit 1
}

# Проверяем, есть ли новые коммиты для слияния
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

# Выполняем слияние
Write-Host ""
Write-Host "Выполнение $Strategy с upstream/$UpstreamBranch..." -ForegroundColor $Colors.Info

if ($Strategy -eq 'Merge') {
    # --no-commit останавливает слияние при конфликтах и не создаёт коммит автоматически
    git merge upstream/$UpstreamBranch --no-commit --no-ff
} else {
    git rebase upstream/$UpstreamBranch
}

# Проверяем наличие конфликтов
$Conflicts = git diff --name-only --diff-filter=U

if ($Conflicts) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor $Colors.Error
    Write-Host "ОБНАРУЖЕНЫ КОНФЛИКТЫ!" -ForegroundColor $Colors.Error
    Write-Host "========================================" -ForegroundColor $Colors.Error
    Write-Host ""
    Write-Host "Следующие файлы имеют конфликты:" -ForegroundColor $Colors.Warning

    $ConflictFiles = @($Conflicts -split "`n")
    for ($i = 0; $i -lt $ConflictFiles.Count; $i++) {
        Write-Host "  $($i + 1). $($ConflictFiles[$i])" -ForegroundColor $Colors.Warning
    }

    Write-Host ""
    Write-Host "Для каждого файла выберите действие:" -ForegroundColor $Colors.Question
    Write-Host "  [N] - Оставить ВАШУ версию (по умолчанию, рекомендуется)" -ForegroundColor $Colors.Success
    Write-Host "  [Y] - Заменить на версию из UPSTREAM" -ForegroundColor $Colors.Warning
    Write-Host "  [V] - Открыть файл в VS Code для ручного разрешения" -ForegroundColor $Colors.Info
    Write-Host "  [A] - Прервать слияние и выйти" -ForegroundColor $Colors.Error
    Write-Host ""

    foreach ($File in $ConflictFiles) {
        if ([string]::IsNullOrWhiteSpace($File)) { continue }

        Write-Host "Файл: $File" -ForegroundColor $Colors.Info

        do {
            $Choice = Read-Host "Ваш выбор (N/Y/V/A) [по умолчанию: N]"

            if ([string]::IsNullOrWhiteSpace($Choice)) {
                $Choice = 'N'
            } else {
                $Choice = $Choice.ToUpper()
            }

            switch ($Choice) {
                'N' {
                    # Оставить нашу версию
                    git checkout --ours $File
                    git add $File
                    Write-Host "  ? Оставлена ваша версия" -ForegroundColor $Colors.Success
                    break
                }
                'Y' {
                    # Взять версию из upstream
                    git checkout --theirs $File
                    git add $File
                    Write-Host "  ? Заменена на версию из upstream" -ForegroundColor $Colors.Warning
                    break
                }
                'V' {
                    # Открыть в VS Code
                    Write-Host "  Открывается VS Code для файла: $File" -ForegroundColor $Colors.Info
                    code --wait $File
                    Write-Host "  После разрешения конфликта в VS Code, добавьте файл:" -ForegroundColor $Colors.Warning
                    Write-Host "    git add $File" -ForegroundColor $Colors.Info
                    Write-Host "  Затем нажмите Enter для продолжения..." -ForegroundColor $Colors.Warning
                    Read-Host
                    break
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
                    Write-Host "  Неверный выбор. Пожалуйста, введите N, Y, V или A." -ForegroundColor $Colors.Error
                }
            }
        } while ($true)

        Write-Host ""
    }

    # Завершаем слияние
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

# Отправляем изменения в origin
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
    if ($StashCreated) { git stash pop }
    exit $LASTEXITCODE
}

# Восстанавливаем сохраненные изменения из stash
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

Write-Host ""
Write-Host "========================================" -ForegroundColor $Colors.Success
Write-Host "? Синхронизация завершена успешно!" -ForegroundColor $Colors.Success
Write-Host "========================================" -ForegroundColor $Colors.Success