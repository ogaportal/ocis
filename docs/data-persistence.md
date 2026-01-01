# Persistance des Données OCIS

## Problème
Par défaut, OCIS utilisait des volumes éphémères (`emptyDir`) pour stocker les données utilisateurs dans `/var/lib/ocis`. Ces volumes sont supprimés à chaque redéploiement, entraînant la perte de tous les utilisateurs, fichiers et configurations.

## Solution
Configuration d'un **PersistentVolumeClaim (PVC)** pour le stockage des données OCIS.

### Architecture

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ocis-data-pvc
  namespace: owncloud
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  storageClassName: managed-premium  # Azure Premium SSD
```

Le Deployment OCIS monte ce PVC sur `/var/lib/ocis` :

```yaml
volumeMounts:
  - name: data
    mountPath: /var/lib/ocis

volumes:
  - name: data
    persistentVolumeClaim:
      claimName: ocis-data-pvc
```

### Données Persistées

Le PVC conserve toutes les données critiques d'OCIS :
- **Utilisateurs et groupes** (base LDAP interne)
- **Fichiers utilisateurs** (stockage local OCIS)
- **Métadonnées** (permissions, partages, etc.)
- **Configurations** (paramètres de l'application)
- **Tokens et sessions**

### Caractéristiques du Volume

- **Taille** : 50 Gi (configurable selon les besoins)
- **Type** : Azure Premium SSD (`managed-premium`)
- **Mode d'accès** : ReadWriteOnce (un seul pod à la fois)
- **Backup** : Géré par Azure (snapshots disponibles)

## Vérification

Après déploiement, vérifiez que le PVC est bien lié :

```powershell
kubectl get pvc -n owncloud
```

Résultat attendu :
```
NAME              STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
ocis-data-pvc     Bound    pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   50Gi       RWO            managed-premium   10m
```

Vérifiez que le pod OCIS utilise le volume :

```powershell
kubectl describe pod -n owncloud -l app=ocis | Select-String -Pattern "Volumes:" -Context 0,10
```

## Migration de Données Existantes

Si vous aviez déjà créé des utilisateurs avec l'ancien système éphémère, vous devrez les recréer après le passage au PVC persistant. Pour éviter cela à l'avenir :

1. **Sauvegarde régulière** : Créez des snapshots du PVC via Azure
2. **Documentation** : Conservez la liste des utilisateurs et leurs permissions
3. **Automatisation** : Utilisez des scripts pour créer les utilisateurs de base

## Environnements

La même configuration est appliquée pour :
- **Dev** : `ocis-data-pvc` avec `managed-premium`
- **Prod** : `ocis-data-pvc` avec `managed-premium`

## Limitations

- **Un seul replica** : Le mode `ReadWriteOnce` ne permet qu'un seul pod OCIS à la fois
- **Zone unique** : Le volume est lié à une zone de disponibilité Azure spécifique
- **Performance** : Les disques Premium SSD offrent jusqu'à 7500 IOPS

## Alternative : Azure Blob Storage

Pour une solution plus scalable, OCIS peut utiliser Azure Blob Storage :

```yaml
env:
  - name: STORAGE_USERS_DRIVER
    value: "azureblob"
  - name: STORAGE_USERS_AZUREBLOB_ACCOUNT_NAME
    valueFrom:
      secretKeyRef:
        name: azure-storage-secret
        key: account-name
  - name: STORAGE_USERS_AZUREBLOB_ACCOUNT_KEY
    valueFrom:
      secretKeyRef:
        name: azure-storage-secret
        key: account-key
  - name: STORAGE_USERS_AZUREBLOB_CONTAINER_NAME
    value: "ocis-data"
```

Cette option permet :
- **Haute disponibilité** : Données répliquées automatiquement
- **Scalabilité** : Pas de limite de taille fixe
- **Multi-region** : Accès depuis plusieurs régions Azure

## Références

- [OCIS Storage Documentation](https://doc.owncloud.com/ocis/next/deployment/storage/)
- [Kubernetes Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Azure Disk Storage](https://learn.microsoft.com/en-us/azure/aks/concepts-storage)
