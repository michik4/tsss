#!/bin/sh

# --- Настройка цветов ---
if [ "$(tput colors)" -ge 8 ]; then
  RED=$(tput setaf 1); GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3); BLUE=$(tput setaf 4); RESET=$(tput sgr0)
else
  RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
fi

# --- Глобальная переменная для хранения вывода команд ---
SHRUN_OUTPUT=""

# --- Анимированный спиннер для длительных команд ---
spinner() {
    local message=$1; local pid=$2; local spin_chars="/-\|"
    while kill -0 $pid 2>/dev/null; do
        for i in $(seq 0 3); do
            printf "\r%s [%s]" "$message" "${spin_chars:$i:1}" >&2; sleep 0.1
        done
    done
}

# --- Улучшенная обертка для запуска команд с обрезкой длинных строк ---
shrun() {
    SHRUN_OUTPUT=""
    local original_message="Executing: '$*'"
    local message="$original_message"
    local terminal_width=${COLUMNS:-80}
    local max_len=$((terminal_width - 5))

    if [ ${#message} -gt $max_len ]; then
        message="$(echo "$message" | cut -c1-$((max_len-3)))..."
    fi

    local tmp_output; tmp_output=$(mktemp)
    "$@" > "$tmp_output" 2>&1 &
    local pid=$!
    spinner "$message" $pid
    wait $pid
    local exit_code=$?
    SHRUN_OUTPUT=$(cat "$tmp_output")
    rm -f "$tmp_output"

    if [ $exit_code -eq 0 ]; then
        printf "\r%s... %s\e[K\n" "$original_message" "${GREEN}Done.${RESET}" >&2
    else
        printf "\r%s... %s\e[K\n" "$original_message" "${RED}Failed${RESET} (code: $exit_code)." >&2
        echo "--- Program output ---" >&2; echo "$SHRUN_OUTPUT" >&2; echo "----------------------" >&2
    fi
    return $exit_code
}

# --- УЛУЧШЕННАЯ функция для очистки существующего проекта ---
cleanup_project() {
    echo "${YELLOW}Cleaning up existing project files...${RESET}"
    rm -rf src dist node_modules .husky
    # Удаляем все возможные варианты конфигов (старые и новые)
    rm -f package.json package-lock.json tsconfig.json \
          eslint.config.js .eslintrc.js \
          .prettierrc .prettierrc.json \
          .prettierignore .prettierignore.json \
          vitest.config.ts
}


# --- Начало основной логики скрипта ---

echo "${BLUE}--- TypeScript Project Bootstrapper ---${RESET}"
echo ""

# -----------------------------------------------------------------------------
# 1. ПРОВЕРКА СРЕДЫ
# -----------------------------------------------------------------------------
echo "Step 1: Checking prerequisites..."
if ! command -v node >/dev/null 2>&1; then echo "${RED}Error${RESET}: Node.js is not installed." >&2; exit 127; fi
if ! command -v npm >/dev/null 2>&1; then echo "${RED}Error${RESET}: NPM is not installed." >&2; exit 127; fi
if shrun node --version; then echo "Node version: ${SHRUN_OUTPUT}"; else echo "${RED}Failed to get Node.js version.${RESET}" >&2; exit 1; fi
if shrun npm --version; then echo "NPM version: ${SHRUN_OUTPUT}"; else echo "${RED}Failed to get NPM version.${RESET}" >&2; exit 1; fi
echo "${GREEN}Prerequisites check passed.${RESET}"; echo ""

# -----------------------------------------------------------------------------
# 2. ПРОВЕРКА НА СУЩЕСТВУЮЩИЙ ПРОЕКТ (БЕЗОПАСНОСТЬ)
# -----------------------------------------------------------------------------
echo "Step 2: Checking for existing project..."
if [ -f "package.json" ] || [ -d "src" ]; then
    echo "${YELLOW}Warning:${RESET} Existing project files detected."
    read -p "Do you want to DELETE them and start over? [y/N]: " confirm_delete
    confirm_delete=$(echo "$confirm_delete" | tr '[:upper:]' '[:lower:]')

    if [ "$confirm_delete" = "y" ] || [ "$confirm_delete" = "yes" ]; then
        cleanup_project
        echo "${GREEN}Cleanup complete. Proceeding with setup.${RESET}"
    else
        echo "${RED}Aborting. No files were changed.${RESET}"
        exit 0
    fi
else
    echo "Directory is clean, proceeding."
fi
echo ""

# -----------------------------------------------------------------------------
# 3. СБОР ИНФОРМАЦИИ И СОЗДАНИЕ PACKAGE.JSON
# -----------------------------------------------------------------------------
echo "Step 3: Initializing project..."
read -p "Enter project name (my-ts-app): " project_name
project_name=${project_name:-my-ts-app}
read -p "Enter project description: " project_desc; echo ""

if ! mkdir -p src; then echo "${RED}Error: Could not create 'src' directory.${RESET}" >&2; exit 1; fi
echo "Directory 'src' created."

cat > package.json << EOF
{
    "name": "${project_name}",
    "version": "0.0.1",
    "description": "${project_desc}",
    "main": "dist/index.js",
    "type": "module",
    "scripts": { "dev": "tsx watch src/index.ts", "build": "tsc", "start": "node dist/index.js", "test": "vitest", "test:watch": "vitest --watch", "test:coverage": "vitest run --coverage", "lint": "eslint .", "lint:fix": "eslint . --fix", "format": "prettier --write .", "format:check": "prettier --check .", "prepare": "husky install" },
    "lint-staged": { "*.{js,ts}": [ "eslint --fix", "prettier --write" ] }
}
EOF
echo "package.json created."; echo ""

# -----------------------------------------------------------------------------
# 4. УСТАНОВКА ЗАВИСИМОСТЕЙ
# -----------------------------------------------------------------------------
echo "Step 4: Installing dependencies..."
DEPENDENCIES="zod"
DEV_DEPENDENCIES="typescript @types/node tsx eslint typescript-eslint globals prettier eslint-config-prettier husky lint-staged vitest @vitest/coverage-v8"
echo "Installing runtime dependencies..."
if ! shrun npm install ${DEPENDENCIES}; then echo "${RED}Failed to install dependencies.${RESET}" >&2; exit 1; fi
echo "Installing development dependencies (this may take a minute)..."
if ! shrun npm install --save-dev ${DEV_DEPENDENCIES}; then echo "${RED}Failed to install dev dependencies.${RESET}" >&2; exit 1; fi
echo "${GREEN}All dependencies installed successfully.${RESET}"; echo ""

# -----------------------------------------------------------------------------
# 5. СОЗДАНИЕ ОСТАЛЬНЫХ КОНФИГУРАЦИОННЫХ ФАЙЛОВ
# -----------------------------------------------------------------------------
echo "Step 5: Creating configuration files..."
cat > tsconfig.json << EOF
{ "compilerOptions": { "target": "ES2022", "module": "NodeNext", "moduleResolution": "NodeNext", "esModuleInterop": true, "sourceMap": true, "outDir": "./dist", "rootDir": "./src", "strict": true, "forceConsistentCasingInFileNames": true, "skipLibCheck": true }, "include": ["src/**/*", "eslint.config.js"], "exclude": ["node_modules", "dist"] }
EOF
echo "tsconfig.json ${GREEN}OK${RESET}"

cat > eslint.config.js << EOF
import globals from "globals";
import tseslint from "typescript-eslint";
import eslintConfigPrettier from "eslint-config-prettier";
export default [ { languageOptions: { globals: { ...globals.node, }, }, }, ...tseslint.configs.recommended, eslintConfigPrettier, ];
EOF
echo "eslint.config.js ${GREEN}OK${RESET}"

cat > .prettierrc << EOF
{ "semi": true, "singleQuote": true, "tabWidth": 2, "trailingComma": "all", "printWidth": 80 }
EOF
echo ".prettierrc ${GREEN}OK${RESET}"

cat > .prettierignore << EOF
node_modules
dist
coverage
EOF
echo ".prettierignore ${GREEN}OK${RESET}"

cat > vitest.config.ts << EOF
import { defineConfig } from 'vitest/config';
export default defineConfig({ test: { globals: true, environment: 'node', include: ['src/**/*.test.ts'], coverage: { provider: 'v8', reporter: ['text', 'json', 'html'], reportsDirectory: './coverage' } }, });
EOF
echo "vitest.config.ts ${GREEN}OK${RESET}"; echo ""

# -----------------------------------------------------------------------------
# 6. НАСТРОЙКА GIT И HUSKY
# -----------------------------------------------------------------------------
echo "Step 6: Initializing Git and setting up Husky..."
if ! command -v git >/dev/null 2>&1; then
  echo "${YELLOW}Warning${RESET}: Git not found. Skipping Git & Husky setup." >&2
else
  if ! shrun git init; then echo "${RED}Failed to initialize Git repository.${RESET}" >&2
  else
    if shrun npm run prepare; then
      if echo "npx lint-staged" > .husky/pre-commit; then
          chmod +x .husky/pre-commit; echo "${GREEN}Husky pre-commit hook created successfully.${RESET}"
      else echo "${RED}Failed to create Husky pre-commit hook file.${RESET}" >&2; fi
    else echo "${RED}Failed to run 'npm run prepare' for Husky setup.${RESET}" >&2; fi
  fi
fi
echo ""

# -----------------------------------------------------------------------------
# 7. ФИНАЛЬНАЯ ПРОВЕРКА
# -----------------------------------------------------------------------------
echo "Step 7: Verifying the setup..."
echo "console.log('Hello from TypeScript!');" > src/index.ts
if ! shrun npm run build; then echo "${RED}Project build failed.${RESET}" >&2; exit 1; fi
if ! shrun npm run start; then echo "${RED}Failed to start the application.${RESET}" >&2; exit 1
else
    echo "--- Application Output ---"; echo "${SHRUN_OUTPUT}"; echo "--------------------------"
fi
echo ""

# --- Завершение ---
echo "${GREEN}Project '${project_name}' has been successfully created!${RESET}"
echo "You can start developing by running: ${YELLOW}npm run dev${RESET}"
