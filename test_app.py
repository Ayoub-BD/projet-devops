from app import app


def test_accueil():
    client = app.test_client()
    reponse = client.get("/")
    assert reponse.status_code == 200
    assert "Bonjour" in reponse.get_data(as_text=True)
