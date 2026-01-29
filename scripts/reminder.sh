#!/bin/bash

# Скрипт для управления напоминаниями дневника

PLIST_FILE="$HOME/Library/LaunchAgents/com.workdiary.reminder.plist"

# Цвета
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Функция показа текущего времени напоминания
show_reminder() {
    if [ ! -f "$PLIST_FILE" ]; then
        echo -e "${YELLOW}Напоминание не настроено${NC}"
        return 1
    fi
    
    # Извлекаем время из первого элемента массива (все дни имеют одинаковое время)
    local hour=$(plutil -extract StartCalendarInterval.0.Hour raw "$PLIST_FILE" 2>/dev/null)
    local minute=$(plutil -extract StartCalendarInterval.0.Minute raw "$PLIST_FILE" 2>/dev/null)
    
    if [ -z "$hour" ] || [ -z "$minute" ]; then
        echo -e "${RED}Ошибка чтения настроек напоминания${NC}"
        return 1
    fi
    
    # Форматируем минуты с ведущим нулем
    minute=$(printf "%02d" "$minute")
    
    echo -e "${BLUE}Текущее время напоминания:${NC}"
    echo -e "${GREEN}$hour:$minute${NC} (только рабочие дни, пн-пт)"
    
    # Проверяем статус
    if launchctl list | grep -q "com.workdiary.reminder"; then
        echo -e "${GREEN}Статус: активно${NC}"
    else
        echo -e "${YELLOW}Статус: не активно${NC}"
        echo -e "${YELLOW}Для активации выполните: launchctl load $PLIST_FILE${NC}"
    fi
}

# Функция удаления напоминания
remove_reminder() {
    if [ ! -f "$PLIST_FILE" ]; then
        echo -e "${YELLOW}Напоминание не настроено${NC}"
        return 1
    fi
    
    # Деактивируем если активно
    if launchctl list | grep -q "com.workdiary.reminder"; then
        echo -e "${BLUE}Деактивирую напоминание...${NC}"
        launchctl unload "$PLIST_FILE" 2>/dev/null
    fi
    
    # Удаляем файл
    rm "$PLIST_FILE"
    echo -e "${GREEN}✅ Напоминание удалено${NC}"
}

# Функция настройки нового напоминания
setup_reminder() {
    # Если уже есть напоминание, показываем его
    if [ -f "$PLIST_FILE" ]; then
        echo -e "${YELLOW}Обнаружено существующее напоминание:${NC}"
        show_reminder
        echo ""
        read -p "Заменить на новое? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Отменено${NC}"
            return
        fi
        remove_reminder
        echo ""
    fi
    
    # Запрашиваем время напоминания
    echo -e "${BLUE}Настройка напоминаний для дневника${NC}"
    echo ""
    read -p "В какое время напоминать? (часы, 0-23) [18]: " hour
    hour=${hour:-18}
    
    read -p "Минуты? (0-59) [0]: " minute
    minute=${minute:-0}
    
    # Путь к скрипту напоминания (определяем автоматически)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REMINDER_SCRIPT="$SCRIPT_DIR/work-diary-reminder.sh"
    
    # Создаем директорию если её нет
    mkdir -p "$HOME/Library/LaunchAgents"
    
    # Создаем plist файл с напоминаниями для каждого рабочего дня
    cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.workdiary.reminder</string>
    <key>ProgramArguments</key>
    <array>
        <string>$REMINDER_SCRIPT</string>
    </array>
    <key>StartCalendarInterval</key>
    <array>
        <dict>
            <key>Weekday</key>
            <integer>1</integer>
            <key>Hour</key>
            <integer>$hour</integer>
            <key>Minute</key>
            <integer>$minute</integer>
        </dict>
        <dict>
            <key>Weekday</key>
            <integer>2</integer>
            <key>Hour</key>
            <integer>$hour</integer>
            <key>Minute</key>
            <integer>$minute</integer>
        </dict>
        <dict>
            <key>Weekday</key>
            <integer>3</integer>
            <key>Hour</key>
            <integer>$hour</integer>
            <key>Minute</key>
            <integer>$minute</integer>
        </dict>
        <dict>
            <key>Weekday</key>
            <integer>4</integer>
            <key>Hour</key>
            <integer>$hour</integer>
            <key>Minute</key>
            <integer>$minute</integer>
        </dict>
        <dict>
            <key>Weekday</key>
            <integer>5</integer>
            <key>Hour</key>
            <integer>$hour</integer>
            <key>Minute</key>
            <integer>$minute</integer>
        </dict>
    </array>
    <key>RunAtLoad</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/tmp/workdiary-reminder.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/workdiary-reminder-error.log</string>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
EOF
    
    chmod +x "$REMINDER_SCRIPT"
    
    echo ""
    echo -e "${GREEN}✅ Создан файл напоминания: $PLIST_FILE${NC}"
    echo -e "   Время: ${GREEN}$hour:$(printf "%02d" $minute)${NC} (только рабочие дни, пн-пт)"
    echo ""
    echo -e "${BLUE}Для активации выполните:${NC}"
    echo -e "  ${GREEN}launchctl load $PLIST_FILE${NC}"
}

# Главная логика
case "${1:-show}" in
    show|status)
        show_reminder
        ;;
    remove|delete|rm)
        remove_reminder
        ;;
    setup|new)
        setup_reminder
        ;;
    help|--help|-h)
        echo -e "${BLUE}Управление напоминаниями дневника${NC}"
        echo ""
        echo "Использование:"
        echo "  $0 [команда]"
        echo ""
        echo "Команды:"
        echo -e "  ${GREEN}show${NC}     - Показать текущее время напоминания (по умолчанию)"
        echo -e "  ${GREEN}status${NC}   - Показать текущее время напоминания"
        echo -e "  ${GREEN}remove${NC}   - Удалить напоминание"
        echo -e "  ${GREEN}setup${NC}    - Настроить новое напоминание"
        echo -e "  ${GREEN}new${NC}      - Настроить новое напоминание"
        echo -e "  ${GREEN}help${NC}     - Показать эту справку"
        echo ""
        echo "Примеры:"
        echo "  $0              # Показать текущее время"
        echo "  $0 remove      # Удалить напоминание"
        echo "  $0 setup       # Настроить новое напоминание"
        ;;
    *)
        echo -e "${RED}Неизвестная команда: $1${NC}"
        echo "Используйте '$0 help' для справки"
        exit 1
        ;;
esac
