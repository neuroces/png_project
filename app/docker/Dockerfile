# Use minimal Python image
FROM python:3.12-slim

# Set a working directory inside the container
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY plot_fft.py .

# Use an entrypoint script to convert env vars to args
ENTRYPOINT ["sh", "-c", "python plot_fft.py $INPUT_BUCKET $INPUT_KEY"]