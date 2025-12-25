# Scripts de gestion

Ce dossier contient des scripts utilitaires pour gérer les certificats SSL/TLS et d'autres opérations de maintenance.

## 📜 Scripts disponibles

### manage-certificates.sh (Linux/Mac)

Script Bash pour gérer les certificats SSL/TLS dans Azure Key Vault.

**Usage** :
```bash
chmod +x manage-certificates.sh
./manage-certificates.sh [dev|prod] [create|delete|verify]
```

**Exemples** :
```bash
# Créer des certificats pour l'environnement dev
./manage-certificates.sh dev create

# Vérifier les certificats en production
./manage-certificates.sh prod verify

# Supprimer les certificats de dev
./manage-certificates.sh dev delete
```

**Prérequis** :
- Azure CLI installé et configuré
- OpenSSL
- Connexion Azure active (`az login`)

### manage-certificates.ps1 (Windows)

Script PowerShell pour gérer les certificats SSL/TLS dans Azure Key Vault.

**Usage** :
```powershell
.\manage-certificates.ps1 -Environment [dev|prod] -Action [create|delete|verify]
```

**Exemples** :
```powershell
# Créer des certificats pour l'environnement dev
.\manage-certificates.ps1 -Environment dev -Action create

# Vérifier les certificats en production
.\manage-certificates.ps1 -Environment prod -Action verify

# Supprimer les certificats de dev
.\manage-certificates.ps1 -Environment dev -Action delete
```

**Prérequis** :
- Azure CLI installé et configuré
- OpenSSL (Win32 OpenSSL ou via Git Bash)
- Connexion Azure active (`az login`)
- PowerShell 5.1+ ou PowerShell Core 7+

## 🔧 Fonctionnalités communes

Les deux scripts offrent les mêmes fonctionnalités :

### create
- Génère des certificats SSL/TLS auto-signés (valides 365 jours)
- Crée les certificats pour Keycloak et OCIS
- Upload automatique vers Azure Key Vault
- Nettoyage automatique des fichiers temporaires
- Vérification finale de l'upload

### delete
- Supprime les certificats de Azure Key Vault
- Confirmation obligatoire avant suppression
- Supprime certificats ET clés privées
- Purge des versions (soft-delete)

### verify
- Liste tous les certificats dans Key Vault
- Affiche les dates d'expiration
- Affiche le statut (enabled/disabled)
- Sépare certificats et secrets (clés privées)

## 🔐 Certificats créés

Pour chaque environnement, les scripts créent :

| Nom Key Vault       | Type       | Description                    |
|---------------------|------------|--------------------------------|
| keycloak-tls-cert   | Certificat | Certificat public Keycloak     |
| keycloak-tls-key    | Secret     | Clé privée Keycloak            |
| ocis-tls-cert       | Certificat | Certificat public OCIS         |
| ocis-tls-key        | Secret     | Clé privée OCIS                |

## ⚙️ Configuration

Les scripts utilisent les configurations suivantes :

### Environnement Dev
- Domaine : `dev.lesaiglesbraves.online`
- Key Vault : `owncloudkvdev`

### Environnement Prod
- Domaine : `prod.lesaiglesbraves.online`
- Key Vault : `owncloudkvprod`

Pour modifier ces valeurs, éditez les variables en début de fichier.

## 🚨 Gestion des erreurs

Les scripts incluent :
- ✅ Vérification des prérequis (Azure CLI, OpenSSL)
- ✅ Vérification de la connexion Azure
- ✅ Messages d'erreur clairs et informatifs
- ✅ Arrêt en cas d'erreur (`set -e` pour Bash)
- ✅ Nettoyage automatique même en cas d'erreur

## 📊 Sortie des scripts

### Messages de succès (vert)
```
[INFO] ✓ Certificats générés avec succès
[INFO] ✓ Certificats uploadés avec succès
```

### Avertissements (jaune)
```
[WARN] Suppression des certificats du Key Vault: owncloudkvdev
```

### Erreurs (rouge)
```
[ERROR] Azure CLI n'est pas installé
[ERROR] Vous n'êtes pas connecté à Azure
```

## 🔄 Workflow typique

### Première installation

```bash
# 1. Créer les certificats
./manage-certificates.sh dev create

# 2. Vérifier qu'ils sont bien créés
./manage-certificates.sh dev verify

# 3. Déployer l'infrastructure
cd ../terraform/environments/dev
terraform apply
```

### Renouvellement des certificats

```bash
# 1. Supprimer les anciens
./manage-certificates.sh dev delete

# 2. Créer de nouveaux certificats
./manage-certificates.sh dev create

# 3. Redémarrer les pods pour charger les nouveaux certificats
kubectl rollout restart deployment/keycloak -n owncloud
kubectl rollout restart deployment/ocis -n owncloud
```

### Migration dev → prod

```bash
# Après validation en dev, déployer en prod
./manage-certificates.sh prod create
./manage-certificates.sh prod verify
```

## 🛡️ Sécurité

### Bonnes pratiques

- ✅ Les certificats sont stockés uniquement dans Azure Key Vault
- ✅ Les fichiers temporaires sont supprimés automatiquement
- ✅ Pas de certificats dans le code source
- ✅ Permissions Key Vault strictement contrôlées

### À éviter

- ❌ Ne commitez JAMAIS les fichiers `.pem`
- ❌ Ne partagez pas les certificats par email
- ❌ Ne stockez pas les certificats en local
- ❌ N'utilisez pas les mêmes certificats dev/prod

## 🐛 Dépannage

### "Azure CLI n'est pas installé"
```bash
# Installer Azure CLI
# Windows: choco install azure-cli
# Mac: brew install azure-cli
# Linux: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### "OpenSSL n'est pas installé"
```bash
# Windows: Installer Win32 OpenSSL ou utiliser Git Bash
# Mac: brew install openssl
# Linux: sudo apt install openssl
```

### "Vous n'êtes pas connecté à Azure"
```bash
az login
az account set --subscription <SUBSCRIPTION_ID>
```

### "Permission denied: ./manage-certificates.sh"
```bash
chmod +x manage-certificates.sh
```

### "Key Vault not found"
```bash
# Vérifier que le Key Vault existe
az keyvault show --name owncloudkvdev
```

## 📚 Documentation associée

- [Guide de gestion des certificats](../docs/certificate-management.md)
- [Documentation des workflows](../docs/workflows.md)
- [Guide de démarrage rapide](../QUICKSTART.md)

## 🤝 Contribution

Pour améliorer ces scripts :
1. Testez vos modifications localement
2. Assurez-vous que les deux scripts (Bash et PowerShell) restent synchronisés
3. Mettez à jour cette documentation
4. Ouvrez une Pull Request

---

**Note** : Ces scripts sont idempotents - vous pouvez les exécuter plusieurs fois sans effet de bord.
