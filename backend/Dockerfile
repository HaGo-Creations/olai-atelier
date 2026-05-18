# Dockerfile for Hugging Face Spaces deployment.
#
# This image runs the FastAPI backend in CLOUD-ONLY mode (Google AI Studio API).
# Hugging Face Spaces cannot run Ollama or local models on free CPU tier.
# Local mode runs separately on the user's Windows laptop (see README).

FROM python:3.11-slim

WORKDIR /app

# System deps for PDF rendering and image processing
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    poppler-utils \
    && rm -rf /var/lib/apt/lists/*

# Python deps
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# App code
COPY . .

# Hugging Face Spaces expects port 7860
ENV PORT=7860
EXPOSE 7860

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7860"]