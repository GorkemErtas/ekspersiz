FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    YOLO_CONFIG_DIR=/tmp/Ultralytics

COPY requirements-runtime.txt .

RUN pip install --no-cache-dir \
    torch==2.13.0+cpu \
    torchvision==0.28.0+cpu \
    --index-url https://download.pytorch.org/whl/cpu

RUN pip install --no-cache-dir -r requirements-runtime.txt

RUN pip uninstall -y opencv-python && \
    pip install --no-cache-dir opencv-python-headless==4.13.0.92

COPY app ./app
COPY main.py .

COPY yolo11n.pt ./yolo11n.pt
COPY models/vehicle_part_best.pt ./models/vehicle_part_best.pt
COPY models/candidates/damage_detection_v2_cardd_5class.pt ./models/candidates/damage_detection_v2_cardd_5class.pt

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]