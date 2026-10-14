FROM python:3.14-slim

WORKDIR /app

# Dépendances installées en root, puis pip retiré de l'image finale
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && pip uninstall -y pip

# Utilisateur sans privilèges pour exécuter l'application
RUN useradd --create-home --uid 1000 appuser

COPY app.py .

USER appuser

EXPOSE 5000

# Serveur de production Gunicorn (au lieu du serveur de dev de Flask)
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
