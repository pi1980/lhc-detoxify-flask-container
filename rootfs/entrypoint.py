import os
from flask import Flask, request, jsonify
from detoxify import Detoxify

app = Flask(__name__)

# Initialize models outside the request handler
MODEL_NAME = os.environ.get("DETOXIFY_MODEL", "original-small")
ALLOWED_MODELS = ['multilingual', 'original-small', 'original']

if MODEL_NAME not in ALLOWED_MODELS:
    raise ValueError(f"Invalid model name: {MODEL_NAME}. Must be one of {ALLOWED_MODELS}")

try:
    model = Detoxify(MODEL_NAME)
    print(f"Model '{MODEL_NAME}' loaded successfully.")
except Exception as e:
    print(f"Error loading model '{MODEL_NAME}': {e}")
    exit(1)

@app.route('/', methods=['GET', 'POST'])
def detox():
    # Support POST for larger text blocks, fallback to GET for quick tests
    if request.method == 'POST':
        data = request.get_json(silent=True) or {}
        text = data.get('text')
    else:
        text = request.args.get('text')

    # Guard against empty inputs before invoking the model
    if not text:
        return jsonify({"error": "Missing 'text' parameter"}), 400

    try:
        results = model.predict(text)

        # Convert numpy floats to Python floats using dictionary comprehension
        serializable_results = {key: float(value) for key, value in results.items()}

        return jsonify(serializable_results)

    except Exception as e:
        return jsonify({"error": str(e)}), 500
