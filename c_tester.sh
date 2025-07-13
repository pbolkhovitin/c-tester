clear#!/usr/bin/env bash
# C Project Tester v0.1.1
# Автоматизированное тестирование C проектов
# Лицензия: MIT

# ========================
# КОНФИГУРАЦИЯ
# ========================
readonly DEFAULT_SRC_DIR="src/"
readonly DEFAULT_REPORT_FILE="test_report.txt"
readonly DEFAULT_TEST_DATA_FILE="test_data.txt"
readonly CONFIG_FILE=".c_tester.conf"
readonly VERSION="0.1.1"

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

# ========================
# ОСНОВНЫЕ ФУНКЦИИ
# ========================

init_config() {
    SRC_DIR="$DEFAULT_SRC_DIR"
    REPORT_FILE="$DEFAULT_REPORT_FILE"
    TEST_DATA_FILE="$DEFAULT_TEST_DATA_FILE"
    save_config
}

# Сохранение конфигурации
save_config() {
    {
        echo "SRC_DIR=\"$SRC_DIR\""
        echo "REPORT_FILE=\"$REPORT_FILE\""
        echo "TEST_DATA_FILE=\"$TEST_DATA_FILE\""
    } > "$CONFIG_FILE"
}

# Загрузка конфигурации
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        init_config
    fi
}

# Заголовок секции
section_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
    echo ""
}

# Успешное сообщение
success_msg() {
    echo -e "${GREEN}$1${NC}"
}

# Предупреждение
warning_msg() {
    echo -e "${YELLOW}$1${NC}"
}

# Ошибка
error_msg() {
    echo -e "${RED}$1${NC}"
}

# Прогресс бар
progress_bar() {
    local duration=$1
    local steps=50
    local step_delay=$(bc -l <<< "$duration/$steps")
    
    printf "["
    for ((i=0; i<steps; i++)); do
        printf "="
        sleep $step_delay
    done
    printf "] Done!\n"
}

# Проверка зависимостей
check_dependencies() {
    section_header "ПРОВЕРКА ЗАВИСИМОСТЕЙ"
    
    local missing=()
    local tools=("gcc" "clang-format" "valgrind" "cppcheck" "git" "dialog")
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
            error_msg "Не найден: $tool"
        else
            success_msg "Найден: $tool"
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        warning_msg "Отсутствуют некоторые зависимости: ${missing[*]}"
        read -p "Хотите установить их? (y/n): " install
        if [[ "$install" == "y" || "$install" == "Y" ]]; then
            sudo apt-get install -y "${missing[@]}"
            progress_bar 2
        fi
    else
        success_msg "Все зависимости удовлетворены"
    fi
}

# Проверка расположения
check_location() {
    section_header "ПРОВЕРКА РАСПОЛОЖЕНИЯ"
    
    if [[ "$(basename "$(pwd)")" != "$SRC_DIR" ]]; then
        warning_msg "Скрипт должен запускаться из папки $SRC_DIR"
        read -p "Перейти в $SRC_DIR? (y/n): " change_dir
        if [[ "$change_dir" == "y" || "$change_dir" == "Y" ]]; then
            cd "$SRC_DIR" || { error_msg "Ошибка: не удалось перейти в $SRC_DIR"; exit 1; }
            success_msg "Успешно перешли в $SRC_DIR"
        else
            read -p "Изменить путь к $SRC_DIR в настройках? (y/n): " change_config
            if [[ "$change_config" == "y" || "$change_config" == "Y" ]]; then
                read -p "Введите новый путь: " new_path
                SRC_DIR="$new_path"
                save_config
                success_msg "Путь обновлен: $SRC_DIR"
            fi
        fi
    else
        success_msg "Правильное расположение: $SRC_DIR"
    fi
}

