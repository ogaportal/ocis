# Changelog

Toutes les modifications notables de ce projet seront documentées dans ce fichier.

## [1.2.0] - 2025-12-27

### 🔧 Modifié

#### Résolution du problème de timeout cert-manager
- **Suppression de cert-manager** : cert-manager n'est plus utilisé pour générer les certificats
  - Suppression de l'installation de cert-manager dans `ansible/deploy.yml`
  - Suppression du repository Helm jetstack
  - Suppression des étapes d'attente de génération de certificats (qui causaient des timeouts)

- **Nouvelle approche avec Azure Key Vault + CSI Driver**
  - Les certificats sont maintenant générés localement via `scripts/manage-certificates.ps1`
  - Upload automatique vers Azure Key Vault
  - Synchronisation automatique dans Kubernetes via le CSI Driver
  - Création de `k8s/base/certificates-keyvault.yaml` avec SecretProviderClass
  - Sauvegarde de l'ancienne config dans `k8s/base/certificates.yaml.bak`

- **Mise à jour du déploiement Ansible**
  - Nouvelle étape : "Wait for CSI SecretProviderClass to sync certificates from Key Vault"
  - Plus de dépendance sur cert-manager
  - Déploiement plus rapide et fiable

- **Mise à jour des configurations Kustomize**
  - Modification de `k8s/base/kustomization.yaml` pour utiliser `certificates-keyvault.yaml`
  - Simplification des patches dans `k8s/overlays/dev/kustomization.yaml`

### ✨ Ajouté

#### Documentation
- **`docs/certificate-deployment-guide.md`** : Guide complet pour générer et déployer les certificats
  - Procédure pas à pas
  - Vérifications post-déploiement
  - Section troubleshooting
  - Guide de renouvellement

- **Référence dans README.md** : Ajout du lien vers le nouveau guide

### ✅ Avantages de cette version
- ✅ Plus de timeout lors du déploiement
- ✅ Contrôle total sur les certificats
- ✅ Déploiement plus rapide
- ✅ Meilleure intégration avec Azure Key Vault
- ✅ Compatible avec le workflow GitHub Actions existant

## [1.1.0] - 2025-12-25

### ✨ Ajouté

#### Gestion automatique des certificats SSL/TLS
- **Workflow GitHub Actions** : `manage-certificates.yml` pour gérer les certificats indépendamment
  - Création de certificats auto-signés
  - Renouvellement de certificats
  - Suppression de certificats
  - Support préparé pour Let's Encrypt

- **Job de vérification des certificats** dans le workflow de déploiement principal
  - Vérification automatique de la présence des certificats dans Azure Key Vault
  - Génération automatique de certificats auto-signés si absents
  - Upload automatique vers Azure Key Vault
  - Aucune intervention manuelle nécessaire pour le premier déploiement

- **Scripts locaux pour gestion des certificats**
  - `scripts/manage-certificates.sh` : Script Bash pour Linux/Mac
  - `scripts/manage-certificates.ps1` : Script PowerShell pour Windows
  - Fonctionnalités : create, delete, verify
  - Vérification automatique des prérequis

#### Documentation
- `docs/workflows.md` : Documentation complète des workflows GitHub Actions
- `docs/certificate-management.md` : Guide détaillé de gestion des certificats
- `QUICKSTART.md` : Guide de démarrage rapide pour déploiement en 5 minutes
- Mise à jour de `README.md` avec les nouvelles fonctionnalités
- Mise à jour de `SETUP.md` avec 4 options de gestion des certificats

#### Configuration
- `.gitattributes` : Configuration des fins de ligne pour les scripts shell
- Variables d'environnement standardisées dans tous les workflows

### 🔄 Modifié

- **Workflow de déploiement principal** (`deploy.yml`)
  - Ajout du job `check-certificates` avant Terraform
  - Dépendances mises à jour pour `deploy-apps`
  - Meilleure gestion des erreurs

- **README.md**
  - Réorganisation avec GitHub Actions comme méthode recommandée
  - Mise en avant de la gestion automatique des certificats
  - Nouvelle structure de documentation

- **SETUP.md**
  - 4 options clairement définies pour la gestion des certificats
  - Recommandation de l'option automatique
  - Simplification des instructions manuelles

### 🎯 Améliorations

- **Expérience utilisateur**
  - Déploiement en 1 clic via GitHub Actions
  - Certificats créés automatiquement (zéro configuration)
  - Documentation structurée et progressive

- **Sécurité**
  - Certificats toujours stockés dans Azure Key Vault
  - Nettoyage automatique des fichiers temporaires
  - Séparation certificats publics / clés privées

- **Flexibilité**
  - Plusieurs méthodes de gestion des certificats
  - Scripts utilisables localement ou dans CI/CD
  - Support multi-plateforme (Windows, Linux, Mac)

### 📝 Notes

- Les certificats auto-signés sont parfaits pour dev/test mais pas pour la production
- Pour la production, il est recommandé d'utiliser des certificats signés par une CA
- Le support Let's Encrypt est préparé mais nécessite configuration DNS

---

## [1.0.0] - 2025-12-25

### ✨ Version initiale

#### Infrastructure Terraform
- Module AKS pour Azure Kubernetes Service
- Intégration avec Azure Key Vault
- Compte de stockage Azure Blob pour OCIS
- Gestion des identités managées
- Environnements séparés dev et prod

#### Déploiement Ansible
- Playbook de déploiement complet
- Playbook de destruction
- Installation automatique de :
  - NGINX Ingress Controller
  - cert-manager
  - CSI Driver Azure Key Vault
  - PostgreSQL
  - Keycloak
  - ownCloud OCIS

#### Manifests Kubernetes
- Architecture Kustomize avec base et overlays
- Déploiement PostgreSQL dans le cluster
- Déploiement Keycloak avec OIDC
- Déploiement OCIS avec Azure Blob Storage
- Ingress configuré pour HTTPS

#### GitHub Actions
- Workflow de déploiement/destruction
- Workflow de plan Terraform sur PR
- Paramétrisation par environnement

#### Documentation
- README.md complet
- SETUP.md pour la configuration initiale
- Instructions de déploiement manuel
- Guide de troubleshooting

### 🎯 Fonctionnalités

- ✅ Déploiement multi-environnement (dev/prod)
- ✅ Stockage OCIS sur Azure Blob
- ✅ Authentification OIDC via Keycloak
- ✅ PostgreSQL pour Keycloak dans le cluster
- ✅ SSL/TLS via Azure Key Vault
- ✅ Ingress NGINX avec HTTPS forcé
- ✅ Infrastructure as Code (Terraform)
- ✅ Configuration as Code (Ansible)
- ✅ CI/CD via GitHub Actions

---

## Légende

- ✨ Ajouté : Nouvelles fonctionnalités
- 🔄 Modifié : Modifications de fonctionnalités existantes
- 🐛 Corrigé : Corrections de bugs
- 🔒 Sécurité : Améliorations de sécurité
- 📝 Documentation : Mises à jour de documentation
- 🎯 Améliorations : Améliorations diverses
- ⚠️ Déprécié : Fonctionnalités obsolètes
- 🗑️ Supprimé : Fonctionnalités supprimées
