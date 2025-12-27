# 🎯 Solution au problème de timeout cert-manager

## Problème résolu ✅
**"Wait for cert-manager to generate certificates" → TIMEOUT**

## Solution implémentée

### 1️⃣ Générer les certificats LOCALEMENT
```powershell
.\scripts\manage-certificates.ps1 -Environment dev -Action create
```
Cette commande :
- ✅ Génère des certificats SSL auto-signés
- ✅ Les upload automatiquement dans Azure Key Vault
- ✅ Nettoie les fichiers temporaires

### 2️⃣ Le pipeline COPIE automatiquement depuis Key Vault
Le déploiement Ansible utilise maintenant le **CSI Driver** qui :
- ✅ Récupère les certificats depuis Azure Key Vault
- ✅ Les synchronise dans des secrets Kubernetes
- ✅ Les rend disponibles pour les Ingress
- ✅ **Aucun timeout** car les certificats existent déjà !

## Modifications effectuées

### Fichiers modifiés :
- ✅ `ansible/deploy.yml` - Suppression de cert-manager, ajout de la synchronisation Key Vault
- ✅ `k8s/base/certificates-keyvault.yaml` - Nouveau fichier pour le CSI Driver
- ✅ `k8s/base/kustomization.yaml` - Utilise le nouveau fichier de certificats
- ✅ `k8s/overlays/dev/kustomization.yaml` - Patches mis à jour

### Documentation ajoutée :
- 📄 `docs/certificate-deployment-guide.md` - Guide complet
- 📄 `CHANGELOG.md` - Historique des modifications

## Déploiement rapide

```powershell
# 1. Générer les certificats (1 fois seulement)
.\scripts\create-certificates-simple.ps1 -Environment dev

# 2. Vérifier qu'ils sont dans Key Vault
.\scripts\manage-certificates.ps1 -Environment dev -Action verify

# 3. Déployer normalement
ansible-playbook ansible/deploy.yml -e "target_env=dev"
```

## Vérification

```bash
# Vérifier les secrets dans Kubernetes
kubectl get secrets -n owncloud

# Vous devriez voir :
# ocis-tls       kubernetes.io/tls   2      5m
# keycloak-tls   kubernetes.io/tls   2      5m
```

## 📚 Documentation complète
👉 [docs/certificate-deployment-guide.md](docs/certificate-deployment-guide.md)

## Workflow GitHub Actions
Le workflow `.github/workflows/deploy.yml` gère déjà tout automatiquement :
1. Vérifie si les certificats existent dans Key Vault
2. Les génère si nécessaire
3. Les upload
4. Déploie l'infrastructure et les applications

**Plus de timeout ! 🎉**
