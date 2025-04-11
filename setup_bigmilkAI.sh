#!/bin/bash

# Function to validate directory permissions and get user input
get_install_dir() {
    while true; do
        echo "Please specify the installation directory for BigMilkAI (default: ~/bigmilkai):"
        read -p "Directory: " input_dir
        # Use default if input is empty
        [ -z "$input_dir" ] && input_dir="$HOME/bigmilkai"
        # Expand tilde to full path
        BASE_DIR=$(realpath -m "$input_dir")
        
        # Check if directory exists and is writable, or if parent is writable to create it
        if [ -d "$BASE_DIR" ]; then
            if [ -w "$BASE_DIR" ]; then
                echo "Directory $BASE_DIR is writable. Proceeding with installation..."
                break
            else
                echo "Error: You do not have write permission for $BASE_DIR."
            fi
        else
            PARENT_DIR=$(dirname "$BASE_DIR")
            if [ -w "$PARENT_DIR" ]; then
                echo "Directory $BASE_DIR does not exist but can be created. Proceeding..."
                break
            else
                echo "Error: You do not have permission to create $BASE_DIR in $PARENT_DIR."
            fi
        fi
        echo "Please provide a different directory."
    done
}

# Get the installation directory from the user
get_install_dir

# Temporary log_message function for setup (will be overridden by utils.sh later)
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$BASE_DIR/big_milk_ai.log"
}

echo "Setting up BigMilkAI modular structure in $BASE_DIR..."

# Create base directory and modules subdirectory
mkdir -p "$BASE_DIR/modules" || { echo "Failed to create $BASE_DIR"; exit 1; }

# Create utils.sh
cat << 'EOF' > "$BASE_DIR/modules/utils.sh"
#!/bin/bash

# Log file
LOG_FILE="$BASE_DIR/big_milk_ai.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}
EOF

# Create install.sh with improved uninstall_all and model config
cat << 'EOF' > "$BASE_DIR/modules/install.sh"
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
EOF

# Create Python scripts
cat << 'EOF' > "$BASE_DIR/extract_pdf_text.py"
#!/usr/bin/python3
import os
import json
from PyPDF2 import PdfReader
from pdf2image import convert_from_path
import pytesseract
from PIL import Image

pdf_folder = "./pdfs"
output_file = "./fine_tune_data/pdf_texts.jsonl"
os.makedirs("./fine_tune_data", exist_ok=True)

print("Starting PDF text extraction...")
with open(output_file, "w") as f:
    for pdf_file in os.listdir(pdf_folder):
        if pdf_file.endswith(".pdf"):
            pdf_path = os.path.join(pdf_folder, pdf_file)
            print(f"Processing {pdf_file}...")
            text = ""
            try:
                reader = PdfReader(pdf_path)
                for page in reader.pages:
                    extracted = page.extract_text()
                    if extracted:
                        text += extracted + "\n"
                if not text.strip() or len(text.strip()) < 50:
                    print(f"Native extraction insufficient for {pdf_file}. Attempting OCR...")
                    images = convert_from_path(pdf_path)
                    ocr_text = ""
                    for i, img in enumerate(images):
                        ocr_result = pytesseract.image_to_string(img)
                        if ocr_result.strip():
                            ocr_text += ocr_result + "\n"
                        else:
                            print(f"OCR found no text on page {i+1} of {pdf_file}")
                    text = ocr_text if ocr_text.strip() else text
                if text.strip():
                    entry = {"text": text, "source": pdf_file}
                    f.write(json.dumps(entry) + "\n")
                    print(f"Successfully extracted text from {pdf_file} ({len(text)} chars)")
                else:
                    print(f"No usable text extracted from {pdf_file}")
            except Exception as e:
                print(f"Error processing {pdf_file}: {e}")
print(f"Text extraction complete. Output saved to {output_file}")
EOF

cat << 'EOF' > "$BASE_DIR/fine_tune_model.py"
#!/usr/bin/python3
import os
import sys
from transformers import AutoModelForCausalLM, AutoTokenizer, Trainer, TrainingArguments
from datasets import load_dataset
import torch

# Force CPU if GPU issues
torch.cuda.is_available = lambda: False

# Load the selected model from config.sh via environment variable
HF_MODEL = os.environ.get("HF_MODEL")
if not HF_MODEL:
    print("Error: HF_MODEL environment variable not set. Please run the installation first.")
    sys.exit(1)

print(f"Loading model: {HF_MODEL}")
try:
    model = AutoModelForCausalLM.from_pretrained(HF_MODEL)
    tokenizer = AutoTokenizer.from_pretrained(HF_MODEL)
