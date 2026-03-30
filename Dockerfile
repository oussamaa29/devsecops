# Image de base volontairement ancienne pour démontrer les CVEs détectées par Trivy
FROM python:3.8-slim

WORKDIR /app

# Copier les dépendances en premier (cache Docker)
COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# Copier le code source
COPY app.py .

# Exposer le port de l'application
EXPOSE 5000

# Lancer l'application
CMD ["python", "app.py"]
