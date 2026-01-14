# Configuration des mots de passe oCIS

Ce document explique comment configurer les mots de passe pour les environnements dev et prod, à la fois pour le déploiement local et le pipeline CI/CD.

## 🔐 Configuration des GitHub Secrets

Pour que le pipeline fonctionne correctement, vous devez configurer deux secrets dans GitHub :

1. **OCIS_ADMIN_PASSWORD_DEV** : Mot de passe admin pour l'environnement dev
2. **OCIS_ADMIN_PASSWORD_PROD** : Mot de passe admin pour l'environnement prod

### Comment ajouter les secrets GitHub :

1. Allez sur votre dépôt GitHub
2. Cliquez sur **Settings** → **Secrets and variables** → **Actions**
3. Cliquez sur **New repository secret**
4. Ajoutez les deux secrets :
   - Name: `OCIS_ADMIN_PASSWORD_DEV`
     Value: `5T3phane` (ou votre mot de passe dev)
   
   - Name: `OCIS_ADMIN_PASSWORD_PROD`
     Value: `5T3phane` (ou votre mot de passe prod)

## 📝 Fichiers kustomization.yaml

Les fichiers `k8s/overlays/{dev,prod}/kustomization.yaml` contiennent maintenant un placeholder `__ADMIN_PASSWORD__` au lieu du mot de passe en clair.

**IMPORTANT** : Ne commitez JAMAIS de mot de passe en clair dans ces fichiers !

## 🚀 Déploiement Local

Pour déployer localement avec un mot de passe spécifique, utilisez le script PowerShell :

```powershell
# Déployer en dev
.\scripts\deploy-with-password.ps1 -Environment dev -AdminPassword "5T3phane"

# Déployer en prod
.\scripts\deploy-with-password.ps1 -Environment prod -AdminPassword "5T3phane"
```

Ce script :
1. Remplace temporairement le placeholder par le mot de passe
2. Applique la configuration avec kubectl
3. Nettoie les fichiers temporaires
4. Vérifie que le mot de passe est correctement configuré

## 🔄 Pipeline CI/CD

Le pipeline GitHub Actions (`.github/workflows/build-and-deploy.yml`) :

1. **Build** : Valide les configurations Terraform, Kubernetes et Ansible
2. **Certificates** : Génère ou vérifie les certificats SSL
3. **Terraform** : Déploie l'infrastructure Azure (AKS, KeyVault, Storage)
4. **Deploy Apps** : 
   - Applique les manifests Kubernetes avec kustomize
   - Récupère le mot de passe depuis les GitHub Secrets
   - Patch le secret Kubernetes avec le bon mot de passe
   - Génère les autres secrets (JWT, transfer, API keys)

### Branches et environnements :

- **develop** → déploie en **dev**
- **main** → déploie en **prod**
- **Pull Requests** → validation seulement (pas de déploiement)

## ⚠️ Sécurité

### ✅ Bonnes pratiques :
- Mots de passe stockés dans GitHub Secrets (chiffrés)
- Placeholder dans les fichiers Git
- Secrets générés automatiquement pour JWT, transfer, etc.

### ❌ À éviter :
- NE JAMAIS commiter de mot de passe en clair
- NE PAS partager les GitHub Secrets
- NE PAS exposer les mots de passe dans les logs

## 🔍 Vérification

Pour vérifier que le mot de passe est correct dans un pod :

```powershell
# Récupérer le nom du pod
$podName = kubectl get pods -n owncloud -o jsonpath='{.items[0].metadata.name}'

# Vérifier les variables d'environnement (ne montre que les noms, pas les valeurs)
kubectl exec -n owncloud $podName -- env | Select-String "ADMIN_PASSWORD"

# Pour voir la valeur réelle (ATTENTION : sensible !)
kubectl get secret -n owncloud -o jsonpath='{.data.admin-password}' $(kubectl get secrets -n owncloud -o name | grep ocis-secret) | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

## 🆘 Dépannage

### Le mot de passe ne fonctionne pas après le déploiement

1. Vérifiez que les GitHub Secrets sont correctement configurés
2. Vérifiez les logs du pipeline pour voir quel mot de passe a été utilisé
3. Supprimez le déploiement et réappliquez :
   ```powershell
   kubectl delete deployment ocis -n owncloud
   .\scripts\deploy-with-password.ps1 -Environment prod -AdminPassword "VotreMotDePasse"
   ```

### Le pipeline génère un mot de passe aléatoire

Cela signifie que les GitHub Secrets ne sont pas configurés. Le pipeline affiche un warning :
```
⚠️ Warning: OCIS_ADMIN_PASSWORD secret not set in GitHub, generating random password
```

Solution : Configurez les secrets GitHub comme expliqué ci-dessus.

### Différence entre dev et prod

Les deux environnements peuvent avoir des mots de passe différents :
- Dev : `OCIS_ADMIN_PASSWORD_DEV`
- Prod : `OCIS_ADMIN_PASSWORD_PROD`

Actuellement, les deux utilisent `5T3phane`, mais vous pouvez les changer indépendamment.
