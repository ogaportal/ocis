# Configuration des mots de passe oCIS

Ce document explique comment configurer les mots de passe pour les environnements dev et prod, à la fois pour le déploiement local et le pipeline CI/CD.

## 🔐 Configuration des GitHub Secrets (OBLIGATOIRE pour le pipeline)

Pour que le pipeline fonctionne correctement, vous devez configurer deux secrets dans GitHub :

1. **OCIS_ADMIN_PASSWORD_DEV** : Mot de passe admin pour l'environnement dev
2. **OCIS_ADMIN_PASSWORD_PROD** : Mot de passe admin pour l'environnement prod

### Comment ajouter les secrets GitHub :

1. Allez sur votre dépôt GitHub
2. Cliquez sur **Settings** → **Secrets and variables** → Actions**
3. Cliquez sur **New repository secret**
4. Ajoutez les deux secrets :
   - Name: `OCIS_ADMIN_PASSWORD_DEV`
     Value: `5T3phane` (ou votre mot de passe dev)
   
   - Name: `OCIS_ADMIN_PASSWORD_PROD`
     Value: `5T3phane` (ou votre mot de passe prod)

**IMPORTANT** : Sans ces secrets, le pipeline échouera avec l'erreur :
```
❌ Error: OCIS_ADMIN_PASSWORD_XXX secret not set in GitHub!
```

## 📝 Fichiers kustomization.yaml

Les fichiers `k8s/overlays/{dev,prod}/kustomization.yaml` contiennent un placeholder `__ADMIN_PASSWORD__` :

```yaml
secretGenerator:
  - name: ocis-secret
    behavior: merge
    literals:
      - admin-password=__ADMIN_PASSWORD__  # ← Placeholder
      - admin-email=stephane.nzali@gmail.com
```

**IMPORTANT** : 
- ❌ Ne JAMAIS remplacer manuellement ce placeholder dans Git
- ❌ Ne JAMAIS commiter de mot de passe en clair
- ✅ Le placeholder est remplacé automatiquement au déploiement

## 🚀 Déploiement Local

Pour déployer localement avec un mot de passe spécifique, utilisez le script PowerShell :

```powershell
# Déployer en dev
.\scripts\deploy-with-password.ps1 -Environment dev -AdminPassword "5T3phane"

# Déployer en prod
.\scripts\deploy-with-password.ps1 -Environment prod -AdminPassword "5T3phane"
```

**Ce script :**
1. Remplace temporairement `__ADMIN_PASSWORD__` par le mot de passe réel
2. Supprime le deployment existant
3. Applique la configuration avec kubectl
4. Nettoie les fichiers temporaires
5. Vérifie que le mot de passe est correctement configuré

**⚠️ N'utilisez JAMAIS `kubectl apply -k` directement** - utilisez toujours le script !

## 🔄 Pipeline CI/CD

Le pipeline GitHub Actions (`.github/workflows/build-and-deploy.yml`) fonctionne ainsi :

### Étapes du pipeline :

1. **Build** : Valide les configurations Terraform, Kubernetes et Ansible
2. **Certificates** : Génère ou vérifie les certificats SSL
3. **Terraform** : Déploie l'infrastructure Azure (AKS, KeyVault, Storage)
4. **Deploy Apps** : 
   - Récupère le mot de passe depuis les GitHub Secrets (`OCIS_ADMIN_PASSWORD_DEV` ou `PROD`)
   - Crée un répertoire temporaire `k8s/overlays/{env}-temp`
   - Remplace `__ADMIN_PASSWORD__` par le vrai mot de passe
   - Supprime le deployment existant
   - Applique `kubectl apply -k` sur le répertoire temporaire
   - Nettoie le répertoire temporaire
   - Attend que le pod soit prêt
   - Génère les autres secrets (JWT, API keys) s'ils n'existent pas

### Branches et environnements :

- **develop** → déploie en **dev** avec `OCIS_ADMIN_PASSWORD_DEV`
- **main** → déploie en **prod** avec `OCIS_ADMIN_PASSWORD_PROD`
- **Pull Requests** → validation seulement (pas de déploiement)

### Sécurité du pipeline :

✅ **Ce qui est sécurisé :**
- Mots de passe stockés dans GitHub Secrets (chiffrés par GitHub)
- Placeholder dans les fichiers Git (pas de mot de passe en clair)
- Remplacement du placeholder AVANT le déploiement
- Répertoire temporaire supprimé après le déploiement
- Secrets JWT/API générés automatiquement

❌ **Si le secret GitHub n'est pas configuré :**
- Le pipeline échouera immédiatement
- Message d'erreur clair indiquant le problème
- Pas de déploiement avec des valeurs par défaut dangereuses

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
