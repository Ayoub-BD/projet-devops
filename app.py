from flask import Flask

app = Flask(__name__)


@app.route("/")
def accueil():
    return "Au revoir depuis mon pipeline DevOps !"
