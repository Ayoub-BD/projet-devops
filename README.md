# projet-devops

[![CI/CD](https://github.com/Ayoub-BD/projet-devops/actions/workflows/ci.yml/badge.svg)](https://github.com/Ayoub-BD/projet-devops/actions/workflows/ci.yml)

Chaîne de livraison continue d'une application Flask conteneurisée, de l'infrastructure cloud jusqu'au déploiement :

- **Infrastructure as Code** : réseau, pare-feu et machine virtuelle Azure décrits avec Terraform
- **Configuration serveur** : installation de Docker et durcissement du système avec Ansible
- **CI/CD** : tests, analyse de sécurité, build, publication et déploiement avec GitHub Actions

L'application est volontairement minimale (une route HTTP). Le périmètre du projet est l'industrialisation qui l'entoure : chaque `push` sur `main` est testé, analysé, empaqueté puis déployé sans intervention manuelle.

---

## Architecture

![Architecture d'ensemble : développeur, GitHub Actions, GHCR, VM Azure, Terraform et Ansible](docs/architecture.svg)

| Couche | Outil | Responsabilité |
|---|---|---|
| Infrastructure | Terraform | Crée les ressources Azure de manière reproductible |
| Configuration | Ansible | Installe Docker, configure le pare-feu, SSH et fail2ban |
| Livraison | GitHub Actions | Teste, analyse, construit, publie et déploie l'application |
| Exécution | Docker | Isole l'application et fige son environnement |

---

## Pipeline CI/CD

Défini dans [`.github/workflows/ci.yml`](.github/workflows/ci.yml), déclenché à chaque push sur `main`. Les jobs sont chaînés par dépendances : un échec à une étape empêche toutes les suivantes.

![Pipeline CI/CD : tests et secrets en parallèle, puis build avec scan Trivy, puis déploiement](docs/pipeline.svg)

| Job | Dépend de | Actions | Bloque si |
|---|---|---|---|
| `tests` | | Installe les dépendances, exécute `pytest` | Un test échoue |
| `secrets` | | Analyse **tout l'historique Git** avec Gitleaks | Un secret est détecté |
| `build` | `tests`, `secrets` | Construit l'image, la scanne avec Trivy, la publie sur GHCR | Faille `CRITICAL` ou `HIGH` corrigeable |
| `deploy` | `build` | Se connecte en SSH, exécute `scripts/deploy.sh` avec l'image du commit | Le site ne répond pas après déploiement |

### Déploiement sur le serveur

Le script [`scripts/deploy.sh`](scripts/deploy.sh) s'exécute sur la VM avec `set -euo pipefail` :

1. `docker pull` de l'image taguée avec le SHA du commit
2. Suppression de l'ancien conteneur, lancement du nouveau (`80 → 5000`, `--restart unless-stopped`)
3. Health check : `curl` sur `localhost`, le script échoue si le site ne répond pas
4. Nettoyage des anciennes images (`docker image prune`)

Chaque version déployée est identifiable par son commit grâce au tag SHA.

---

## Infrastructure Azure

Provisionnée par [`terraform/`](terraform/) (provider `azurerm ~> 4.0`).

![Infrastructure Azure : IP publique, NSG, réseau virtuel, VM avec UFW et conteneur Docker](docs/azure.svg)

| Ressource | Rôle |
|---|---|
| `azurerm_resource_group` | Regroupe toutes les ressources |
| `azurerm_virtual_network`, `azurerm_subnet` | Réseau privé et sous-réseau |
| `azurerm_public_ip` | Adresse IP fixe |
| `azurerm_network_security_group` | Pare-feu cloud : ports 22 et 80 ouverts |
| `azurerm_network_interface` | Relie la VM au sous-réseau, à l'IP et au NSG |
| `azurerm_linux_virtual_machine` | Serveur Ubuntu 24.04 LTS, accès par clé SSH uniquement |

Région, taille de VM et abonnement sont paramétrables dans [`variables.tf`](terraform/variables.tf). L'IP publique est exposée en sortie ([`outputs.tf`](terraform/outputs.tf)).

---

## Configuration du serveur

Le playbook [`ansible/playbook.yml`](ansible/playbook.yml) est idempotent : il peut être rejoué sans effet de bord.

| Domaine | Mise en œuvre |
|---|---|
| Docker | Dépôt officiel avec vérification de la clé GPG, installation de Docker Engine, activation au démarrage |
| Pare-feu | UFW : SSH (22) et HTTP (80) autorisés, tout autre trafic entrant refusé |
| SSH | Authentification par mot de passe désactivée, connexion root interdite, configuration validée par `sshd -t` avant redémarrage du service |
| Anti brute-force | fail2ban sur `sshd` : bannissement d'1 heure après 5 échecs |

---

## Sécurité

| Couche | Mesure | Emplacement |
|---|---|---|
| Code | Détection de secrets sur tout l'historique Git | `ci.yml`, job `secrets` |
| Image | Scan Trivy, build bloqué si faille critique ou haute corrigeable | `ci.yml`, job `build` |
| Image | Base `python:3.14-slim`, `pip` désinstallé de l'image finale, `.dockerignore` | `Dockerfile` |
| Réseau | NSG Azure : seuls les ports 22 et 80 sont ouverts | `terraform/main.tf` |
| Réseau | UFW : refus entrant par défaut | `ansible/playbook.yml` |
| Accès | Clé SSH obligatoire, mot de passe et root désactivés | `ansible/playbook.yml` |
| Accès | fail2ban contre le brute-force SSH | `ansible/playbook.yml` |
| Secrets CI | Clé privée SSH, hôte et utilisateur stockés dans les GitHub Secrets | `ci.yml` |

---

## Stack technique

| Domaine | Technologies |
|---|---|
| Application | Python 3.14, Flask 3, pytest |
| Conteneurs | Docker, GitHub Container Registry |
| CI/CD | GitHub Actions |
| Infrastructure as Code | Terraform |
| Configuration | Ansible |
| Cloud | Microsoft Azure |
| Sécurité | Gitleaks, Trivy, UFW, fail2ban |
| Système | Ubuntu Server 24.04 LTS, Bash |

---

## Structure du dépôt

```
.
├── app.py                      Application Flask
├── test_app.py                 Tests pytest
├── Dockerfile                  Image de l'application
├── requirements.txt            Dépendances Python
├── .github/workflows/ci.yml    Pipeline CI/CD
├── terraform/                  Infrastructure Azure
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── ansible/                    Configuration et durcissement du serveur
│   ├── playbook.yml
│   └── inventory.ini
├── scripts/deploy.sh           Script de déploiement exécuté sur la VM
└── docs/                       Schémas d'architecture (SVG)
```

---

## Prise en main

### Exécution locale

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
pytest
flask run          # http://localhost:5000
```

### Avec Docker

```bash
docker build -t projet-devops .
docker run --rm -p 8080:5000 projet-devops   # http://localhost:8080
```

### Provisionner l'infrastructure

Prérequis : abonnement Azure (`az login`), Terraform, Ansible (collection `community.general`), et deux paires de clés SSH : `~/.ssh/azure_devops` (administration) et `~/.ssh/github_deploy` (déploiement depuis la CI).

```bash
# 1. Créer l'infrastructure
cd terraform
terraform init
terraform apply -var="subscription_id=<ID_ABONNEMENT>"     # relever la sortie ip_publique

# 2. Configurer le serveur (renseigner l'IP dans ansible/inventory.ini)
cd ../ansible
ansible-playbook -i inventory.ini playbook.yml
```

### Activer le déploiement continu

Ajouter ces secrets dans *Settings > Secrets and variables > Actions* :

| Secret | Contenu |
|---|---|
| `SSH_PRIVATE_KEY` | Clé privée de déploiement |
| `SSH_HOST` | Adresse IP du serveur |
| `SSH_USER` | Utilisateur SSH |

Chaque push sur `main` déclenche ensuite le pipeline complet.

---

## Limites connues et évolutions

- State Terraform local : à migrer vers un backend distant (Azure Storage)
- Pas de HTTPS : ajouter un reverse proxy (Caddy ou Traefik) avec Let's Encrypt
- Serveur de développement Flask : le remplacer par Gunicorn en production
- Conteneur exécuté en root, pas de `HEALTHCHECK` Docker
- Pas de rollback automatique si le health check échoue après remplacement du conteneur
- SSH ouvert à toutes les adresses : restreindre par IP source ou utiliser Azure Bastion
- Terraform et Ansible exécutés manuellement : à intégrer à la CI (`plan` sur pull request)
- Pas de supervision : métriques et alertes à ajouter

---

## Auteur

Ayoub — [github.com/Ayoub-BD](https://github.com/Ayoub-BD)
