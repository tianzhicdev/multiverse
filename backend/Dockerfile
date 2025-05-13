FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Create logs directory with proper permissions
RUN mkdir -p /logs && chmod 777 /logs

EXPOSE 5000

CMD ["python", "-m", "src.web.main"]
