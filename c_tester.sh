#!/usr/bin/env bash
# C Project Tester v0.1.4
# Автоматизированное тестирование C проектов
# Лицензия: MIT

# ========================
# КОНФИГУРАЦИЯ
# ========================
readonly DEFAULT_SRC_DIR="src"
readonly DEFAULT_REPORT_FILE="test_report.txt"
readonly DEFAULT_TEST_DATA_FILE="test_data.txt"
readonly CONFIG_FILE=".c_tester.conf"
readonly VERSION="0.1.3"

# ========================
# НАСТРОЙКИ ЦВЕТОВ
# ========================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# ========================
# ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
# ========================
declare -a SELECTED_FILES=()
declare SRC_DIR=""
declare REPORT_FILE=""
declare TEST_DATA_FILE=""
declare CURRENT_DIR=""

# ========================
# ОСНОВНЫЕ ФУНКЦИИ
# ========================

init_config() {
    SRC_DIR="$DEFAULT_SRC_DIR"
    REPORT_FILE="$DEFAULT_REPORT_FILE"
    TEST_DATA_FILE="$DEFAULT_TEST_DATA_FILE"
    save_config
}

save_config() {
    cat > "$CONFIG_FILE" << EOF
# C Tester Configuration
SRC_DIR="$SRC_DIR"
REPORT_FILE="$REPORT_FILE"
TEST_DATA_FILE="$TEST_DATA_FILE"
EOF
}

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        init_config
    fi
}

copy_clang_format() {
    local source_file="materials/linters/.clang-format"
    local target_file="$SRC_DIR/.clang-format"
    
    show_section "Копирование .clang-format"
    
    if [[ ! -f "$source_file" ]]; then
        log_error "Исходный файл не найден: $source_file"
        return 1
    fi
    
    if cp "$source_file" "$target_file"; then
        log_success "Файл .clang-format успешно скопирован в $SRC_DIR/"
    else
        log_error "Ошибка при копировании файла"
        return 1
    fi
}

# ========================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ========================