# Выбор файлов
select_files() {
    section_header "ВЫБОР ФАЙЛОВ ДЛЯ ТЕСТИРОВАНИЯ"
    
    local files=()
    local i=0
    
    echo "Доступные .c файлы:"
    echo "-------------------"
    
    for file in *.c; do
        if [ -f "$file" ]; then
            files+=("$file")
            printf "${BLUE}%2d)${NC} %s\n" "$i" "$file"
            ((i++))
        fi
    done
    
    if [ ${#files[@]} -eq 0 ]; then
        error_msg "Файлы .c не найдены"
        return 1
    fi
    
    echo "-------------------"
    read -p "Выберите файлы (через пробел) или 'all' для всех: " selection
    
    if [[ "$selection" == "all" ]]; then
        SELECTED_FILES=("${files[@]}")
        success_msg "Выбраны все файлы: ${SELECTED_FILES[*]}"
    else
        SELECTED_FILES=()
        for idx in $selection; do
            if [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -lt "${#files[@]}" ]; then
                SELECTED_FILES+=("${files[$idx]}")
            fi
        done
        
        if [ ${#SELECTED_FILES[@]} -ne 0 ]; then
            success_msg "Выбраны файлы: ${SELECTED_FILES[*]}"
        else
            error_msg "Не выбрано ни одного файла"
            return 1
        fi
    fi
    
    return 0
}

# Проверка стиля кода
check_style() {
    section_header "ПРОВЕРКА СТИЛЯ КОДА"
    
    for file in "${SELECTED_FILES[@]}"; do
        echo -e "${BLUE}Проверка файла:${NC} $file"
        
        if ! command -v clang-format &> /dev/null; then
            error_msg "clang-format не установлен. Пропускаем проверку стиля."
            return 1
        fi
        
        temp_file=$(mktemp)
        clang-format "$file" > "$temp_file"
        
        if diff -u "$file" "$temp_file"; then
            success_msg "Стиль кода соответствует требованиям"
        else
            error_msg "Найдены отклонения от стиля кода"
            warning_msg "Используйте: clang-format -i $file для автоматического исправления"
        fi
        
        rm -f "$temp_file"
        echo ""
    done
}

# Компиляция
compile() {
    local mode="$1"
    local extra_flags=""
    local suffix=""
    
    case "$mode" in
        1)
            extra_flags=""
            suffix=""
            echo -e "${YELLOW}Обычная компиляция${NC}"
            ;;
        2)
            extra_flags="-Wall -Werror -Wextra --std=c11"
            suffix="_strict"
            echo -e "${YELLOW}Строгая компиляция${NC}"
            ;;
        3)
            extra_flags="-Wall -Werror -Wextra --std=c11 -fsanitize=address -fsanitize=leak -fsanitize=undefined -fsanitize=unreachable"
            suffix="_sanitize"
            echo -e "${YELLOW}Компиляция с санитайзерами${NC}"
            ;;
        *)
            error_msg "Неверный режим компиляции"
            return 1
            ;;
    esac
    
    for file in "${SELECTED_FILES[@]}"; do
        local output="${file%.c}${suffix}"
        echo -e "${BLUE}Компиляция:${NC} $file -> $output"
        
        gcc $extra_flags "$file" -o "$output"
        if [ $? -eq 0 ]; then
            success_msg "Успешно скомпилировано: $output"
        else
            error_msg "Ошибка при компиляции $file"
        fi
        echo ""
    done
}

# Визуализация тестирования
visual_test() {
    local executable="$1"
    local input_data="$2"
    
    section_header "ТЕСТИРОВАНИЕ $executable"
    echo -e "${YELLOW}Входные данные:${NC} $input_data"
    echo ""
    
    echo -e "${BLUE}Ожидаемый результат:${NC}"
    echo "------------------"
    echo "------------------"
    echo ""
    
    echo -e "${GREEN}Фактический результат:${NC}"
    echo "------------------"
    echo "$input_data" | ./"$executable"
    local exit_code=$?
    echo "------------------"
    echo ""
    
    if [ $exit_code -eq 0 ]; then
        success_msg "Тест пройден успешно!"
    else
        error_msg "Тест завершился с ошибкой (код: $exit_code)"
    fi
    
    return $exit_code
}

# Запуск тестов
run_visual_tests() {
    section_header "ЗАПУСК ТЕСТОВ С ВИЗУАЛИЗАЦИЕЙ"
    
    for file in "${SELECTED_FILES[@]}"; do
        local base="${file%.c}"
        local executable="${base}_strict"
        
        if [ ! -f "$executable" ]; then
            error_msg "Исполняемый файл $executable не найден"
            warning_msg "Сначала выполните компиляцию в режиме 2"
            continue
        fi
        
        if [ -f "$TEST_DATA_FILE" ]; then
            success_msg "Используется файл тестовых данных: $TEST_DATA_FILE"
            local test_num=1
            
            while IFS= read -r line || [[ -n "$line" ]]; do
                if [[ -z "$line" ]]; then
                    echo "" >> "$REPORT_FILE"
                    continue
                fi
                
                echo -e "\n${BLUE}Тест #$test_num${NC}"
                echo "Входные данные: $line" | tee -a "$REPORT_FILE"
                
                visual_test "$executable" "$line" | tee -a "$REPORT_FILE"
                
                echo "" >> "$REPORT_FILE"
                ((test_num++))
                
            done < "$TEST_DATA_FILE"
        else
            warning_msg "Файл тестовых данных не найден, ручной ввод"
            read -p "Введите тестовые данные (или оставьте пустым для пропуска): " test_data
            
            if [ -n "$test_data" ]; then
                echo "Входные данные: $test_data" | tee -a "$REPORT_FILE"
                visual_test "$executable" "$test_data" | tee -a "$REPORT_FILE"
                echo "" >> "$REPORT_FILE"
            fi
        fi
    done
}

