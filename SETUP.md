# Configuration pré-déploiement

Ce document décrit les étapes de configuration nécessaires avant le premier déploiement.

## 1. Créer les certificats SSL dans Azure Key Vault

Vous avez **3 options** pour gérer les certificats SSL/TLS :

### Option 1 : Automatique via GitHub Actions (Recommandé) ✨

Les certificats sont créés automatiquement lors du déploiement si ils n'existent pas encore. Le workflow vérifie leur présence et les génère si nécessaire.

Pour forcer la création/renouvellement des certificats :

1. Allez dans **Actions** > **Manage SSL Certificates**
2. Cliquez sur **Run workflow**
3. Sélectionnez :
   - **Environment** : `dev` ou `prod`
   - **Certificate Type** : `self-signed` (auto-signé)
   - **Action** : `create`
4. Cliquez sur **Run workflow**

### Option 2 : Script local (Windows PowerShell)

```powershell
# Pour l'environnement Dev
.\scripts\manage-certificates.ps1 -Environment dev -Action create

# Pour l'environnement Prod
.\scripts\manage-certificates.ps1 -Environment prod -Action create

# Pour vérifier les certificats
.\scripts\manage-certificates.ps1 -Environment dev -Action verify
```

### Option 3 : Script local (Linux/Mac Bash)

```bash
# Rendre le script exécutable
chmod +x scripts/manage-certificates.sh

# Pour l'environnement Dev
./scripts/manage-certificates.sh dev create

# Pour l'environnement Prod
./scripts/manage-certificates.sh prod create

# Pour vérifier les certificats
./scripts/manage-certificates.sh dev verify
```

### Option 4 : Manuellement via Azure CLI

#### Pour l'environnement Dev

```bash
# Générer les certificats avec OpenSSL
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout keycloak-key.pem \
  -out keycloak-cert.pem \
  -subj "/C=FR/ST=France/L=Paris/O=OwnCloud/CN=dev.lesaiglesbraves.online"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ocis-key.pem \
  -out ocis-cert.pem \
  -subj "/C=FR/ST=France/L=Paris/O=OwnCloud/CN=dev.lesaiglesbraves.online"

# Importer dans Key Vault
az keyvault certificate import \
  --vault-name owncloudkvdev \
  --name keycloak-tls-cert \
  --file keycloak-cert.pem

az keyvault secret set \
  --vault-name owncloudkvdev \
  --name keycloak-tls-key \
  --file keycloak-key.pem

az keyvault certificate import \
  --vault-name owncloudkvdev \
  --name ocis-tls-cert \
  --file ocis-cert.pem

az keyvault secret set \
  --vault-name owncloudkvdev \
  --name ocis-tls-key \
  --file ocis-key.pem
```

#### Pour l'environnement Prod

```bash
# Même procédure que Dev, en remplaçant :
# - owncloudkvdev par owncloudkvprod
# - dev.lesaiglesbraves.online par prod.lesaiglesbraves.online
```

> **Note** : Pour la production, il est recommandé d'utiliser des certificats signés par une autorité de certification (CA) reconnue comme Let's Encrypt ou un certificat commercial. \
  --name ocis-tls-cert \
  --file ocis-cert.pem

# Créer ou importer la clé privée pour OCIS
az keyvault secret set \
  --vault-name owncloudkvprod \
  --name ocis-tls-key \
  --file ocis-key.pem
```

## 2. Configurer le backend Terraform pour le state

Créez un compte de stockage pour stocker le state Terraform :

### Dev

```bash
# Créer un compte de stockage
az storage account create \
  --name owncloudtfstatedev \
  --resource-group owncloud-rg-dev \
  --location westeurope \
  --sku Standard_LRS

# Créer un container
az storage container create \
  --name tfstate \
  --account-name owncloudtfstatedev
```

### Prod

```bash
# Créer un compte de stockage
az storage account create \
  --name owncloudtfstateprod \
  --resource-group owncloud-rg-prod \
  --location westeurope \
  --sku Standard_LRS

# Créer un container
az storage container create \
  --name tfstate \
  --account-name owncloudtfstateprod
```

## 3. Obtenir le Tenant ID Azure

```bash
az account show --query tenantId -o tsv
```

Mettez à jour le `TENANT_ID` dans les fichiers :
- `k8s/base/secret-provider-class.yaml`

## 4. Configurer les permissions Key Vault

Donnez les permissions nécessaires au Service Principal GitHub Actions :

```bash
# Récupérer l'Object ID du Service Principal
SP_OBJECT_ID=$(az ad sp list --display-name "github-actions-owncloud" --query [0].id -o tsv)

# Dev
az keyvault set-policy \
  --name owncloudkvdev \
  --object-id $SP_OBJECT_ID \
  --secret-permissions get list \
  --certificate-permissions get list

# Prod
az keyvault set-policy \
  --name owncloudkvprod \
  --object-id $SP_OBJECT_ID \
  --secret-permissions get list \
  --certificate-permissions get list
```

## 5. Générer des mots de passe sécurisés

Générez des mots de passe pour les secrets Kubernetes :

```bash
# PostgreSQL
openssl rand -base64 32

# Keycloak Admin
openssl rand -base64 32

# OCIS Admin
openssl rand -base64 32

# OIDC Client Secret
openssl rand -base64 32
```

Mettez à jour ces valeurs dans :
- `k8s/base/kustomization.yaml`
- Ou utilisez des secrets externes depuis Azure Key Vault

## 6. Vérifier les quotas Azure

Assurez-vous que vous avez suffisamment de quotas pour :
- Clusters AKS (au moins 2)
- VMs (Standard_D2s_v3)
- Adresses IP publiques
- Disques managés

```bash
az vm list-usage --location westeurope -o table
```

## 7. Configuration DNS

Une fois l'infrastructure déployée, récupérez l'adresse IP de l'Ingress et configurez vos enregistrements DNS :

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

Créez les enregistrements DNS :
- `dev.lesaiglesbraves.online` → IP de l'Ingress Dev
- `prod.lesaiglesbraves.online` → IP de l'Ingress Prod

## 8. Checklist pré-déploiement

- [ ] Les Resource Groups existent (owncloud-rg-dev, owncloud-rg-prod)
- [ ] Les Key Vaults existent (owncloudkvdev, owncloudkvprod)
- [ ] Les certificats SSL sont dans les Key Vaults
- [ ] Les comptes de stockage pour Terraform state sont créés
- [ ] Le Service Principal GitHub Actions est créé
- [ ] Les permissions Key Vault sont configurées
- [ ] Les secrets GitHub sont configurés
- [ ] Le DNS est prêt à être configuré
- [ ] Les quotas Azure sont suffisants

Une fois toutes ces étapes complétées, vous êtes prêt à déployer !
