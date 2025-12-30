# Test de Charge avec Locust

Ce dossier contient les scripts et configurations pour effectuer des tests de charge sur l'application OCIS.

## 📋 Fichiers

- **`locustfile.py`** : Script Locust principal qui simule des utilisateurs concurrents
- **`requirements-locust.txt`** : Dépendances Python pour Locust

## 🎯 Configuration du Test

Le test de charge est configuré pour :

- **50 utilisateurs concurrents**
- **Taux de montée en charge** : 5 utilisateurs/seconde
- **Durée** : 2 minutes
- **Cible** : Production uniquement (`prod.lesaiglesbraves.online`)

## ✅ Critères de Succès

Le test est considéré comme réussi si :

1. **Taux d'échec** < 5%
2. **Temps de réponse moyen** < 3000ms
3. Au moins une requête a été effectuée

## 🚀 Utilisation Locale

### Installation

```bash
pip install -r scripts/requirements-locust.txt
```

### Exécution en mode headless (sans interface)

```bash
# Test contre production
locust -f scripts/locustfile.py \
  --host https://prod.lesaiglesbraves.online \
  --users 50 \
  --spawn-rate 5 \
  --run-time 2m \
  --headless \
  --html reports/load-test-report.html

# Test contre dev
locust -f scripts/locustfile.py \
  --host https://dev.lesaiglesbraves.online \
  --users 20 \
  --spawn-rate 2 \
  --run-time 1m \
  --headless
```

### Exécution en mode Web UI

```bash
locust -f scripts/locustfile.py --host https://prod.lesaiglesbraves.online
```

Puis ouvrez http://localhost:8089 dans votre navigateur.

## 📊 Scénarios de Test

Le script simule les actions suivantes :

1. **Accès à la page d'accueil** (poids : 3)
   - Vérifie que l'application répond
   - Accepte les codes 200, 301, 302, 307, 308

2. **Accès à la page de connexion** (poids : 2)
   - Teste l'endpoint de login
   - Vérifie la disponibilité du formulaire

3. **Health Check** (poids : 1)
   - Teste différents endpoints (/, /health, /status, /app/)
   - Vérifie que l'application est en ligne

## 🔧 Personnalisation

### Modifier le nombre d'utilisateurs

Éditez le workflow GitHub Actions (`.github/workflows/build-and-deploy.yml`) :

```yaml
--users 100 \        # Nombre d'utilisateurs concurrents
--spawn-rate 10 \    # Utilisateurs ajoutés par seconde
--run-time 5m \      # Durée du test
```

### Modifier les critères de succès

Éditez `locustfile.py` dans la fonction `on_test_stop` :

```python
# Modifier le taux d'échec maximum (actuellement 5%)
if failure_rate > 5.0:
    
# Modifier le temps de réponse maximum (actuellement 3000ms)
if avg_response_time > 3000:
```

### Ajouter des scénarios de test

Dans `locustfile.py`, ajoutez de nouvelles tâches dans la classe `OCISUser` :

```python
@task(1)
def my_custom_test(self):
    """Description de votre test"""
    with self.client.get("/mon-endpoint", catch_response=True) as response:
        if response.status_code == 200:
            response.success()
        else:
            response.failure(f"Erreur: {response.status_code}")
```

## 📈 Rapports

Les rapports de test sont générés dans le dossier `reports/` :

- **`load-test-report.html`** : Rapport détaillé avec graphiques
- **`load-test_stats.csv`** : Statistiques détaillées par endpoint
- **`load-test_failures.csv`** : Liste des échecs

Ces rapports sont également disponibles en tant qu'artifacts dans GitHub Actions pendant 30 jours.

## 🔍 Interprétation des Résultats

### Métriques clés

- **Requests/sec** : Nombre de requêtes traitées par seconde
- **Average Response Time** : Temps de réponse moyen en millisecondes
- **Failure Rate** : Pourcentage de requêtes échouées
- **50th/90th/95th Percentile** : Temps de réponse pour X% des utilisateurs

### Que faire si le test échoue ?

1. **Taux d'échec élevé (>5%)** :
   - Vérifier les logs de l'application
   - Vérifier les ressources AKS (CPU, mémoire)
   - Augmenter le nombre de replicas OCIS
   - Vérifier la configuration de l'Ingress

2. **Temps de réponse élevé (>3000ms)** :
   - Augmenter les ressources des pods (CPU/mémoire)
   - Ajouter des replicas pour la scalabilité horizontale
   - Optimiser la configuration d'OCIS
   - Vérifier la latence réseau

3. **Timeouts fréquents** :
   - Augmenter les timeouts de l'Ingress
   - Vérifier les connexions à Azure Storage
   - Vérifier les limites de Key Vault

## 🎯 Intégration CI/CD

Le test de charge s'exécute automatiquement :

- ✅ **Quand** : Après chaque déploiement en production (branche `main`)
- ✅ **Condition** : Uniquement si le déploiement réussit
- ❌ **Échec** : Si les critères de performance ne sont pas atteints

Le workflow échoue si le test de charge échoue, empêchant ainsi de déployer une version non performante en production.
