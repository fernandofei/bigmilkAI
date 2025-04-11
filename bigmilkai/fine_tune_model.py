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