except Exception as e:
    print(f"Error loading model {HF_MODEL}: {e}")
    sys.exit(1)

# Set padding token if not already set
if tokenizer.pad_token is None:
    tokenizer.pad_token = tokenizer.eos_token
    model.config.pad_token_id = model.config.eos_token_id

data_file = "./fine_tune_data/pdf_texts.jsonl"
if not os.path.exists(data_file) or os.path.getsize(data_file) == 0:
    print(f"Error: {data_file} is missing or empty. Run extract_pdf_text.py first.")
    sys.exit(1)

dataset = load_dataset("json", data_files=data_file, split="train")

def tokenize_function(examples):
    tokenized = tokenizer(examples["text"], padding="max_length", truncation=True, max_length=512)
    tokenized["labels"] = tokenized["input_ids"].copy()
    return tokenized

tokenized_dataset = dataset.map(tokenize_function, batched=True)
tokenized_dataset = tokenized_dataset.remove_columns(["text"])

training_args = TrainingArguments(
    output_dir="./fine_tune_output",
    num_train_epochs=1,
    per_device_train_batch_size=1,
    save_steps=500,
    save_total_limit=2,
    logging_dir="./fine_tune_logs",
    logging_steps=100,
)

trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=tokenized_dataset,
)

print("Starting fine-tuning...")
trainer.train()

output_dir = "./fine_tuned_llama"
os.makedirs(output_dir, exist_ok=True)

print("Saving fine-tuned model...")
model.save_pretrained(output_dir)
tokenizer.save_pretrained(output_dir)
print(f"Model saved to {output_dir}")

if os.path.exists(os.path.join(output_dir, "model.safetensors")):
    print("Model verified successfully!")
else:
    print(f"Error: Model not saved correctly to {output_dir}")
    sys.exit(1)
EOF

cat << 'EOF' > "$BASE_DIR/web_interface.py"
#!/usr/bin/python3
from flask import Flask, request, send_file, render_template_string
import os
import subprocess
import pickle
import numpy as np
from sentence_transformers import SentenceTransformer
import ollama

app = Flask(__name__)
BASE_DIR = os.path.expanduser(os.environ.get("BIGMILKAI_DIR", "~/bigmilkai"))
PDF_DIR = os.path.join(BASE_DIR, "pdfs")
EMBEDDINGS_FILE = os.path.join(BASE_DIR, "embeddings.pkl")
model = SentenceTransformer('all-MiniLM-L6-v2')

@app.route('/')
def index():
    return render_template_string('''
        <!DOCTYPE html>
        <html>
        <head>
            <title>BigMilkAI Manager</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 20px; }
                h1 { color: #333; }
                .button { padding: 10px 20px; margin: 5px; background-color: #4CAF50; color: white; border: none; cursor: pointer; }
                .button:hover { background-color: #45a049; }
            </style>
        </head>
        <body>
            <h1>BigMilkAI Manager</h1>
            <h2>Upload PDFs to Train Model</h2>
            <form action="/upload" method="post" enctype="multipart/form-data">
                <input type="file" name="pdfs" multiple accept=".pdf">
                <input type="submit" value="Upload and Train" class="button">
            </form>
            <h2>Ask a Question</h2>
            <form action="/query" method="post">
                <input type="text" name="question" placeholder="Enter your question" style="width: 300px;">
                <input type="submit" value="Ask" class="button">
            </form>
            <h2>Model Management</h2>
            <form action="/import" method="post" enctype="multipart/form-data">
                <input type="file" name="embeddings" accept=".pkl">
                <input type="submit" value="Import Pre-trained Model" class="button">
            </form>
            <form action="/export" method="get">
                <input type="submit" value="Export Trained Model" class="button">
            </form>
        </body>
        </html>
    ''')

@app.route('/upload', methods=['POST'])
def upload_pdfs():
    if 'pdfs' not in request.files:
        return "No files uploaded", 400
    pdfs = request.files.getlist('pdfs')
    for pdf in pdfs:
        if pdf.filename.endswith('.pdf'):
            pdf.save(os.path.join(PDF_DIR, pdf.filename))
    subprocess.run(["./process_pdfs.py"], cwd=BASE_DIR)
    return "PDFs uploaded and processed successfully!"

