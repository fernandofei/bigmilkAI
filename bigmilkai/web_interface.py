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
