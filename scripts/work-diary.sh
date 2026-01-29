#!/bin/bash

# Work Diary Manager для macOS
# Скрипт для ведения дневника о работе
# Структура: спринты как папки, каждый день как отдельный файл

# Определяем путь к проекту автоматически на основе расположения скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DIARY_DIR="$PROJECT_ROOT/entries"
TEMPLATE_DIR="$PROJECT_ROOT/templates"
DIARY_EDITOR="${DIARY_EDITOR:-nano}"

# Цвета для вывода
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для открытия файла в редакторе
open_in_editor() {
    local file="$1"
    
    # Для VS Code открываем в текущем окне и в контексте проекта
    if [[ "$DIARY_EDITOR" == "code" ]] || [[ "$DIARY_EDITOR" == *"code"* ]]; then
        # Открываем корень проекта и файл вместе с флагом -r (reuse window)
        # Это гарантирует, что файл откроется в контексте проекта в текущем окне
        # Если проект уже открыт, просто добавит файл в текущее окно
        code -r "$PROJECT_ROOT" "$file"
    else
        # Для других редакторов используем как есть
        $DIARY_EDITOR "$file"
    fi
}

# Создаем директории если их нет
mkdir -p "$DIARY_DIR"
mkdir -p "$TEMPLATE_DIR"

# Функция для получения текущего спринта
get_current_sprint() {
    local day=$(date +%d | sed 's/^0//')  # Убираем ведущий ноль
    local month=$(date +%m)
    local year=$(date +%y)
    
    # Определяем начало спринта (каждые 2 недели)
    # Упрощенная логика: спринты начинаются 1 и 15 числа
    if [ "$day" -le 15 ]; then
        local sprint_start="01.$month.$year"
        local sprint_end="15.$month.$year"
    else
        local sprint_start="15.$month.$year"
        # Получаем последний день месяца для macOS
        local last_day=$(date -v1d -v+1m -v-1d +%d 2>/dev/null || echo "28")
        # Убираем ведущий ноль если есть
        last_day=$(echo "$last_day" | sed 's/^0//')
        local sprint_end="$last_day.$month.$year"
    fi
    
    echo "$sprint_start-$sprint_end"
}

# Функция для получения пути к папке спринта
get_sprint_dir() {
    local sprint=$(get_current_sprint)
    # Формат: sprint_01.01.26-15.01.26 (читаемо и понятно)
    echo "$DIARY_DIR/sprint_${sprint}"
}

# Функция для получения пути к файлу текущего дня
get_today_file() {
    local sprint_dir=$(get_sprint_dir)
    local today=$(date +%d.%m.%Y)
    echo "$sprint_dir/$today.md"
}

# Функция проверки рабочего дня (пн-пт)
is_workday() {
    local day_of_week=$(date +%u)  # 1=понедельник, 7=воскресенье
    [ "$day_of_week" -ge 1 ] && [ "$day_of_week" -le 5 ]
}

# Функция создания новой записи на сегодня
create_entry() {
    local sprint_dir=$(get_sprint_dir)
    local filename=$(get_today_file)
    local today=$(date "+%d.%m.%Y")
    local day_name=$(date "+%A")
    
    # Создаем папку спринта если её нет
    mkdir -p "$sprint_dir"
    
    if [ -f "$filename" ]; then
        echo -e "${YELLOW}Запись на сегодня уже существует.${NC}"
        echo -e "${BLUE}Открываю существующую запись...${NC}"
        open_entry
        return
    fi
    
    # Создаем новую запись из шаблона
    cat > "$filename" << EOF
# Дневник сумасшедшего
$today, $day_name

## Спринт $(get_current_sprint)

### Тикеты, которые решал сегодня
- 

### Что было интересного?
- 

### Что можно рассказать коллегам?
- 

### Заметки
- 

---
EOF
    
    echo -e "${GREEN}Создана новая запись на $today${NC}"
    echo -e "${BLUE}Файл: $filename${NC}"
    if [ -t 0 ]; then
        echo -e "${BLUE}Открываю в редакторе...${NC}"
        open_in_editor "$filename"
    else
        echo -e "${YELLOW}Запустите '$0 open' для редактирования${NC}"
    fi
}

# Функция открытия текущей записи
open_entry() {
    local filename=$(get_today_file)
    
    # Проверяем рабочий ли это день
    if ! is_workday; then
        local day_name=$(date "+%A")
        echo -e "${YELLOW}Сегодня $day_name - выходной день.${NC}"
        read -p "Всё равно создать запись? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    if [ ! -f "$filename" ]; then
        echo -e "${YELLOW}Запись на сегодня не найдена.${NC}"
        read -p "Создать новую запись? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            create_entry
        fi
        return
    fi
    
    echo -e "${GREEN}Открываю дневник на сегодня...${NC}"
    if [ -t 0 ]; then
        open_in_editor "$filename"
    else
        echo -e "${YELLOW}Файл: $filename${NC}"
        echo -e "${YELLOW}Запустите '$0 open' для редактирования${NC}"
    fi
}

