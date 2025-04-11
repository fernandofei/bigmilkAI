#!/bin/bash

# Define BASE_DIR based on where the script is located or an environment variable
BASE_DIR="${BIGMILKAI_DIR:-$(dirname "$(realpath "$0")")}"

# Source all modules with debugging
echo "Loading modules from $BASE_DIR/modules/"
for module in "$BASE_DIR/modules/"*.sh; do
    if [ -f "$module" ]; then
        echo "Sourcing $module..."
        source "$module"
        if [ $? -eq 0 ]; then
            echo "Successfully loaded $module"
        else
            echo "Error loading $module"
            exit 1
        fi
    else
        echo "No modules found in $BASE_DIR/modules/"
        exit 1
    fi
done

# Check if install_all is available
if ! command -v install_all >/dev/null 2>&1; then
    echo "Error: install_all function not found. Check if $BASE_DIR/modules/install.sh exists and is valid."
    exit 1
fi

# CLI Menu
show_menu() {
    clear
    echo "=== BigMilkAI Management Menu ==="
    echo "Welcome! Select an option below to manage BigMilkAI."
    echo "1. Start services"
    echo "2. Stop services"
    echo "3. Restart services"
    echo "4. Check status"
    echo "5. View logs"
    echo "6. Enable/Disable on boot"
    echo "7. Import PDF base (CLI)"
    echo "8. Fine-Tune Model with PDFs"
    echo "9. Convert and Import Fine-Tuned Model to Ollama"
    echo "10. Install BigMilkAI"
    echo "11. Uninstall BigMilkAI"
    echo "12. Start Web Interface"
    echo "13. Show Network Details"
    echo "0. Exit"
    read -p "Choose an option: " choice
    case $choice in
        1) start_services ;;
        2) stop_services ;;
        3) restart_services ;;
        4) check_status ;;
        5) view_logs ;;
        6) toggle_boot ;;
        7) import_pdfs ;;
        8) fine_tune_model ;;
        9) convert_and_import_model ;;
        10) install_all ;;
        11) uninstall_all ;;
        12) start_web_interface ;;
        13) show_network_details ;;
        0) log_message "Exiting..."; exit 0 ;;
        *) log_message "Invalid option, try again." ;;
    esac
    echo "Press Enter to continue..."
    read
}

# Main execution
while true; do
    show_menu
done
