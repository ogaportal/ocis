# Guide : Génération de certificats en local et déploiement

## Contexte
Le problème de timeout avec cert-manager a été résolu en passant à une approche où les certificats sont générés localement et uploadés dans Azure Key Vault, puis synchronisés automatiquement dans Kubernetes via le CSI Driver.

## Modifications apportées

### 1. Déploiement Ansible ([deploy.yml](ansible/deploy.yml))
- ✅ Suppression de l'installation de cert-manager
- ✅ Suppression du repository Helm jetstack
- ✅ Suppression des étapes d'attente de génération de certificats
- ✅ Ajout d'une vérification de la synchronisation des secrets depuis Key Vault

### 2. Configuration Kubernetes
- ✅ Nouveau fichier [certificates-keyvault.yaml](k8s/base/certificates-keyvault.yaml) pour récupérer les certificats depuis Azure Key Vault
- ✅ Mise à jour de [kustomization.yaml](k8s/base/kustomization.yaml) pour utiliser le nouveau fichier
- ✅ Sauvegarde de l'ancienne configuration cert-manager dans `certificates.yaml.bak`

### 3. Configuration par environnement
- ✅ Mise à jour des patches Kustomize pour cibler le nouveau SecretProviderClass

## 🚀 Procédure de déploiement

### Étape 1 : Générer les certificats localement

**Sur Windows (PowerShell) - RECOMMANDÉ :**
```powershell
# Se placer dans le dossier du projet
cd d:\source\ocis

# Utiliser le script simplifié (plus fiable)
.\scripts\create-certificates-simple.ps1 -Environment dev

# Ou pour production
.\scripts\create-certificates-simple.ps1 -Environment prod
```

**Alternative - Script complet (Windows PowerShell) :**
```powershell
# Générer et uploader les certificats pour dev
.\scripts\manage-certificates.ps1 -Environment dev -Action create

# Ou pour production
.\scripts\manage-certificates.ps1 -Environment prod -Action create
```

**Sur Linux/Mac (Bash) :**
```bash
# Se placer dans le dossier du projet
cd /path/to/ocis

# Générer et uploader les certificats pour dev
./scripts/manage-certificates.sh dev create

# Ou pour production
./scripts/manage-certificates.sh prod create
```

**Cette commande va :**
1. ✅ Générer des certificats SSL/TLS auto-signés (valides 365 jours)
2. ✅ Créer les certificats pour Keycloak et OCIS
3. ✅ Les uploader automatiquement dans Azure Key Vault
4. ✅ Nettoyer les fichiers temporaires locaux

### Étape 2 : Vérifier que les certificats sont dans Key Vault

```powershell
# Vérifier les certificats
.\scripts\manage-certificates.ps1 -Environment dev -Action verify
```

Vous devriez voir :
- `keycloak-tls-cert` (certificat)
- `keycloak-tls-key` (secret)
- `ocis-tls-cert` (certificat)
- `ocis-tls-key` (secret)

### Étape 3 : Déployer avec Ansible

Le pipeline GitHub Actions ou Ansible va maintenant :

1. ✅ Installer le CSI Driver pour Azure Key Vault
2. ✅ Déployer le `SecretProviderClass` qui référence les certificats dans Key Vault
3. ✅ Créer un pod temporaire qui monte le CSI volume
4. ✅ Synchroniser automatiquement les certificats dans des secrets Kubernetes :
   - `ocis-tls` (secret type kubernetes.io/tls)
   - `keycloak-tls` (secret type kubernetes.io/tls)
5. ✅ Les Ingress utilisent ces secrets pour le TLS

```powershell
# Déploiement via Ansible
ansible-playbook ansible/deploy.yml -e "target_env=dev"
```

## 📋 Workflow GitHub Actions

Le workflow [.github/workflows/deploy.yml](.github/workflows/deploy.yml) gère déjà automatiquement :
1. ✅ Vérification de l'existence des certificats dans Key Vault
2. ✅ Génération automatique s'ils n'existent pas
3. ✅ Upload vers Key Vault
4. ✅ Déploiement Terraform
5. ✅ Déploiement Ansible

**Pour déclencher le workflow :**
- Aller sur GitHub → Actions → Deploy Infrastructure and Applications
- Choisir l'environnement (dev/prod)
- Choisir l'action (deploy)
- Lancer le workflow

## 🔍 Vérification post-déploiement

### Vérifier que les secrets existent dans Kubernetes :
```bash
kubectl get secrets -n owncloud
```

Vous devriez voir :
```
NAME           TYPE                DATA   AGE
ocis-tls       kubernetes.io/tls   2      5m
keycloak-tls   kubernetes.io/tls   2      5m
```

### Vérifier le contenu des secrets :
```bash
kubectl describe secret ocis-tls -n owncloud
kubectl describe secret keycloak-tls -n owncloud
```

### Vérifier les Ingress :
```bash
kubectl get ingress -n owncloud
kubectl describe ingress -n owncloud
```

## 🔄 Renouvellement des certificats

Les certificats auto-signés sont valides **365 jours**. Pour les renouveler :

```powershell
# Supprimer les anciens certificats
.\scripts\manage-certificates.ps1 -Environment dev -Action delete

# Régénérer de nouveaux certificats
.\scripts\manage-certificates.ps1 -Environment dev -Action create

# Redémarrer le pod de synchronisation pour forcer la mise à jour
kubectl delete pod secrets-sync-pod -n owncloud
kubectl apply -k k8s/overlays/dev
```

## ⚠️ Troubleshooting

### Les secrets ne sont pas créés dans Kubernetes

**Vérifier le SecretProviderClass :**
```bash
kubectl get secretproviderclass -n owncloud
kubectl describe secretproviderclass ocis-keyvault-certs -n owncloud
```

**Vérifier les logs du CSI Driver :**
```bash
kubectl logs -n kube-system -l app=csi-secrets-store-provider-azure
```

**Vérifier les permissions du Managed Identity :**
- Le Managed Identity AKS doit avoir les permissions `get` et `list` sur les secrets et certificats du Key Vault

### Le pod secrets-sync-pod est en erreur

```bash
# Voir les événements
kubectl describe pod secrets-sync-pod -n owncloud

# Voir les logs
kubectl logs secrets-sync-pod -n owncloud
```

### Certificats expirés

```bash
# Vérifier la date d'expiration
openssl x509 -in <(kubectl get secret ocis-tls -n owncloud -o jsonpath='{.data.tls\.crt}' | base64 -d) -noout -dates
```

## 📚 Ressources

- [Script PowerShell](scripts/manage-certificates.ps1)
- [Script Bash](scripts/manage-certificates.sh)
- [Documentation des scripts](scripts/README.md)
- [Azure Key Vault CSI Driver](https://azure.github.io/secrets-store-csi-driver-provider-azure/)

## 🎯 Avantages de cette approche

✅ **Plus de timeout** - Les certificats sont créés à l'avance  
✅ **Contrôle total** - Vous générez et gérez vos propres certificats  
✅ **Sécurité** - Les certificats sont stockés dans Azure Key Vault  
✅ **Automatisation** - Le CSI Driver synchronise automatiquement les certificats  
✅ **Simplicité** - Pas besoin de cert-manager et de ses dépendances  
✅ **Pipeline CI/CD** - S'intègre parfaitement dans GitHub Actions
