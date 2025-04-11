#!/bin/bash

source "$BASE_DIR/modules/utils.sh"
source "$BASE_DIR/config.sh"  # Load model configuration

fine_tune_model() {
    if [ ! -d "$BASE_DIR" ]; then
        log_message "BigMilkAI environment not installed. Please select option 10 to install first."
        return
    fi
    cd "$BASE_DIR"
    log_message "Extracting text from PDFs..."
    ./extract_pdf_text.py 2>> "$LOG_FILE"
    log_message "Fine-tuning the model with extracted text..."
    HF_MODEL="$HF_MODEL" ./fine_tune_model.py 2>> "$LOG_FILE"
    log_message "Fine-tuning process complete. Converting and importing to Ollama..."
    convert_and_import_model
}

convert_and_import_model() {
    if [ ! -d "$BASE_DIR/fine_tuned_llama" ]; then
        log_message "Fine-tuned model not found. Please run option 8 first."
        return
    fi
    cd "$BASE_DIR"
    log_message "Installing llama.cpp for model conversion..."
    if [ ! -d "llama.cpp" ]; then
        git clone https://github.com/ggerganov/llama.cpp 2>> "$LOG_FILE"
        cd llama.cpp
        sudo dnf install -y cmake gcc g++ 2>> "$LOG_FILE"
        mkdir -p build
        cd build
        cmake .. 2>> "$LOG_FILE"
        make -j$(nproc) 2>> "$LOG_FILE"
        cd ../..
    fi
    if [ ! -f "llama.cpp/convert_hf_to_gguf.py" ]; then
        log_message "Conversion script convert_hf_to_gguf.py not found in llama.cpp directory."
        return
    fi
    log_message "Converting fine-tuned model to GGUF format..."
    python3 "$BASE_DIR/llama.cpp/convert_hf_to_gguf.py" ./fine_tuned_llama --outfile fine_tuned_llama.gguf --outtype f16 2>> "$LOG_FILE"
    if [ $? -ne 0 ]; then
        log_message "Failed to convert model to GGUF. Check the log for details."
        return
    fi
    log_message "Creating a basic Modelfile for Ollama..."
    echo 'FROM ./fine_tuned_llama.gguf' > Modelfile
    echo 'PARAMETER temperature 0.7' >> Modelfile
    echo 'PARAMETER top_p 0.9' >> Modelfile
    echo 'SYSTEM "You are a helpful coding assistant trained on custom PDFs."' >> Modelfile
    log_message "Importing model to Ollama..."
    ollama create bigmilkai-tuned -f Modelfile 2>> "$LOG_FILE"
    if [ $? -ne 0 ]; then
        log_message "Failed to import model to Ollama. Check the log for details."
        return
    fi
    log_message "Restarting Open WebUI to sync new model..."
    podman restart open-webui 2>> "$LOG_FILE"
    log_message "Model converted and imported successfully. Check Ollama with 'ollama list'."
}

import_pdfs() {
    if [ ! -d "$BASE_DIR" ]; then
        log_message "BigMilkAI environment not installed. Please select option 10 to install first."
        return
    fi
    log_message "Enter the path to the directory containing PDFs to import:"
    echo "Enter the path to the directory containing PDFs to import:"
    read -p "Path: " pdf_path
    if [ -d "$pdf_path" ]; then
        cp "$pdf_path"/*.pdf "$BASE_DIR/pdfs/" 2>> "$LOG_FILE" || log_message "No PDFs found in $pdf_path"
        cd "$BASE_DIR"
        ./extract_pdf_text.py 2>> "$LOG_FILE"
        log_message "PDFs imported and text extracted!"
    else
        log_message "Invalid directory: $pdf_path"
    fi
}
