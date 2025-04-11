#!/bin/bash

source "$BASE_DIR/modules/utils.sh"

install_all() {
    mkdir -p "$BASE_DIR" 2>/dev/null
    log_message "Updating Fedora 41..."
    sudo dnf upgrade --refresh -y 2>> "$LOG_FILE"
    log_message "Installing Podman, Python, and other dependencies..."
    sudo dnf install -y podman python3-pip python3-devel curl git cmake gcc g++ tesseract poppler-utils 2>> "$LOG_FILE"
    log_message "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh -o /tmp/ollama_install.sh 2>> "$LOG_FILE"
    if [ $? -eq 0 ]; then
        chmod +x /tmp/ollama_install.sh
        sudo /tmp/ollama_install.sh 2>> "$LOG_FILE"
        rm -f /tmp/ollama_install.sh
        log_message "Starting Ollama immediately after installation..."
        if command -v ollama >/dev/null 2>&1; then
            if systemctl --user status ollama >/dev/null 2>&1; then
                systemctl --user start ollama || log_message "Failed to start Ollama as a service."
            else
                ollama serve &  # Start in background
                sleep 2
                log_message "Ollama started manually in the background."
            fi
        else
            log_message "Ollama installation failed; not found in PATH."
        fi
    else
        log_message "Failed to download Ollama installation script."
    fi

    # Limpar modelos antigos antes de instalar um novo
    log_message "Cleaning up existing Ollama models..."
    rm -rf ~/.ollama/models/* 2>> "$LOG_FILE"
    log_message "All previous models removed."

    # Model selection
    log_message "Select a model to install:"
    echo "Select a model to install:"
    echo "1. CodeLlama"
    echo "2. DeepSeek"
    echo "3. StarCoder2"
    echo "4. CodeQwen"
    read -p "Choice (1-4): " model_choice

    case $model_choice in
        1)
            log_message "Selected CodeLlama. Choose a variant:"
            echo "1. CodeLlama 7b (Basic)"
            echo "2. CodeLlama 13b (Intermediate)"
            echo "3. CodeLlama 70b (Advanced)"
            read -p "Variant (1-3): " variant_choice
            case $variant_choice in
                1) MODEL="codellama:7b-code"; HF_MODEL="codellama/CodeLlama-7b-hf";;
                2) MODEL="codellama:13b-code"; HF_MODEL="codellama/CodeLlama-13b-hf";;
                3) MODEL="codellama:70b-code"; HF_MODEL="codellama/CodeLlama-70b-hf";;
                *) log_message "Invalid variant. Defaulting to CodeLlama 7b."; MODEL="codellama:7b-code"; HF_MODEL="codellama/CodeLlama-7b-hf";;
            esac
            ;;
        2)
            log_message "Selected DeepSeek. Choose a variant:"
            echo "1. DeepSeek 1b (Basic)"
            echo "2. DeepSeek 7b (Intermediate)"
            echo "3. DeepSeek 33b (Advanced)"
            read -p "Variant (1-3): " variant_choice
            case $variant_choice in
                1) MODEL="deepseek-coder:1b"; HF_MODEL="deepseek-ai/deepseek-coder-1.3b-base";;
                2) MODEL="deepseek-coder:7b"; HF_MODEL="deepseek-ai/deepseek-coder-6.7b-base";;
                3) MODEL="deepseek-coder:33b"; HF_MODEL="deepseek-ai/deepseek-coder-33b-base";;
                *) log_message "Invalid variant. Defaulting to DeepSeek 1b."; MODEL="deepseek-coder:1b"; HF_MODEL="deepseek-ai/deepseek-coder-1.3b-base";;
            esac
            ;;
        3)
            log_message "Selected StarCoder2. Choose a variant:"
            echo "1. StarCoder2 3b (Basic)"
            echo "2. StarCoder2 7b (Intermediate)"
            echo "3. StarCoder2 15b (Advanced)"
            read -p "Variant (1-3): " variant_choice
            case $variant_choice in
                1) MODEL="starcoder2:3b"; HF_MODEL="bigcode/starcoder2-3b";;
                2) MODEL="starcoder2:7b"; HF_MODEL="bigcode/starcoder2-7b";;
                3) MODEL="starcoder2:15b"; HF_MODEL="bigcode/starcoder2-15b";;
                *) log_message "Invalid variant. Defaulting to StarCoder2 3b."; MODEL="starcoder2:3b"; HF_MODEL="bigcode/starcoder2-3b";;
            esac
            ;;
        4)
            log_message "Selected CodeQwen. Choose a variant:"
            echo "1. CodeQwen 1.5b (Basic)"
            echo "2. CodeQwen 7b (Intermediate)"
            echo "3. CodeQwen 14b (Advanced)"
            read -p "Variant (1-3): " variant_choice
            case $variant_choice in
                1) MODEL="codeqwen:1.5b"; HF_MODEL="Qwen/CodeQwen1.5-1.5B";;
                2) MODEL="codeqwen:7b"; HF_MODEL="Qwen/CodeQwen1.5-7B";;
                3) MODEL="codeqwen:14b"; HF_MODEL="Qwen/CodeQwen1.5-14B";;
                *) log_message "Invalid variant. Defaulting to CodeQwen 1.5b."; MODEL="codeqwen:1.5b"; HF_MODEL="Qwen/CodeQwen1.5-1.5B";;
            esac
            ;;
        *)
            log_message "Invalid model choice. Defaulting to CodeLlama 7b."
            MODEL="codellama:7b-code"
            HF_MODEL="codellama/CodeLlama-7b-hf"
            ;;
    esac

    log_message "Downloading selected model: $MODEL..."
    ollama pull "$MODEL" 2>> "$LOG_FILE"

    # Save selected model to config.sh
    echo "export SELECTED_MODEL=\"$MODEL\"" > "$BASE_DIR/config.sh"
    echo "export HF_MODEL=\"$HF_MODEL\"" >> "$BASE_DIR/config.sh"
    log_message "Model configuration saved to $BASE_DIR/config.sh"

    log_message "Installing Python dependencies..."
    /usr/bin/python3 -m pip install PyPDF2 sentence-transformers flask transformers datasets torch accelerate sentencepiece protobuf pdf2image pytesseract pillow --user --force-reinstall 2>> "$LOG_FILE"
    for pkg in PyPDF2 sentence_transformers flask transformers datasets torch accelerate sentencepiece protobuf pdf2image pytesseract pillow; do
        if ! /usr/bin/python3 -c "import $pkg" >/dev/null 2>&1; then
            log_message "Failed to install $pkg with --user. Trying with sudo..."
            sudo /usr/bin/python3 -m pip install $pkg --force-reinstall 2>> "$LOG_FILE"
        fi
    done
    if ! /usr/bin/python3 -c "import sys; print('\n'.join(sys.path))" | grep -q "/home/$USER/.local/lib/python3.13/site-packages"; then
        log_message "Adding ~/.local/lib/python3.13/site-packages to PYTHONPATH..."
        echo "export PYTHONPATH=\"\$PYTHONPATH:/home/$USER/.local/lib/python3.13/site-packages\"" >> ~/.bashrc
        source ~/.bashrc
    fi
    log_message "Setting up Open WebUI..."
    if podman ps -a | grep -q "open-webui"; then
        log_message "Existing open-webui container found. Removing it..."
        podman stop open-webui >/dev/null 2>> "$LOG_FILE"
        podman rm open-webui >/dev/null 2>> "$LOG_FILE"
    fi
    podman run -d -p 8080:8080 \
      --network=host \
      -v open-webui:/app/backend/data \
      -e "OLLAMA_API_BASE_URL=http://127.0.0.1:11434" \
      -e "OLLAMA_HOST=http://127.0.0.1:11434" \
      -e "DEFAULT_OLLAMA_HOST=http://127.0.0.1:11434" \
      --name open-webui \
      --replace \
      ghcr.io/open-webui/open-webui:main 2>> "$LOG_FILE"
    log_message "Creating project directories..."
    mkdir -p "$BASE_DIR/pdfs" "$BASE_DIR/fine_tune_data" 2>> "$LOG_FILE"
    cd "$BASE_DIR"
    log_message "Setting permissions for Python scripts..."
    chmod +x extract_pdf_text.py 2>> "$LOG_FILE"
    chmod +x fine_tune_model.py 2>> "$LOG_FILE"
    chmod +x web_interface.py 2>> "$LOG_FILE"
    chmod +x process_pdfs.py 2>> "$LOG_FILE"
    log_message "BigMilkAI installation complete with $MODEL in $BASE_DIR!"
}

uninstall_all() {
    source "$BASE_DIR/modules/services.sh"
    stop_services
    log_message "Removing BigMilkAI models from Ollama..."
    ollama rm codellama:7b-code codellama:13b-code codellama:70b-code deepseek-coder:1b deepseek-coder:7b deepseek-coder:33b starcoder2:3b starcoder2:7b starcoder2:15b codeqwen:1.5b codeqwen:7b codeqwen:14b bigmilkai-tuned >/dev/null 2>> "$LOG_FILE" || log_message "No models found to remove."

    # Complete Ollama removal
    log_message "Removing Ollama completely..."
    if systemctl --user status ollama >/dev/null 2>&1; then
        systemctl --user stop ollama >/dev/null 2>> "$LOG_FILE"
        systemctl --user disable ollama >/dev/null 2>> "$LOG_FILE"
        rm -f ~/.config/systemd/user/ollama.service 2>> "$LOG_FILE"
        systemctl --user daemon-reload
        log_message "Ollama service stopped and disabled."
    fi
    sudo rm -f /usr/local/bin/ollama >/dev/null 2>> "$LOG_FILE"
    rm -rf ~/.ollama >/dev/null 2>> "$LOG_FILE"
    sudo rm -rf /usr/share/ollama 2>> "$LOG_FILE"
    log_message "Ollama binaries and data removed."

    # Complete Open WebUI removal
    log_message "Removing Open WebUI completely..."
    podman stop open-webui >/dev/null 2>> "$LOG_FILE" || log_message "No Open WebUI container running."
    podman rm -f open-webui >/dev/null 2>> "$LOG_FILE" || log_message "No Open WebUI container to remove."
    podman volume rm open-webui >/dev/null 2>> "$LOG_FILE" || log_message "No Open WebUI volume to remove."
    podman rmi ghcr.io/open-webui/open-webui:main >/dev/null 2>> "$LOG_FILE" || log_message "No Open WebUI image to remove."
    log_message "Open WebUI container, volume, and image removed."

    log_message "Removing installed packages..."
    sudo dnf remove -y podman python3-pip python3-devel curl git cmake gcc g++ tesseract poppler-utils >/dev/null 2>> "$LOG_FILE"
    sudo dnf autoremove -y >/dev/null 2>> "$LOG_FILE"
    /usr/bin/python3 -m pip uninstall PyPDF2 sentence-transformers flask transformers datasets torch accelerate sentencepiece protobuf pdf2image pytesseract pillow -y >/dev/null 2>> "$LOG_FILE"
    log_message "Removing project directory..."
    rm -rf "$BASE_DIR" >/dev/null 2>> "$LOG_FILE"
    log_message "BigMilkAI uninstallation complete!"
}
