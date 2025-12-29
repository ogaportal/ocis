# Documentation des Workflows GitHub Actions

Ce document décrit les workflows GitHub Actions disponibles pour gérer le déploiement et la maintenance de l'infrastructure ownCloud OCIS.

## 📋 Workflows disponibles

### 1. Deploy Infrastructure and Applications

**Fichier** : [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml)

**Description** : Workflow principal pour déployer ou détruire l'infrastructure et les applications.

**Déclenchement** : Manuel (`workflow_dispatch`)

**Paramètres** :
- **environment** : Environnement cible (`dev` ou `prod`)
- **action** : Action à effectuer (`deploy` ou `destroy`)

**Jobs** :
1. **check-certificates** : Vérifie la présence des certificats SSL/TLS dans Azure Key Vault
   - Si les certificats n'existent pas et que l'action est `deploy`, ils sont automatiquement générés (auto-signés)
   - Upload automatique vers Azure Key Vault

2. **terraform** : Déploie ou détruit l'infrastructure Azure avec Terraform
   - Création du cluster AKS
   - Création du compte de stockage Azure Blob
   - Configuration des accès Key Vault

3. **deploy-apps** : Déploie les applications avec Ansible (seulement si action = `deploy`)
   - Installation de NGINX Ingress Controller
   - Installation de cert-manager
   - Installation du CSI Driver pour Azure Key Vault
   - Déploiement de PostgreSQL, Keycloak et OCIS

4. **destroy-apps** : Détruit les applications avec Ansible (seulement si action = `destroy`)

**Exemple d'utilisation** :
```yaml
Environment: dev
Action: deploy
```

### 2. Manage SSL Certificates

**Fichier** : [`.github/workflows/manage-certificates.yml`](../.github/workflows/manage-certificates.yml)

**Description** : Workflow dédié à la gestion des certificats SSL/TLS.

**Déclenchement** : Manuel (`workflow_dispatch`)

**Paramètres** :
- **environment** : Environnement cible (`dev` ou `prod`)
- **certificate_type** : Type de certificat (`self-signed` ou `letsencrypt`)
- **action** : Action à effectuer (`create`, `renew` ou `delete`)

**Fonctionnalités** :
- ✅ Génération de certificats auto-signés
- ✅ Upload vers Azure Key Vault
- ✅ Vérification des certificats existants
- ⚠️ Support Let's Encrypt (nécessite configuration DNS)
- ✅ Suppression de certificats

**Exemple d'utilisation** :
```yaml
Environment: dev
Certificate Type: self-signed
Action: create
```

### 3. Terraform Plan

**Fichier** : [`.github/workflows/terraform-plan.yml`](../.github/workflows/terraform-plan.yml)

**Description** : Affiche un plan Terraform sur les Pull Requests pour visualiser les changements d'infrastructure.

**Déclenchement** : Automatique sur Pull Request vers `main` ou `develop` avec modifications dans `terraform/**`

**Jobs** :
- **plan-dev** : Génère un plan Terraform pour l'environnement dev
- **plan-prod** : Génère un plan Terraform pour l'environnement prod

**Fonctionnalités** :
- Validation de la syntaxe Terraform
- Génération du plan d'exécution
- Commentaire automatique sur la PR avec le résultat

## 🚀 Guide d'utilisation

### Premier déploiement (Dev)

1. **Créer les certificats** (optionnel - fait automatiquement) :
   - Actions > Manage SSL Certificates
   - Environment: `dev`
   - Certificate Type: `self-signed`
   - Action: `create`

2. **Déployer l'infrastructure et les applications** :
   - Actions > Deploy Infrastructure and Applications
   - Environment: `dev`
   - Action: `deploy`

3. **Attendre la fin du déploiement** (~15-20 minutes)

4. **Récupérer l'IP de l'Ingress** depuis les logs du job `deploy-apps`

5. **Configurer le DNS** pour pointer `dev.lesaiglesbraves.online` vers l'IP

### Déploiement en production

Suivre la même procédure mais avec `environment: prod`.

### Renouveler les certificats

1. Actions > Manage SSL Certificates
2. Environment: `dev` ou `prod`
3. Certificate Type: `self-signed`
4. Action: `renew`

### Détruire un environnement

1. Actions > Deploy Infrastructure and Applications
2. Environment: `dev` ou `prod`
3. Action: `destroy`

## 🔐 Secrets GitHub requis

Les secrets suivants doivent être configurés dans le repository GitHub :

### AZURE_CREDENTIALS

Credentials Azure au format JSON pour l'authentification du Service Principal.

**Création** :
```bash
az ad sp create-for-rbac \
  --name "github-actions-owncloud" \
  --role contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID> \
  --sdk-auth
```

**Format attendu** :
```json
{
  "clientId": "...",
  "clientSecret": "...",
  "subscriptionId": "...",
  "tenantId": "...",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

## 📊 Diagramme de flux

```
┌─────────────────────────────────────────────┐
│     Deploy Infrastructure & Applications    │
└─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│     1. Check/Create Certificates            │
│     - Vérifier existence dans Key Vault     │
│     - Générer si absent (auto-signé)        │
│     - Upload vers Key Vault                 │
└─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│     2. Terraform Apply                      │
│     - Créer AKS cluster                     │
│     - Créer Storage Account                 │
│     - Configurer accès Key Vault            │
└─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│     3. Deploy Applications (Ansible)        │
│     - NGINX Ingress Controller              │
│     - cert-manager                          │
│     - CSI Driver Key Vault                  │
│     - PostgreSQL                            │
│     - Keycloak                              │
│     - OCIS                                  │
└─────────────────────────────────────────────┘
```

## ⚠️ Notes importantes

### Certificats auto-signés vs Let's Encrypt

- **Auto-signés** : Parfait pour dev/test, pas pour la production (avertissement navigateur)
- **Let's Encrypt** : Certificats valides reconnus, mais nécessite :
  - Configuration DNS publique
  - Validation de domaine via challenge HTTP ou DNS
  - Pour production, utiliser cert-manager dans le cluster

### Durée des déploiements

- **Infrastructure Terraform** : ~10-15 minutes
- **Applications Ansible** : ~10-15 minutes
- **Total** : ~20-30 minutes

### Ordre des opérations

1. ✅ Certificats (automatique ou manuel)
2. ✅ Infrastructure (Terraform)
3. ✅ Applications (Ansible)

Les certificats doivent exister **avant** le déploiement des applications car elles en dépendent.

## 🔧 Dépannage

### Le workflow échoue lors de la création des certificats

- Vérifier les permissions du Service Principal sur le Key Vault
- Vérifier que le Key Vault existe bien
- Vérifier les logs du job pour plus de détails

### Le workflow Terraform échoue

- Vérifier que les Resource Groups existent
- Vérifier que les quotas Azure sont suffisants
- Vérifier le backend Terraform (Storage Account pour le state)

### Le déploiement Ansible échoue

- Vérifier que le cluster AKS est bien créé
- Vérifier les credentials kubectl
- Vérifier les repositories Helm

## 📚 Ressources

- [Documentation Terraform Azure](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Documentation Ansible Kubernetes](https://docs.ansible.com/ansible/latest/collections/kubernetes/core/index.html)
- [Documentation GitHub Actions](https://docs.github.com/en/actions)
- [Documentation Azure Key Vault](https://docs.microsoft.com/en-us/azure/key-vault/)
