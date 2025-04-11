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
