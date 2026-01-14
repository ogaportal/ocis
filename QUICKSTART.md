# Quick Start - Déploiement ownCloud OCIS + Keycloak sur Azure AKS

Guide rapide pour déployer l'infrastructure en 5 minutes.

## ⚡ Démarrage rapide avec GitHub Actions

### Prérequis (5 min)

1. **Créer un Service Principal Azure** :
```bash
az login
az ad sp create-for-rbac \
  --name "github-actions-owncloud" \
  --role contributor \
  --scopes /subscriptions/<VOTRE_SUBSCRIPTION_ID> \
  --sdk-auth
```

2. **Copier la sortie JSON** et créer le secret `AZURE_CREDENTIALS` dans GitHub :
   - Settings > Secrets and variables > Actions > New repository secret
   - Name: `AZURE_CREDENTIALS`
   - Value: Coller le JSON complet

3. **Vérifier que les ressources Azure existent** :
```bash
# Resource Groups
az group show --name owncloud-rg-dev
az group show --name owncloud-rg-prod

# Key Vaults
az keyvault show --name owncloudkvdev
az keyvault show --name owncloudkvprod
```

4. **Créer les Storage Accounts pour Terraform state** :
```bash
# Dev
az storage account create \
  --name owncloudsastatedev \
  --resource-group owncloud-rg-dev \
  --location westeurope \
  --sku Standard_LRS

az storage container create \
  --name tfstate \
  --account-name owncloudsastatedev

# Prod
az storage account create \
  --name owncloudsastateprod \
  --resource-group owncloud-rg-prod \
  --location westeurope \
  --sku Standard_LRS

az storage container create \
  --name tfstate \
  --account-name owncloudsastateprod
```

### Déploiement (1 clic)

1. Aller dans **Actions** > **Deploy Infrastructure and Applications**
2. Cliquer sur **Run workflow**
3. Sélectionner :
   - Environment: `dev`
   - Action: `deploy`
4. Cliquer **Run workflow**

⏱️ **Durée** : 20-30 minutes

### Post-déploiement

1. **Récupérer l'IP de l'Ingress** depuis les logs du workflow
2. **Configurer le DNS** :
   ```
   dev.lesaiglesbraves.online -> IP_INGRESS
   ```
3. **Accéder aux applications** :
   - OCIS : https://dev.lesaiglesbraves.online

## 🛠️ Démarrage rapide local (développeurs)

### Prérequis

```bash
# Installer les outils
choco install terraform azure-cli kubernetes-helm kubectl python
pip install ansible kubernetes openshift PyYAML
```

### Étapes

1. **Générer les certificats** :
```powershell
.\scripts\manage-certificates.ps1 -Environment dev -Action create
```

2. **Déployer l'infrastructure** :
```bash
cd terraform/environments/dev
terraform init
terraform apply
```

3. **Déployer les applications** :
```bash
az aks get-credentials --resource-group owncloud-rg-dev --name owncloud-aks-dev
cd ../../ansible
ansible-playbook deploy.yml -i inventories/hosts -e @inventories/dev.yml -e target_env=dev
```

## 📊 Ce qui est déployé

### Infrastructure (Terraform)
- ✅ Cluster AKS (1 nœud Standard_D2s_v3)
- ✅ Azure Blob Storage pour OCIS
- ✅ Intégration avec Key Vault
- ✅ Identités managées

### Applications (Ansible/Kubernetes)
- ✅ NGINX Ingress Controller
- ✅ cert-manager
- ✅ CSI Driver Azure Key Vault
- ✅ PostgreSQL (dans le cluster)
- ✅ Keycloak + PostgreSQL
- ✅ ownCloud OCIS

### Sécurité
- ✅ Certificats SSL/TLS (auto-générés ou Key Vault)
- ✅ Secrets dans Azure Key Vault
- ✅ HTTPS forcé
- ✅ Authentification OIDC (Keycloak)

## 🔑 Certificats SSL/TLS

**Automatique** : Les certificats sont créés automatiquement lors du déploiement.

**Manuel** (si besoin) :
```bash
# Windows
.\scripts\manage-certificates.ps1 -Environment dev -Action create

# Linux/Mac
./scripts/manage-certificates.sh dev create
```


## 📍 Commandes utiles

### Vérifier le déploiement
```bash
kubectl get pods -n owncloud
kubectl get svc -n owncloud
kubectl get ingress -n owncloud
```

### Logs
```bash
kubectl logs -f deployment/ocis -n owncloud
kubectl logs -f deployment/keycloak -n owncloud
kubectl logs -f statefulset/postgres -n owncloud
```

### IP de l'Ingress
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

### Détruire l'environnement
```bash
# Via GitHub Actions
Actions > Deploy Infrastructure and Applications
Environment: dev
Action: destroy

# Via Terraform local
cd terraform/environments/dev
terraform destroy
```

## 🎯 Checklist de déploiement

- [ ] Service Principal créé et configuré dans GitHub Secrets
- [ ] Resource Groups existent (`owncloud-rg-dev`, `owncloud-rg-prod`)
- [ ] Key Vaults existent (`owncloudkvdev`, `owncloudkvprod`)
- [ ] Storage Accounts pour Terraform state créés
- [ ] Workflow lancé avec succès
- [ ] Certificats créés (automatique ou manuel)
- [ ] IP de l'Ingress récupérée
- [ ] DNS configuré
- [ ] Keycloak configuré (realm + client)
- [ ] Secret OIDC mis à jour dans OCIS
- [ ] Applications accessibles via HTTPS

## 📚 Documentation complète

- [README.md](README.md) - Documentation principale
- [SETUP.md](SETUP.md) - Configuration pré-déploiement
- [docs/workflows.md](docs/workflows.md) - Guide des workflows
- [docs/certificate-management.md](docs/certificate-management.md) - Gestion des certificats

## 🆘 Dépannage rapide

### Les pods ne démarrent pas
```bash
kubectl describe pod <POD_NAME> -n owncloud
kubectl logs <POD_NAME> -n owncloud
```

### Certificats invalides
```bash
# Vérifier dans Key Vault
az keyvault certificate list --vault-name owncloudkvdev --output table

# Régénérer
.\scripts\manage-certificates.ps1 -Environment dev -Action create
```

### Terraform state locked
```bash
cd terraform/environments/dev
terraform force-unlock <LOCK_ID>
```

### Accès refusé Key Vault
```bash
# Vérifier les permissions
az keyvault show --name owncloudkvdev --query properties.accessPolicies
```

## 🚀 Prochaines étapes

1. **Production** : Répéter le processus avec `environment: prod`
2. **Monitoring** : Configurer Azure Monitor
3. **Backup** : Configurer la sauvegarde PostgreSQL
4. **Scaling** : Ajuster le nombre de nœuds AKS si besoin
5. **Certificats CA** : Remplacer auto-signés par Let's Encrypt en prod

---

**Temps total estimé** : 30-45 minutes pour un déploiement complet (dev + prod)