# Функция просмотра всех записей
list_entries() {
    echo -e "${BLUE}Доступные записи:${NC}"
    echo ""
    
    if [ ! -d "$DIARY_DIR" ] || [ -z "$(find "$DIARY_DIR" -name "*.md" -type f 2>/dev/null)" ]; then
        echo -e "${YELLOW}Записей пока нет.${NC}"
        return
    fi
    
    # Группируем по спринтам
    find "$DIARY_DIR" -type d -name "sprint_*" | sort -r | while read -r sprint_dir; do
        local sprint_name=$(basename "$sprint_dir" | sed 's/sprint_//')
        echo -e "${BLUE}📁 Спринт: $sprint_name${NC}"
        
        find "$sprint_dir" -name "*.md" -type f | sort -r | head -10 | while read -r file; do
            local date_str=$(basename "$file" .md)
            local day_name=$(date -j -f "%d.%m.%Y" "$date_str" "+%A" 2>/dev/null || echo "")
            echo -e "  ${GREEN}📝 $date_str${NC}${YELLOW} ($day_name)${NC}"
        done
        echo ""
    done
}

# Функция поиска по записям
search_entries() {
    if [ -z "$1" ]; then
        echo -e "${YELLOW}Укажите поисковый запрос${NC}"
        echo "Использование: $0 search <запрос>"
        return
    fi
    
    echo -e "${BLUE}Поиск: $1${NC}"
    echo ""
    grep -r -i "$1" "$DIARY_DIR" --include="*.md" -n | head -20 | while IFS= read -r line; do
        echo -e "${GREEN}$line${NC}"
    done
}

# Функция показа статистики
show_stats() {
    local total_entries=$(find "$DIARY_DIR" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    local total_sprints=$(find "$DIARY_DIR" -type d -name "sprint_*" 2>/dev/null | wc -l | tr -d ' ')
    local total_size=$(du -sh "$DIARY_DIR" 2>/dev/null | cut -f1)
    
    echo -e "${BLUE}Статистика дневника:${NC}"
    echo -e "Всего записей: ${GREEN}$total_entries${NC}"
    echo -e "Всего спринтов: ${GREEN}$total_sprints${NC}"
    echo -e "Размер: ${GREEN}$total_size${NC}"
    echo ""
    
    if [ "$total_entries" -gt 0 ]; then
        echo -e "${BLUE}Последние записи:${NC}"
        find "$DIARY_DIR" -name "*.md" -type f | sort -r | head -5 | while read -r file; do
            local sprint_dir=$(dirname "$file")
            local sprint_name=$(basename "$sprint_dir" | sed 's/sprint_//')
            local date_str=$(basename "$file" .md)
            echo -e "  ${GREEN}📝 $date_str${NC} (спринт: ${BLUE}$sprint_name${NC})"
        done
    fi
}

# Функция показа помощи
show_help() {
    echo -e "${BLUE}Work Diary Manager${NC}"
    echo ""
    echo "Использование:"
    echo "  $0 [команда]"
    echo ""
    echo "Команды:"
    echo -e "  ${GREEN}new${NC}       - Создать новую запись на сегодня"
    echo -e "  ${GREEN}open${NC}      - Открыть запись на сегодня (по умолчанию)"
    echo -e "  ${GREEN}list${NC}      - Показать все записи (сгруппированные по спринтам)"
    echo -e "  ${GREEN}search <текст>${NC} - Поиск по записям"
    echo -e "  ${GREEN}stats${NC}     - Показать статистику"
    echo -e "  ${GREEN}help${NC}      - Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  $0              # Открыть запись на сегодня"
    echo "  $0 new          # Создать новую запись на сегодня"
    echo "  $0 search тикет # Найти все упоминания 'тикет'"
    echo ""
    echo "Структура:"
    echo "  entries/sprint_XX.XX.XX-XX.XX.XX/DD.MM.YYYY.md"
}

# Главная логика
case "${1:-open}" in
    new)
        create_entry
        ;;
    open)
        open_entry
        ;;
    list)
        list_entries
        ;;
    search)
        search_entries "$2"
        ;;
    stats)
        show_stats
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${YELLOW}Неизвестная команда: $1${NC}"
        show_help
        ;;
esac