# Проверка утечек
check_leaks() {
    section_header "ПРОВЕРКА УТЕЧЕК ПАМЯТИ"
    
    for file in "${SELECTED_FILES[@]}"; do
        local base="${file%.c}"
        local executable="${base}_strict"
        
        if [ -f "$executable" ]; then
            echo -e "${BLUE}Проверка:${NC} $executable"
            valgrind --leak-check=full ./"$executable"
            echo ""
        else
            error_msg "Исполняемый файл $executable не найден"
        fi
    done
}

# Проверка cppcheck
run_cppcheck() {
    section_header "ПРОВЕРКА CPPCHECK"
    
    for file in "${SELECTED_FILES[@]}"; do
        echo -e "${BLUE}Проверка:${NC} $file"
        cppcheck --enable=all --suppress=missingIncludeSystem "$file"
        echo ""
    done
}

# Циклическое тестирование
loop_testing() {
    section_header "ЦИКЛИЧЕСКОЕ ТЕСТИРОВАНИЕ"
    
    read -p "Введите путь к файлу с тестовыми данными: " data_file
    if [ -f "$data_file" ]; then
        TEST_DATA_FILE="$data_file"
        save_config
        run_visual_tests
    else
        error_msg "Файл не найден: $data_file"
    fi
}

# Git операции
git_operations() {
    section_header "GIT ОПЕРАЦИИ"
    
    read -p "Введите комментарий для коммита: " commit_msg
    if [ -z "$commit_msg" ]; then
        commit_msg="Automatic commit"
    fi
    
    git add *.c
    git commit -m "$commit_msg"
    git push --set-upstream origin develop
}

# Меню настроек
settings_menu() {
    while true; do
        clear
        section_header "НАСТРОЙКИ"
        
        echo -e "1. Текущая папка исходников: ${YELLOW}$SRC_DIR${NC}"
        echo -e "2. Файл отчета: ${YELLOW}$REPORT_FILE${NC}"
        echo -e "3. Файл тестовых данных: ${YELLOW}$TEST_DATA_FILE${NC}"
        echo -e "4. Сбросить все настройки к значениям по умолчанию"
        echo -e "5. Вернуться в главное меню"
        echo ""
        
        read -p "Выберите настройку для изменения: " setting_choice
        
        case "$setting_choice" in
            1)
                read -p "Введите новый путь к папке исходников: " new_path
                SRC_DIR="$new_path"
                save_config
                success_msg "Путь к исходникам обновлен: $SRC_DIR"
                ;;
            2)
                read -p "Введите новое имя файла отчета: " new_file
                REPORT_FILE="$new_file"
                save_config
                success_msg "Файл отчета обновлен: $REPORT_FILE"
                ;;
            3)
                read -p "Введите новое имя файла тестовых данных: " new_data_file
                TEST_DATA_FILE="$new_data_file"
                save_config
                success_msg "Файл тестовых данных обновлен: $TEST_DATA_FILE"
                ;;
            4)
                read -p "Вы уверены, что хотите сбросить все настройки? (y/n): " confirm
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    init_config
                    success_msg "Все настройки сброшены к значениям по умолчанию"
                fi
                ;;
            5)
                return
                ;;
            *)
                error_msg "Неверный выбор. Попробуйте снова."
                ;;
        esac
        
        read -p "Нажмите Enter для продолжения..."
    done
}