@app.route('/query', methods=['POST'])
def query():
    if not os.path.exists(EMBEDDINGS_FILE):
        return "No trained model found. Please upload PDFs first.", 404
    with open(EMBEDDINGS_FILE, "rb") as f:
        embeddings = pickle.load(f)
    question = request.form['question']
    query_embedding = model.encode(question)
    similarities = [np.dot(query_embedding, emb) for _, emb in embeddings]
    best_match_idx = np.argmax(similarities)
    context = embeddings[best_match_idx][0]
    response = ollama.chat(
        model="bigmilkai-tuned" if "bigmilkai-tuned" in [m["name"] for m in ollama.list()["models"]] else os.environ.get("SELECTED_MODEL", "codellama:7b-code"),
        messages=[
            {"role": "system", "content": "Você é um assistente útil que responde com base no conteúdo dos PDFs fornecidos."},
            {"role": "user", "content": f"Com base neste contexto: '{context[:1000]}...', responda: {question}"}
        ]
    )
    return response["message"]["content"]

@app.route('/import', methods=['POST'])
def import_model():
    if 'embeddings' not in request.files:
        return "No file uploaded", 400
    embeddings = request.files['embeddings']
    if embeddings.filename.endswith('.pkl'):
        embeddings.save(EMBEDDINGS_FILE)
        return "Pre-trained model imported successfully!"
    return "Invalid file format. Please upload a .pkl file.", 400

@app.route('/export', methods=['GET'])
def export_model():
    if os.path.exists(EMBEDDINGS_FILE):
        return send_file(EMBEDDINGS_FILE, as_attachment=True, download_name="embeddings.pkl")
    return "No trained model found to export.", 404

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
EOF

cat << 'EOF' > "$BASE_DIR/process_pdfs.py"
#!/usr/bin/python3
from PyPDF2 import PdfReader
import os
import pickle
from sentence_transformers import SentenceTransformer

pdf_folder = "./pdfs"
output_file = "./embeddings.pkl"
model = SentenceTransformer('all-MiniLM-L6-v2')

print("Starting PDF processing...")
embeddings = []
for pdf_file in os.listdir(pdf_folder):
    if pdf_file.endswith(".pdf"):
        print(f"Processing {pdf_file}...")
        reader = PdfReader(os.path.join(pdf_folder, pdf_file))
        text = ""
        for page in reader.pages:
            text += page.extract_text() or ""
        if text.strip():
            embedding = model.encode(text)
            embeddings.append((text, embedding))
            print(f"Processed {pdf_file} successfully.")
        else:
            print(f"No text extracted from {pdf_file}.")
with open(output_file, "wb") as f:
    pickle.dump(embeddings, f)
print(f"PDF processing complete. Embeddings saved to {output_file}")
EOF

# Create services.sh
cat << 'EOF' > "$BASE_DIR/modules/services.sh"
#!/bin/bash

source "$BASE_DIR/modules/utils.sh"

start_services() {
    if ! command -v ollama >/dev/null 2>&1 || ! podman ps -a | grep -q "open-webui"; then
        log_message "BigMilkAI environment not fully installed. Please select option 10 to install first."
        return
    fi
    log_message "Starting Ollama for BigMilkAI..."
    if systemctl --user status ollama >/dev/null 2>&1; then
        systemctl --user start ollama || {
            log_message "Failed to start Ollama service. Attempting to enable it..."
            systemctl --user enable --now ollama || log_message "Failed to enable Ollama service."
        }
    else
        log_message "Ollama not configured as a service. Starting manually..."
        ollama serve &
        sleep 2
    fi
    log_message "Starting Open WebUI..."
    podman start open-webui || {
        log_message "Open WebUI not running. Recreating container..."
        podman run -d -p 8080:8080 \
          --network=host \
          -v open-webui:/app/backend/data \
          -e "OLLAMA_API_BASE_URL=http://127.0.0.1:11434" \
          -e "OLLAMA_HOST=http://127.0.0.1:11434" \
          -e "DEFAULT_OLLAMA_HOST=http://127.0.0.1:11434" \
          --name open-webui \
          --replace \
          ghcr.io/open-webui/open-webui:main 2>> "$LOG_FILE"
    }
    log_message "BigMilkAI services started!"
}

stop_services() {
    log_message "Stopping Ollama..."
    if systemctl --user status ollama >/dev/null 2>&1; then
        systemctl --user stop ollama || log_message "Failed to stop Ollama service"
    else
        pkill -f "ollama serve" >/dev/null 2>&1 && log_message "Ollama stopped" || log_message "Ollama not running"
    fi
    log_message "Stopping Open WebUI..."
    podman stop open-webui >/dev/null 2>> "$LOG_FILE" && log_message "Open WebUI stopped" || log_message "Open WebUI not running"
    log_message "BigMilkAI services stopped!"
}

restart_services() {
    stop_services
    start_services
    log_message "BigMilkAI services restarted!"
}

