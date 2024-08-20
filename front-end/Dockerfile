FROM python:3.10-slim

WORKDIR /app
COPY app.py .
COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt && \
    rm -rf /root/.cache/pip


EXPOSE 8501

CMD ["streamlit", "run", "app.py"]
