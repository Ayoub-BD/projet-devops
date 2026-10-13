from flask import Flask

app = Flask(__name__)


@app.route("/")
def accueil():
    return "Bonjour depuis mon pipeline DevOps ! Déployé automatiquement."
