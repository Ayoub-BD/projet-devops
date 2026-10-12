# Image de départ : un Linux minimal avec Python déjà installé
FROM python:3.14-slim

# Dossier de travail dans le conteneur
WORKDIR /app

# Installer les dépendances avant de copier le code
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copier le reste du projet
COPY . .

# Port utilisé par l'appli
EXPOSE 5000

# Commande lancée au démarrage du conteneur
CMD ["flask", "run", "--host=0.0.0.0"]