log_success() {
    echo -e "${GREEN}[✓] $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

log_error() {
    echo -e "${RED}[✗] $1${NC}"
}

show_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

validate_src_dir() {
    if [[ ! -d "$SRC_DIR" ]]; then
        log_error "Папка $SRC_DIR не найдена в текущей директории"
        return 1
    fi
    return 0
}

check_dependencies() {
    local missing=()
    local tools=("gcc" "clang-format" "valgrind" "cppcheck")

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warning "Отсутствуют зависимости: ${missing[*]}"
        read -p "Установить недостающие зависимости? (y/n): " answer
        if [[ "$answer" == "y" ]]; then
            sudo apt-get install -y "${missing[@]}"
        fi
        return 1
    fi
    return 0
}

# ========================
# ОПЕРАЦИИ С ФАЙЛАМИ
# ========================

select_files() {
    show_section "Выбор файлов для тестирования"
    
    local files=()
    local i=0
    
    pushd "$SRC_DIR" > /dev/null || return 1
    
    echo "Доступные .c файлы в $SRC_DIR:"
    echo "-----------------------------"
    
    for file in *.c; do
        if [[ -f "$file" ]]; then
            files+=("$file")
            printf "%2d) %s\n" "$i" "$file"
            ((i++))
        fi
    done
    
    if [[ ${#files[@]} -eq 0 ]]; then
        log_error "Файлы .c не найдены в папке $SRC_DIR"
        popd > /dev/null || return 1
        return 1
    fi
    
    echo "-----------------------------"
    read -rp "Выберите файлы (через пробел) или 'all' для всех: " selection
    
    if [[ "$selection" == "all" ]]; then
        SELECTED_FILES=("${files[@]}")
    else
        SELECTED_FILES=()
        for idx in $selection; do
            if [[ "$idx" =~ ^[0-9]+$ && "$idx" -lt ${#files[@]} ]]; then
                SELECTED_FILES+=("${files[$idx]}")
            fi
        done
    fi
    
    popd > /dev/null || return 1
    
    [[ ${#SELECTED_FILES[@]} -gt 0 ]] || return 1
}

# ========================
# ФУНКЦИИ ТЕСТИРОВАНИЯ
# ========================

check_code_style() {
    if ! select_files; then
        return 1
    fi

    show_section "Проверка стиля кода"
    
    if ! command -v clang-format &>/dev/null; then
        log_error "clang-format не установлен"
        return 1
    fi

    pushd "$SRC_DIR" > /dev/null || return 1
    
    for file in "${SELECTED_FILES[@]}"; do
        echo -e "Проверка ${BLUE}$file${NC}"
        clang-format --dry-run --Werror "$file"
        if [[ $? -eq 0 ]]; then
            log_success "Стиль кода соответствует"
        else
            log_error "Нарушения стиля кода"
        fi
    done
    
    popd > /dev/null || return 1
}

show_compile_menu() {
    if ! select_files; then
        return 1
    fi

    show_section "Меню компиляции"
    echo "1. Обычная компиляция (gcc)"
    echo "2. Строгая компиляция (gcc -Wall -Werror -Wextra --std=c11)"
    echo "3. Компиляция с санитайзерами"
    echo ""
    
    read -rp "Выберите режим компиляции: " mode
    compile_project "$mode"
}

compile_project() {
    local mode="$1"
    local flags=()
    local suffix=""

    case "$mode" in
        1) flags=(""); suffix="" ;;
        2) flags=("-Wall" "-Werror" "-Wextra" "--std=c11"); suffix="_strict" ;;
        3) flags=("-Wall" "-Werror" "-Wextra" "--std=c11" "-fsanitize=address" \
                 "-fsanitize=leak" "-fsanitize=undefined"); suffix="_sanitize" ;;
        *) log_error "Неверный режим компиляции"; return 1 ;;
    esac

    pushd "$SRC_DIR" > /dev/null || return 1
    
    for file in "${SELECTED_FILES[@]}"; do
        local output="${file%.c}${suffix}"
        echo -e "\nКомпиляция: ${BLUE}$file${NC} -> ${GREEN}$output${NC}"
        
        if gcc "${flags[@]}" "$file" -o "$output"; then
            log_success "Успешно скомпилировано"
        else
            log_error "Ошибка компиляции"
        fi
    done
    
    popd > /dev/null || return 1
}

run_tests() {
    if ! select_files; then
        return 1
    fi

    show_section "Запуск тестов"
    
    pushd "$SRC_DIR" > /dev/null || return 1
    
    for file in "${SELECTED_FILES[@]}"; do
        local base="${file%.c}"
        local executable="${base}_strict"
        
        if [[ ! -f "$executable" ]]; then
            log_error "Исполняемый файл $executable не найден"
            log_warning "Сначала выполните компиляцию в режиме 2"
            continue
        fi
        
        echo -e "Тестирование ${BLUE}$executable${NC}"
        if [[ -f "../$TEST_DATA_FILE" ]]; then
            echo "Используются тестовые данные из $TEST_DATA_FILE"
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                echo -e "\nВходные данные: ${YELLOW}$line${NC}"
                echo "$line" | "./$executable"
            done < "../$TEST_DATA_FILE"
        else
            log_warning "Файл тестовых данных не найден"
            read -rp "Введите тестовые данные: " test_data
            echo "$test_data" | "./$executable"
        fi
    done
    
    popd > /dev/null || return 1
}

check_memory_leaks() {
    if ! select_files; then
        return 1
    fi

    show_section "Проверка утечек памяти"
    
    pushd "$SRC_DIR" > /dev/null || return 1
    
    for file in "${SELECTED_FILES[@]}"; do
        local base="${file%.c}"
        local executable="${base}_strict"
        
        if [[ ! -f "$executable" ]]; then
            log_error "Исполняемый файл $executable не найден"
            continue
        fi
        
        echo -e "Проверка ${BLUE}$executable${NC} с valgrind"
        valgrind --leak-check=full "./$executable"
    done
    
    popd > /dev/null || return 1
}

run_static_analysis() {
    if ! select_files; then
        return 1
    fi

    show_section "Статический анализ cppcheck"
    
    pushd "$SRC_DIR" > /dev/null || return 1
    
    for file in "${SELECTED_FILES[@]}"; do
        echo -e "Анализ ${BLUE}$file${NC}"
        cppcheck --enable=all --suppress=missingIncludeSystem "$file"
    done
    
    popd > /dev/null || return 1
}

# ========================
# МЕНЮ НАСТРОЕК
# ========================

show_settings_menu() {
    while true; do
        show_section "Меню настроек"
        echo "1. Изменить папку исходников (текущая: $SRC_DIR)"
        echo "2. Изменить файл отчета (текущий: $REPORT_FILE)"
        echo "3. Изменить файл тестовых данных (текущий: $TEST_DATA_FILE)"
        echo "4. Сбросить настройки по умолчанию"
        echo "5. Вернуться в главное меню"
        echo ""
        
        read -rp "Выберите действие: " choice
        
        case "$choice" in
            1)
                read -rp "Введите новую папку исходников: " new_src
                SRC_DIR="$new_src"
                save_config
                log_success "Папка исходников обновлена"
                ;;
            2)
                read -rp "Введите новый файл отчета: " new_report
                REPORT_FILE="$new_report"
                save_config
                log_success "Файл отчета обновлен"
                ;;
            3)
                read -rp "Введите новый файл тестовых данных: " new_test_data
                TEST_DATA_FILE="$new_test_data"
                save_config
                log_success "Файл тестовых данных обновлен"
                ;;
            4)
                init_config
                log_success "Настройки сброшены к значениям по умолчанию"
                ;;
            5)
                return
                ;;
            *)
                log_error "Неверный выбор"
                ;;
        esac
        
        read -rp "Нажмите Enter для продолжения..."
    done
}

# ========================
# ГЛАВНОЕ МЕНЮ
# ========================

show_main_menu() {
    while true; do
        clear
        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}  C Project Tester v${VERSION}${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo -e "Рабочая директория: $(pwd)"
        echo -e "Папка исходников: ${YELLOW}$SRC_DIR${NC}"
        echo ""
        
        echo "1. Проверить стиль кода"
        echo "2. Компиляция проекта"
        echo "3. Запустить тесты"
        echo "4. Проверить утечки памяти"
        echo "5. Статический анализ"
        echo "6. Настройки"
        echo "7. Копировать .clang-format в src/"
        echo "8. Выход"
        echo ""

        read -rp "Выберите действие: " choice

        case "$choice" in
            1) check_code_style ;;
            2) show_compile_menu ;;
            3) run_tests ;;
            4) check_memory_leaks ;;
            5) run_static_analysis ;;
            6) show_settings_menu ;;
            7) copy_clang_format ;;
            8) exit 0 ;;
            *) log_error "Неверный выбор" ;;
        esac

        read -rp "Нажмите Enter для продолжения..."
    done
}

# ========================
# ТОЧКА ВХОДА
# ========================

main() {
    CURRENT_DIR=$(pwd)
    load_config
    
    if ! validate_src_dir; then
        log_error "Не найдена папка с исходниками: $SRC_DIR"
        log_warning "Создайте папку $SRC_DIR и поместите в неё .c файлы"
        exit 1
    fi

    check_dependencies
    show_main_menu
}

main "$@"