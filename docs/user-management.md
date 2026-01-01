# Guide de Gestion des Utilisateurs OCIS

## Situation Actuelle

**Environnement Dev** : Le PVC persistant `ocis-data-pvc` vient d'être créé et est vide.  
**Environnement Prod** : Le PVC persistant `ocis-data-pvc` est configuré.

⚠️ **Important** : Les utilisateurs créés avant la mise en place du PVC ont été perdus car ils étaient sur des volumes éphémères.

## À Partir de Maintenant

✅ Tous les nouveaux utilisateurs créés seront **conservés automatiquement** grâce au PVC.

## Créer des Utilisateurs OCIS

### Option 1 : Via l'Interface Web

1. Connectez-vous à OCIS avec le compte admin :
   - **Dev** : https://dev.lesaiglesbraves.online
   - **Prod** : https://prod.lesaiglesbraves.online
   - Login : `admin` / Mot de passe : voir les secrets

2. Allez dans **Settings** → **Users** → **Create User**

### Option 2 : Via l'API Graph

```powershell
# Environnement
$Environment = "dev"  # ou "prod"
$OCIS_URL = "https://$Environment.lesaiglesbraves.online"

# Se connecter au cluster
if ($Environment -eq "prod") {
    az aks get-credentials --resource-group owncloud-rg-prod --name owncloud-aks-prod --overwrite-existing
} else {
    az aks get-credentials --resource-group owncloud-rg-dev --name owncloud-aks-dev --overwrite-existing
}

# Récupérer le mot de passe admin
$ADMIN_PASSWORD = kubectl get secret -n owncloud ocis-secret-2mdbdhk457 -o jsonpath="{.data.admin-password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# Créer un utilisateur via API (depuis un pod dans le cluster)
$podName = kubectl get pod -n owncloud -l app=ocis -o jsonpath="{.items[0].metadata.name}"

kubectl exec -n owncloud $podName -- sh -c @"
curl -X POST 'http://localhost:9200/graph/v1.0/users' \
  -H 'Content-Type: application/json' \
  -u 'admin:$ADMIN_PASSWORD' \
  -d '{
    \"displayName\": \"Nom Utilisateur\",
    \"mail\": \"utilisateur@example.com\",
    \"onPremisesSamAccountName\": \"username\",
    \"passwordProfile\": {
      \"password\": \"MotDePasse123!\"
    }
  }'
"@
```

### Option 3 : Via ligne de commande OCIS

```powershell
# Se connecter au pod OCIS
$podName = kubectl get pod -n owncloud -l app=ocis -o jsonpath="{.items[0].metadata.name}"

# Créer un utilisateur
kubectl exec -it -n owncloud $podName -- ocis user create --displayname "Nom Utilisateur" --username username --email user@example.com --password "MotDePasse123!"
```

## Sauvegarder les Utilisateurs

### Backup Complet

```powershell
# Créer un backup
.\scripts\backup-ocis-users.ps1 -Environment dev -Action backup

# Résultat : ocis-backup-dev-YYYYMMDD_HHMMSS.tar.gz
```

### Restaurer depuis un Backup

```powershell
# Restaurer un backup
.\scripts\backup-ocis-users.ps1 -Environment dev -Action restore -BackupFile ocis-backup-dev-20260101_230000.tar.gz

# Redémarrer le pod après restore
kubectl delete pod -n owncloud -l app=ocis
```

## Lister les Utilisateurs Actuels

### Via API

```powershell
$Environment = "dev"  # ou "prod"
$podName = kubectl get pod -n owncloud -l app=ocis -o jsonpath="{.items[0].metadata.name}"

kubectl exec -n owncloud $podName -- sh -c "curl -s http://localhost:9200/graph/v1.0/users -u 'admin:PASSWORD' | jq '.value[] | {displayName, userPrincipalName, mail}'"
```

### Via logs

```powershell
kubectl logs -n owncloud -l app=ocis | Select-String "user"
```

## Vérifier l'Espace de Stockage

```powershell
.\scripts\backup-ocis-users.ps1 -Environment dev -Action list
```

## Snapshots Azure (Recommandé)

Pour une protection supplémentaire, créez des snapshots réguliers du PVC via Azure :

```powershell
# Lister les PVs
kubectl get pv

# Noter le nom du disque Azure
$diskId = kubectl get pv <pv-name> -o jsonpath="{.spec.azureDisk.diskURI}"

# Créer un snapshot via Azure CLI
az snapshot create \
  --resource-group owncloud-rg-dev \
  --name ocis-snapshot-$(Get-Date -Format "yyyyMMdd") \
  --source $diskId
```

## Bonnes Pratiques

1. **Backup Régulier** : Faites un backup avant chaque modification importante
   ```powershell
   .\scripts\backup-ocis-users.ps1 -Environment dev -Action backup
   ```

2. **Nommage Cohérent** : Utilisez des conventions de nommage claires pour les utilisateurs

3. **Snapshots Automatisés** : Configurez des snapshots Azure hebdomadaires

4. **Test de Restauration** : Testez régulièrement la restauration en dev

5. **Documentation** : Conservez une liste des utilisateurs et leurs rôles

## Migration de Données

Si vous avez besoin de migrer des données d'un environnement à un autre :

```powershell
# 1. Backup depuis prod
.\scripts\backup-ocis-users.ps1 -Environment prod -Action backup -BackupFile prod-to-dev.tar.gz

# 2. Restore vers dev
.\scripts\backup-ocis-users.ps1 -Environment dev -Action restore -BackupFile prod-to-dev.tar.gz
```

## Dépannage

### Les utilisateurs n'apparaissent pas

```powershell
# Vérifier le pod
kubectl get pods -n owncloud

# Vérifier les logs
kubectl logs -n owncloud -l app=ocis --tail=100

# Vérifier le PVC
kubectl get pvc -n owncloud ocis-data-pvc
```

### Le PVC est plein

```powershell
# Vérifier l'utilisation
kubectl exec -n owncloud $(kubectl get pod -n owncloud -l app=ocis -o jsonpath="{.items[0].metadata.name}") -- df -h /var/lib/ocis

# Augmenter la taille du PVC (si nécessaire)
kubectl patch pvc ocis-data-pvc -n owncloud -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'
```

## Références

- Documentation OCIS : https://doc.owncloud.com/ocis/
- Graph API : https://owncloud.dev/apis/http/graph/
- PVC Kubernetes : https://kubernetes.io/docs/concepts/storage/persistent-volumes/