check_status() {
    log_message "Checking Ollama status..."
    echo "Checking Ollama status..."
    if systemctl --user status ollama >/dev/null 2>&1; then
        systemctl --user status ollama --no-pager
    else
        pgrep -f "ollama serve" >/dev/null && echo "Ollama is running manually" || echo "Ollama is not running"
    fi
    log_message "Checking Open WebUI status..."
    echo "Checking Open WebUI status..."
    podman ps -a | grep open-webui || echo "Open WebUI is not running"
}

view_logs() {
    log_message "Viewing logs..."
    echo "=== BigMilkAI Script Logs ==="
    if [ -f "$LOG_FILE" ]; then
        cat "$LOG_FILE"
    else
        echo "No script logs found at $LOG_FILE."
    fi
    echo ""
    echo "=== Ollama Logs (if running as service) ==="
    if systemctl --user status ollama >/dev/null 2>&1; then
        journalctl --user-unit ollama --no-pager
    else
        echo "Ollama not running as a service; no logs available."
    fi
    echo ""
    echo "=== Open WebUI Logs ==="
    podman logs open-webui || echo "No logs available for Open WebUI."
}

toggle_boot() {
    log_message "Enable or disable BigMilkAI services on boot? (1 = Enable, 2 = Disable)"
    echo "Enable or disable BigMilkAI services on boot? (1 = Enable, 2 = Disable)"
    read -p "Choice: " boot_choice
    if [ "$boot_choice" = "1" ]; then
        systemctl --user enable ollama >/dev/null 2>&1 || log_message "Ollama service not installed yet"
        log_message "BigMilkAI services enabled on boot."
    elif [ "$boot_choice" = "2" ]; then
        systemctl --user disable ollama >/dev/null 2>&1 || log_message "Ollama service not installed yet"
        log_message "BigMilkAI services disabled on boot."
    else
        log_message "Invalid choice."
    fi
}
EOF

# Create model.sh
cat << 'EOF' > "$BASE_DIR/modules/model.sh"
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
EOF

# Create network.sh
cat << 'EOF' > "$BASE_DIR/modules/network.sh"
#!/bin/bash

source "$BASE_DIR/modules/utils.sh"

show_network_details() {
    log_message "Showing network details..."
    echo "=== BigMilkAI Network Details ==="
    echo "Hostname: $(hostname)"
    echo "Local IPs:"
    ip addr show | grep "inet " | awk '{print "  " $2}' | grep -v "127.0.0.1"
    echo "Loopback IP: 127.0.0.1"
    echo ""
    echo "Service Details:"
    echo "  Ollama:"
    echo "    - IP: 127.0.0.1"
    echo "    - Port: 11434"
    echo "    - Status: $(if systemctl --user status ollama >/dev/null 2>&1; then echo "Running (systemd)"; elif pgrep -f 'ollama serve' >/dev/null; then echo "Running (manual)"; else echo "Not running"; fi)"
    echo "  Open WebUI:"
    echo "    - IP: localhost (or any local IP above)"
    echo "    - Port: 8080"
    echo "    - Status: $(if podman ps | grep -q 'open-webui'; then echo "Running"; else echo "Not running"; fi)"
    echo "    - URL: http://localhost:8080"
    echo "  Web Interface:"
    echo "    - IP: localhost (or any local IP above)"
    echo "    - Port: 5000"
    echo "    - Status: $(if pgrep -f 'web_interface.py' >/dev/null; then echo "Running"; else echo "Not running"; fi)"
    echo "    - URL: http://localhost:5000"
    echo "================================="
}
EOF

# Create web.sh
cat << 'EOF' > "$BASE_DIR/modules/web.sh"
#!/bin/bash

source "$BASE_DIR/modules/utils.sh"

start_web_interface() {
    if [ ! -f "$BASE_DIR/web_interface.py" ]; then
        log_message "BigMilkAI environment not installed. Please select option 10 to install first."
        return
    fi
    log_message "Starting BigMilkAI web interface on http://localhost:5000..."
    cd "$BASE_DIR"
    nohup ./web_interface.py > "$LOG_FILE" 2>&1 &
    log_message "Web interface started! Access it at http://localhost:5000"
}
EOF

# Create bigmilkai_manager.sh with debugging
cat << 'EOF' > "$BASE_DIR/bigmilkai_manager.sh"
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
EOF

# Set permissions
chmod +x "$BASE_DIR/bigmilkai_manager.sh"
chmod +x "$BASE_DIR/modules/"*.sh
chmod +x "$BASE_DIR/"*.py

echo "BigMilkAI modular structure created successfully in $BASE_DIR!"
echo "To use, run: cd $BASE_DIR && ./bigmilkai_manager.sh"
