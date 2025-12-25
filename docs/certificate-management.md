# Gestion Automatique des Certificats SSL/TLS 🔐

Cette fonctionnalité permet de gérer automatiquement la création, le renouvellement et la suppression des certificats SSL/TLS nécessaires au déploiement de ownCloud OCIS et Keycloak.

## 🎯 Fonctionnalités

### ✅ Création automatique lors du déploiement
- Le workflow `Deploy Infrastructure and Applications` vérifie automatiquement la présence des certificats dans Azure Key Vault
- Si les certificats n'existent pas, ils sont générés automatiquement (certificats auto-signés)
- Upload automatique vers Azure Key Vault
- Aucune intervention manuelle nécessaire

### ✅ Workflow dédié pour la gestion des certificats
- Workflow `Manage SSL Certificates` pour gérer les certificats indépendamment
- Actions disponibles : `create`, `renew`, `delete`
- Support des certificats auto-signés
- Préparation pour Let's Encrypt (nécessite configuration DNS)

### ✅ Scripts locaux pour gestion manuelle
- Script PowerShell pour Windows : `scripts/manage-certificates.ps1`
- Script Bash pour Linux/Mac : `scripts/manage-certificates.sh`
- Génération, upload et vérification des certificats

## 📁 Fichiers créés/modifiés

### Nouveaux fichiers

1. **`.github/workflows/manage-certificates.yml`**
   - Workflow GitHub Actions pour gérer les certificats
   - Génération de certificats auto-signés
   - Upload/suppression dans Azure Key Vault

2. **`scripts/manage-certificates.sh`**
   - Script Bash pour Linux/Mac
   - Fonctions : create, delete, verify
   - Vérification des prérequis

3. **`scripts/manage-certificates.ps1`**
   - Script PowerShell pour Windows
   - Mêmes fonctionnalités que le script Bash
   - Support natif Windows

4. **`docs/workflows.md`**
   - Documentation complète des workflows
   - Guide d'utilisation
   - Diagrammes de flux
   - Dépannage

### Fichiers modifiés

1. **`.github/workflows/deploy.yml`**
   - Ajout du job `check-certificates`
   - Vérification automatique des certificats
   - Génération si absents
   - Upload vers Key Vault

2. **`SETUP.md`**
   - Mise à jour avec 4 options pour gérer les certificats
   - Instructions pour chaque méthode
   - Recommandation de l'option automatique

3. **`README.md`**
   - Mise en avant de la gestion automatique
   - Réorganisation des méthodes de déploiement
   - GitHub Actions comme méthode recommandée

## 🚀 Utilisation

### Option 1 : Automatique (Recommandé)

Lors du déploiement avec GitHub Actions, les certificats sont créés automatiquement :

```
Actions > Deploy Infrastructure and Applications
Environment: dev
Action: deploy
```

### Option 2 : Workflow dédié

Pour gérer les certificats séparément :

```
Actions > Manage SSL Certificates
Environment: dev
Certificate Type: self-signed
Action: create
```

### Option 3 : Script PowerShell (Windows)

```powershell
.\scripts\manage-certificates.ps1 -Environment dev -Action create
```

### Option 4 : Script Bash (Linux/Mac)

```bash
chmod +x scripts/manage-certificates.sh
./scripts/manage-certificates.sh dev create
```

## 🔄 Workflow de déploiement mis à jour

```
┌─────────────────────────────────────┐
│  Démarrage du workflow Deploy       │
└─────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│  Job 1: check-certificates          │
│  ✓ Vérifier si certificats existent │
│  ✓ Si absent: générer auto-signés   │
│  ✓ Upload vers Key Vault            │
└─────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│  Job 2: terraform                   │
│  ✓ Créer infrastructure AKS         │
│  ✓ Créer Storage Account            │
└─────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│  Job 3: deploy-apps                 │
│  ✓ Déployer PostgreSQL              │
│  ✓ Déployer Keycloak                │
│  ✓ Déployer OCIS                    │
└─────────────────────────────────────┘
```

## 📋 Certificats créés

Pour chaque environnement (dev/prod), les certificats suivants sont créés dans Azure Key Vault :

| Nom                  | Type        | Usage              |
|---------------------|-------------|--------------------|
| keycloak-tls-cert   | Certificat  | Certificat Keycloak|
| keycloak-tls-key    | Secret      | Clé privée Keycloak|
| ocis-tls-cert       | Certificat  | Certificat OCIS    |
| ocis-tls-key        | Secret      | Clé privée OCIS    |

## ⚙️ Configuration

### Variables d'environnement dans les workflows

```yaml
env:
  DEV_DOMAIN: dev.lesaiglesbraves.online
  PROD_DOMAIN: prod.lesaiglesbraves.online
  DEV_KEYVAULT: owncloudkvdev
  PROD_KEYVAULT: owncloudkvprod
```

### Durée de validité

- **Certificats auto-signés** : 365 jours
- **Algorithme** : RSA 2048 bits
- **Subject Alternative Names** : Domaine principal + wildcard

## 🔒 Sécurité

- ✅ Certificats stockés dans Azure Key Vault (jamais dans le code)
- ✅ Clés privées séparées des certificats publics
- ✅ Nettoyage automatique des fichiers temporaires
- ✅ Utilisation de l'identité managée AKS pour accéder aux certificats
- ✅ Rotation facilitée avec le workflow de renouvellement

## ⚠️ Notes importantes

### Certificats auto-signés vs Production

- **Dev/Test** : Certificats auto-signés parfaits
- **Production** : Utiliser des certificats signés par une CA (Let's Encrypt, DigiCert, etc.)

### Let's Encrypt

Le workflow supporte Let's Encrypt mais nécessite :
- Configuration DNS publique validée
- Challenge ACME (HTTP ou DNS)
- Pour la production, privilégier cert-manager dans le cluster

### Renouvellement

Les certificats auto-signés sont valides 365 jours. Pour les renouveler :

```yaml
Actions > Manage SSL Certificates
Environment: dev
Certificate Type: self-signed
Action: renew
```

## 📚 Documentation

- [Guide complet des workflows](docs/workflows.md)
- [Configuration pré-déploiement](SETUP.md)
- [README principal](README.md)

## 🎉 Avantages

1. **Zéro configuration manuelle** : Les certificats sont créés automatiquement
2. **Simplicité** : Un seul workflow pour tout déployer
3. **Flexibilité** : Plusieurs méthodes disponibles (workflow, scripts, manuel)
4. **Sécurité** : Stockage dans Azure Key Vault
5. **Traçabilité** : Tous les certificats versionnés et horodatés
6. **Idempotence** : Vérification avant création (pas de doublon)

## 🔍 Vérification

Pour vérifier les certificats dans Key Vault :

```bash
# Via script
./scripts/manage-certificates.sh dev verify

# Via Azure CLI
az keyvault certificate list --vault-name owncloudkvdev --output table
az keyvault secret list --vault-name owncloudkvdev --output table
```

## 🆘 Support

En cas de problème avec les certificats :
1. Consulter la [documentation des workflows](docs/workflows.md)
2. Vérifier les logs du workflow GitHub Actions
3. Utiliser les scripts locaux pour diagnostic
4. Vérifier les permissions du Service Principal sur Key Vault
