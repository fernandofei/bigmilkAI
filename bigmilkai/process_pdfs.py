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
