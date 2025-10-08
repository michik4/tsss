#Requires -Version 5.1
<#
.SYNOPSIS
    TypeScript Simple Setup Script (TSSS) for Windows.
.DESCRIPTION
    An interactive PowerShell script that completely automates the creation of a modern,
    production-ready Node.js project using TypeScript. It sets up tooling like
    ESLint v9, Prettier, Vitest, Husky, and more.
.AUTHOR
    Generated based on michik4/tsss linux script.
#>

# -----------------------------------------------------------------------------
# SETUP AND HELPER FUNCTIONS
# -----------------------------------------------------------------------------

# --- Настройка цветов ---
$colors = @{
    "Red"    = [System.ConsoleColor]::Red
    "Green"  = [System.ConsoleColor]::Green
    "Yellow" = [System.ConsoleColor]::Yellow
    "Blue"   = [System.ConsoleColor]::Cyan # Cyan is more readable than DarkBlue in default PS
    "Reset"  = [System.Console]::ForegroundColor
}

# --- Глобальная переменная для хранения вывода команд ---
$Global:SHRUN_OUTPUT = ""

# --- Обертка для запуска команд с красивым выводом ---
function Start-LongRunningTask {
    param(
        [string]$Command,
        [string[]]$Arguments
    )

    $Global:SHRUN_OUTPUT = ""
    $originalMessage = "Executing: '$Command $($Arguments -join ' ')'"
    $message = $originalMessage

    # Обрезаем сообщение, если оно слишком длинное
    try {
        $terminalWidth = $Host.UI.RawUI.WindowSize.Width
        $maxLength = $terminalWidth - 5
        if ($message.Length -gt $maxLength) {
            $message = "$($message.Substring(0, $maxLength - 3))..."
        }
    } catch {
        # Fails in non-interactive sessions, fallback
    }

    # Спиннер
    $spinChars = @('/', '-', '\', '|')
    $spinnerIndex = 0

    # Запускаем команду в фоновом задании
    $scriptBlock = [Scriptblock]::Create("& $Command $Arguments *>&1")
    $job = Start-Job -ScriptBlock $scriptBlock

    Write-Host -NoNewline "$message ["
    while ($job.State -eq 'Running') {
        Write-Host -NoNewline "`b$($spinChars[$spinnerIndex++ % $spinChars.Length])]"
        Start-Sleep -Milliseconds 100
    }
    Write-Host "`b]... " -NoNewline

    $Global:SHRUN_OUTPUT = Receive-Job -Job $job

    if ($job.State -eq 'Completed') {
        Write-Host -ForegroundColor $colors.Green "Done."
        Remove-Job -Job $job
        return $true
    } else {
        Write-Host -ForegroundColor $colors.Red "Failed."
        Write-Host -ForegroundColor $colors.Red "--- Program output ---"
        Write-Host -ForegroundColor $colors.Red $Global:SHRUN_OUTPUT
        Write-Host -ForegroundColor $colors.Red "----------------------"
        Remove-Job -Job $job
        return $false
    }
}

# --- Функция для очистки существующего проекта ---
function Cleanup-Project {
    Write-Host -ForegroundColor $colors.Yellow "Cleaning up existing project files..."
    $itemsToRemove = @(
        ".\src", ".\dist", ".\node_modules", ".\.husky",
        ".\package.json", ".\package-lock.json", ".\tsconfig.json",
        ".\eslint.config.js", ".\.eslintrc.js",
        ".\.prettierrc", ".\.prettierrc.json",
        ".\.prettierignore", ".\.prettierignore.json",
        ".\vitest.config.ts"
    )
    foreach ($item in $itemsToRemove) {
        if (Test-Path $item) {
            Remove-Item -Path $item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# --- Начало основной логики скрипта ---

Write-Host -ForegroundColor $colors.Blue "--- TypeScript Project Bootstrapper for Windows ---"
Write-Host ""

# -----------------------------------------------------------------------------
# 1. ПРОВЕРКА СРЕДЫ
# -----------------------------------------------------------------------------
Write-Host "Step 1: Checking prerequisites..."
$nodeCheck = Get-Command node.exe -ErrorAction SilentlyContinue
$npmCheck = Get-Command npm.cmd -ErrorAction SilentlyContinue

if (-not $nodeCheck) { Write-Host -ForegroundColor $colors.Red "Error: Node.js is not installed or not in PATH."; exit 1 }
if (-not $npmCheck) { Write-Host -ForegroundColor $colors.Red "Error: NPM is not installed or not in PATH."; exit 1 }

if (Start-LongRunningTask "node" "--version") { Write-Host "Node version: $($Global:SHRUN_OUTPUT)" } else { Write-Host -ForegroundColor $colors.Red "Failed to get Node.js version."; exit 1 }
if (Start-LongRunningTask "npm" "--version") { Write-Host "NPM version: $($Global:SHRUN_OUTPUT)" } else { Write-Host -ForegroundColor $colors.Red "Failed to get NPM version."; exit 1 }
Write-Host -ForegroundColor $colors.Green "Prerequisites check passed."; Write-Host ""

# -----------------------------------------------------------------------------
# 2. ПРОВЕРКА НА СУЩЕСТВУЮЩИЙ ПРОЕКТ (БЕЗОПАСНОСТЬ)
# -----------------------------------------------------------------------------
Write-Host "Step 2: Checking for existing project..."
if ((Test-Path -Path ".\package.json" -PathType Leaf) -or (Test-Path -Path ".\src" -PathType Container)) {
    Write-Host -ForegroundColor $colors.Yellow "Warning: Existing project files detected."
    $confirmDelete = Read-Host "Do you want to DELETE them and start over? [y/N]"
    if ($confirmDelete -in @("y", "yes")) {
        Cleanup-Project
        Write-Host -ForegroundColor $colors.Green "Cleanup complete. Proceeding with setup."
    } else {
        Write-Host -ForegroundColor $colors.Red "Aborting. No files were changed."
        exit 0
    }
} else {
    Write-Host "Directory is clean, proceeding."
}
Write-Host ""

# -----------------------------------------------------------------------------
# 3. СБОР ИНФОРМАЦИИ И СОЗДАНИЕ PACKAGE.JSON
# -----------------------------------------------------------------------------
Write-Host "Step 3: Initializing project..."
$projectName = Read-Host "Enter project name (my-ts-app)"
if ([string]::IsNullOrWhiteSpace($projectName)) { $projectName = "my-ts-app" }
Write-Host "Project name set to: $projectName"
$projectDesc = Read-Host "Enter project description"
Write-Host ""

New-Item -Path ".\src" -ItemType Directory -Force | Out-Null
Write-Host "Directory 'src' created."

$packageJsonContent = @"
{
    "name": "$projectName",
    "version": "0.0.1",
    "description": "$projectDesc",
    "main": "dist/index.js",
    "type": "module",
    "scripts": {
        "dev": "tsx watch src/index.ts",
        "build": "tsc",
        "start": "node dist/index.js",
        "test": "vitest",
        "test:watch": "vitest --watch",
        "test:coverage": "vitest run --coverage",
        "lint": "eslint .",
        "lint:fix": "eslint . --fix",
        "format": "prettier --write .",
        "format:check": "prettier --check .",
        "prepare": "husky install"
    },
    "lint-staged": {
        "*.{js,ts}": [
            "eslint --fix",
            "prettier --write"
        ]
    }
}
"@
Set-Content -Path ".\package.json" -Value $packageJsonContent -Encoding utf8
Write-Host "package.json created."; Write-Host ""

# -----------------------------------------------------------------------------
# 4. УСТАНОВКА ЗАВИСИМОСТЕЙ
# -----------------------------------------------------------------------------
Write-Host "Step 4: Installing dependencies..."
$dependencies = "zod"
$devDependencies = "typescript @types/node tsx eslint typescript-eslint globals prettier eslint-config-prettier husky lint-staged vitest @vitest/coverage-v8"

Write-Host "Installing runtime dependencies..."
if (-not (Start-LongRunningTask "npm" "install", $dependencies)) { Write-Host -ForegroundColor $colors.Red "Failed to install dependencies."; exit 1 }

Write-Host "Installing development dependencies (this may take a minute)..."
if (-not (Start-LongRunningTask "npm" "install", "--save-dev", $devDependencies)) { Write-Host -ForegroundColor $colors.Red "Failed to install dev dependencies."; exit 1 }
Write-Host -ForegroundColor $colors.Green "All dependencies installed successfully."; Write-Host ""

# -----------------------------------------------------------------------------
# 5. СОЗДАНИЕ ОСТАЛЬНЫХ КОНФИГУРАЦИОННЫХ ФАЙЛОВ
# -----------------------------------------------------------------------------
Write-Host "Step 5: Creating configuration files..."
@"
{ "compilerOptions": { "target": "ES2022", "module": "NodeNext", "moduleResolution": "NodeNext", "esModuleInterop": true, "sourceMap": true, "outDir": "./dist", "rootDir": "./src", "strict": true, "forceConsistentCasingInFileNames": true, "skipLibCheck": true }, "include": ["src/**/*", "eslint.config.js"], "exclude": ["node_modules", "dist"] }
"@ | Set-Content -Path ".\tsconfig.json" -Encoding utf8
Write-Host -ForegroundColor $colors.Green "tsconfig.json OK"

@"
import globals from "globals";
import tseslint from "typescript-eslint";
import eslintConfigPrettier from "eslint-config-prettier";
export default [ { languageOptions: { globals: { ...globals.node, }, }, }, ...tseslint.configs.recommended, eslintConfigPrettier, ];
"@ | Set-Content -Path ".\eslint.config.js" -Encoding utf8
Write-Host -ForegroundColor $colors.Green "eslint.config.js OK"

@"
{ "semi": true, "singleQuote": true, "tabWidth": 2, "trailingComma": "all", "printWidth": 80 }
"@ | Set-Content -Path ".\.prettierrc" -Encoding utf8
Write-Host -ForegroundColor $colors.Green ".prettierrc OK"

@"
node_modules
dist
coverage
"@ | Set-Content -Path ".\.prettierignore" -Encoding utf8
Write-Host -ForegroundColor $colors.Green ".prettierignore OK"

@"
import { defineConfig } from 'vitest/config';
export default defineConfig({ test: { globals: true, environment: 'node', include: ['src/**/*.test.ts'], coverage: { provider: 'v8', reporter: ['text', 'json', 'html'], reportsDirectory: './coverage' } }, });
"@ | Set-Content -Path ".\vitest.config.ts" -Encoding utf8
Write-Host -ForegroundColor $colors.Green "vitest.config.ts OK"; Write-Host ""

# -----------------------------------------------------------------------------
# 6. НАСТРОЙКА GIT И HUSKY
# -----------------------------------------------------------------------------
Write-Host "Step 6: Initializing Git and setting up Husky..."
$gitCheck = Get-Command git.exe -ErrorAction SilentlyContinue
if (-not $gitCheck) {
    Write-Host -ForegroundColor $colors.Yellow "Warning: Git not found. Skipping Git & Husky setup."
} else {
    if (-not (Start-LongRunningTask "git" "init")) { Write-Host -ForegroundColor $colors.Red "Failed to initialize Git repository." } else {
        if (Start-LongRunningTask "npm" "run", "prepare") {
            # Создаем хук напрямую. В Windows не нужен chmod.
            Set-Content -Path ".\.husky\pre-commit" -Value "npx lint-staged" -Encoding utf8
            Write-Host -ForegroundColor $colors.Green "Husky pre-commit hook created successfully."
        } else {
            Write-Host -ForegroundColor $colors.Red "Failed to run 'npm run prepare' for Husky setup."
        }
    }
}
Write-Host ""

# -----------------------------------------------------------------------------
# 7. ФИНАЛЬНАЯ ПРОВЕРКА
# -----------------------------------------------------------------------------
Write-Host "Step 7: Verifying the setup..."
Set-Content -Path ".\src\index.ts" -Value "console.log('Hello from TypeScript!');" -Encoding utf8
if (-not (Start-LongRunningTask "npm" "run", "build")) { Write-Host -ForegroundColor $colors.Red "Project build failed."; exit 1 }
if (-not (Start-LongRunningTask "npm" "run", "start")) { Write-Host -ForegroundColor $colors.Red "Failed to start the application."; exit 1 } else {
    Write-Host "--- Application Output ---"; Write-Host $Global:SHRUN_OUTPUT; Write-Host "--------------------------"
}
Write-Host ""

# --- Завершение ---
Write-Host -ForegroundColor $colors.Green "Project '$projectName' has been successfully created!"
Write-Host "You can start developing by running: " -NoNewline; Write-Host -ForegroundColor $colors.Yellow "npm run dev"