# Графическое меню
graphic_menu() {
    while true; do
        choice=$(dialog --clear --backtitle "C Tester Menu" \
            --title "Главное меню" \
            --menu "Выберите действие:" 15 50 8 \
            1 "Проверить стиль кода" \
            2 "Компиляция" \
            3 "Запустить тесты" \
            4 "Проверить утечки" \
            5 "Проверить код (cppcheck)" \
            6 "Циклическое тестирование" \
            7 "Git операции" \
            8 "Настройки" \
            9 "Выход" \
            2>&1 >/dev/tty)
        
        clear
        
        case "$choice" in
            1)
                if select_files; then
                    check_style
                    read -p "Нажмите Enter для продолжения..."
                fi
                ;;
            2)
                if select_files; then
                    compile_mode=$(dialog --menu "Выберите режим компиляции:" 15 50 8 \
                        1 "Обычная компиляция" \
                        2 "Строгая компиляция" \
                        3 "С санитайзерами" \
                        2>&1 >/dev/tty)
                    
                    compile "$compile_mode"
                    read -p "Нажмите Enter для продолжения..."
                fi
                ;;
            3)
                if select_files; then
                    run_visual_tests
                    read -p "Нажмите Enter для продолжения..."
                fi
                ;;
            4)
                if select_files; then
                    check_leaks
                    read -p "Нажмите Enter для продолжения..."
                fi
                ;;
            5)
                if select_files; then
                    run_cppcheck
                    read -p "Нажмите Enter для продолжения..."
                fi
                ;;
            6)
                if select_files; then
                    loop_testing
                    read -p "Нажмите Enter для продолжения..."
                fi
                ;;
            7)
                git_operations
                read -p "Нажмите Enter для продолжения..."
                ;;
            8)
                settings_menu
                ;;
            9)
                exit 0
                ;;
            *)
                error_msg "Неверный выбор"
                ;;
        esac
    done
}

# Текстовое меню
text_menu() {
    while true; do
        clear
        section_header "ГЛАВНОЕ МЕНЮ C TESTER"
        
        echo -e "${GREEN}1.${NC} Проверить стиль кода (clang-format)"
        echo -e "${GREEN}2.${NC} Компиляция (выберите режим)"
        echo -e "${GREEN}3.${NC} Запустить тесты с визуализацией"
        echo -e "${GREEN}4.${NC} Проверить утечки памяти (valgrind)"
        echo -e "${GREEN}5.${NC} Проверить код (cppcheck)"
        echo -e "${GREEN}6.${NC} Циклическое тестирование с файлом данных"
        echo -e "${GREEN}7.${NC} Git операции"
        echo -e "${GREEN}8.${NC} Настройки"
        echo -e "${GREEN}9.${NC} Выход"
        echo ""
        
        read -p "Выберите действие: " choice
        
        case "$choice" in
            1)
                if select_files; then
                    check_style
                    read -p "Нажмите Enter для продолжения..."
                fi
                ;;
            2)
                if select_files; then
                    echo -e "\n${BLUE}РЕЖИМЫ КОМПИЛЯЦИИ:${NC}"
                    echo -e "${GREEN}1.${NC} Обычная компиляция (gcc)"
                    echo -e "${GREEN}2.${NC} Строгая компиляция (gcc -Wall -Werror -Wextra --std=c11)"
                    echo -e "${GREEN}3.${NC} Компиляция с санитайзерами"
                    read -p "Выберите режим компиляции: " compile_mode
                    compile "$compile_mode"
                    read -p "Нажмите Enter для продолжения..."
                fi
                ;;
            3)
                if select_files; then
                    run_visual_tests
                    read -p "Нажмите Enter для продолжения..."
                fi
                ;;
            4)
                if select_files; then
                    check_leaks
                    read -p "Нажмите Enter для продолжения..."
                fi
                ;;
            5)
                if select_files; then
                    run_cppcheck
                    read -p "Нажмите Enter для продолжения..."
                fi
                ;;
            6)
                if select_files; then
                    loop_testing
                    read -p "Нажмите Enter для продолжения..."
                fi
                ;;
            7)
                git_operations
                read -p "Нажмите Enter для продолжения..."
                ;;
            8)
                settings_menu
                ;;
            9)
                exit 0
                ;;
            *)
                error_msg "Неверный выбор. Попробуйте снова."
                read -p "Нажмите Enter для продолжения..."
                ;;
        esac
    done
}

# Основная функция
main() {
    load_config
    check_dependencies
    check_location
    
    if [ "$1" == "--gui" ]; then
        if command -v dialog &> /dev/null; then
            graphic_menu
        else
            warning_msg "Для графического меню установите 'dialog'. Используется текстовое меню."
            text_menu
        fi
    else
        text_menu
    fi
}

# Запуск
main "$@"
