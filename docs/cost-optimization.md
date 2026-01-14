# Optimisation des Coûts Azure - Gestion des Clusters AKS

## Vue d'ensemble

Ce guide explique comment arrêter et redémarrer les clusters AKS pour réduire les coûts Azure lorsque les environnements ne sont pas utilisés.

## 💰 Impact sur les Coûts

### Clusters en Fonctionnement
- **Dev** : 2 nodes Standard_D2s_v3 → ~$140/mois
- **Prod** : 2 nodes Standard_D2s_v3 → ~$140/mois
- **Total** : ~$280/mois

### Clusters Arrêtés
- Stockage PVCs uniquement → ~$20/mois
- **Économie** : ~$260/mois (~93%)

## 🎯 Quand Arrêter les Clusters

### Bonnes Pratiques
- ✅ **Fin de journée** : Arrêter dev le soir
- ✅ **Week-ends** : Arrêter dev et prod si pas d'utilisation
- ✅ **Vacances** : Arrêter tous les environnements
- ✅ **Démonstrations** : Démarrer uniquement quand nécessaire

### À Éviter
- ❌ Ne pas arrêter prod pendant les heures de travail
- ❌ Ne pas arrêter si des utilisateurs sont actifs
- ❌ Éviter les arrêts/démarrages fréquents (usure des ressources)

## 📋 Utilisation du Script

### Arrêter Tous les Clusters

```powershell
# Arrêter dev et prod ensemble
.\scripts\manage-aks-clusters.ps1 -Action stop-all

# Résultat attendu:
# [owncloud-aks-dev] Stopping Development Environment...
# [owncloud-aks-prod] Stopping Production Environment...
# ✓ Stop command sent successfully
```

### Arrêter un Seul Environnement

```powershell
# Arrêter uniquement dev
.\scripts\manage-aks-clusters.ps1 -Action stop -Environment dev

# Arrêter uniquement prod
.\scripts\manage-aks-clusters.ps1 -Action stop -Environment prod
```

### Démarrer les Clusters

```powershell
# Démarrer tout
.\scripts\manage-aks-clusters.ps1 -Action start-all

# Démarrer uniquement dev
.\scripts\manage-aks-clusters.ps1 -Action start -Environment dev
```

### Vérifier l'État

```powershell
# Statut de tous les clusters
.\scripts\manage-aks-clusters.ps1 -Action status

# Résultat exemple:
# [owncloud-aks-dev] Development Environment → Stopped
# [owncloud-aks-prod] Production Environment → Running
#   Nodes: 2
```

## ⏱️ Temps d'Opération

| Opération | Durée | Notes |
|-----------|-------|-------|
| **Arrêt** | 2-3 minutes | Opération asynchrone |
| **Démarrage** | 5-7 minutes | Les pods redémarrent automatiquement |
| **Pods prêts** | 8-10 minutes | Services accessibles |

## 🔒 Données Persistantes

### ✅ Ce qui est Conservé
- **PVCs** : Tous les volumes persistants (ocis-data-pvc, etc.)
- **Utilisateurs OCIS** : Base de données LDAP
- **Fichiers** : Stockage utilisateur
- **Configurations** : ConfigMaps et Secrets
- **Certificats** : Azure Key Vault

### ❌ Ce qui est Perdu
- **Pods en mémoire** : État des applications (normal)
- **Connexions actives** : Sessions utilisateurs (ils devront se reconnecter)
- **Caches temporaires** : Reconstruits au démarrage

## 🚀 Procédure Complète

### Fin de Journée (Dev)

```powershell
# 1. Vérifier qu'aucun utilisateur n'est connecté
.\scripts\manage-aks-clusters.ps1 -Action status

# 2. Arrêter dev
.\scripts\manage-aks-clusters.ps1 -Action stop -Environment dev

# 3. Vérifier l'arrêt (après 3 minutes)
.\scripts\manage-aks-clusters.ps1 -Action status
```

### Début de Journée (Dev)

```powershell
# 1. Démarrer dev
.\scripts\manage-aks-clusters.ps1 -Action start -Environment dev

# 2. Attendre 7 minutes
Start-Sleep -Seconds 420

# 3. Vérifier que tout est prêt
kubectl get pods -A

# 4. Tester l'accès
# https://dev.lesaiglesbraves.online
```

### Week-end (Tout Arrêter)

```powershell
# Vendredi soir
.\scripts\manage-aks-clusters.ps1 -Action stop-all

# Lundi matin
.\scripts\manage-aks-clusters.ps1 -Action start-all
```

## 🔍 Surveillance et Dépannage

### Vérifier l'État d'Arrêt

```powershell
# Via le script
.\scripts\manage-aks-clusters.ps1 -Action status

# Via Azure CLI directement
az aks show -g owncloud-rg-dev -n owncloud-aks-dev --query powerState
```

### Logs des Opérations

```powershell
# Voir l'activité Azure
az monitor activity-log list --resource-group owncloud-rg-dev --max-events 10

# Filtrer par AKS
az monitor activity-log list --resource-group owncloud-rg-dev --max-events 50 | ConvertFrom-Json | Where-Object { $_.resourceType -eq "Microsoft.ContainerService/managedClusters" }
```

### Problèmes Courants

#### Le cluster ne démarre pas

```powershell
# Vérifier les quotas Azure
az vm list-usage --location eastus

# Forcer le démarrage
az aks start -g owncloud-rg-dev -n owncloud-aks-dev
```

#### Les pods ne démarrent pas après start

```powershell
# Se connecter au cluster
az aks get-credentials -g owncloud-rg-dev -n owncloud-aks-dev --overwrite-existing

# Vérifier les nodes
kubectl get nodes

# Vérifier les pods
kubectl get pods -A

# Redéployer si nécessaire
kubectl delete pod -n owncloud -l app=ocis
```

## 💡 Optimisations Avancées

### Automatisation avec Azure Automation

Vous pouvez automatiser les arrêts/démarrages avec Azure Automation :

```powershell
# Créer un Automation Account
az automation account create \
  --resource-group owncloud-rg-dev \
  --name owncloud-automation \
  --location eastus

# Créer un runbook pour arrêt automatique à 19h
# (voir documentation Azure Automation)
```

### Alertes de Coût

```powershell
# Configurer une alerte si le coût dépasse $300/mois
az monitor metrics alert create \
  --name aks-cost-alert \
  --resource-group owncloud-rg-dev \
  --scopes "/subscriptions/YOUR_SUBSCRIPTION_ID" \
  --condition "total cost > 300"
```

### Scheduled Scaling (Alternative)

Si l'arrêt complet est trop contraignant, vous pouvez utiliser le scaling :

```powershell
# Réduire à 1 node le soir
az aks nodepool scale \
  --resource-group owncloud-rg-dev \
  --cluster-name owncloud-aks-dev \
  --name default \
  --node-count 1

# Augmenter à 2 nodes le matin
az aks nodepool scale \
  --resource-group owncloud-rg-dev \
  --cluster-name owncloud-aks-dev \
  --name default \
  --node-count 2
```

## 📊 Tableau de Bord des Coûts

### Estimation Mensuelle

| Scénario | Dev | Prod | Total | Économie |
|----------|-----|------|-------|----------|
| 24/7 | $140 | $140 | $280 | - |
| Dev arrêté la nuit (12h/j) | $70 | $140 | $210 | 25% |
| Dev arrêté nuit + weekend | $42 | $140 | $182 | 35% |
| Tout arrêté la nuit | $70 | $70 | $140 | 50% |
| Tout arrêté hors heures travail | $42 | $42 | $84 | 70% |
| Arrêt complet | $10 | $10 | $20 | 93% |

### Calcul Réel

```powershell
# Voir les coûts réels dans Azure
az consumption usage list \
  --start-date 2026-01-01 \
  --end-date 2026-01-31 \
  --query "[?contains(instanceId, 'aks')].{Service:meterName, Cost:pretaxCost}"
```

## 🎓 Bonnes Pratiques

1. **Communication** : Prévenez l'équipe avant d'arrêter prod
2. **Backup** : Faites un backup avant arrêt prolongé
3. **Documentation** : Notez les horaires d'arrêt/démarrage
4. **Monitoring** : Surveillez les coûts régulièrement
5. **Tests** : Testez la procédure en dev avant prod

## 📚 Références

- [Azure AKS Pricing](https://azure.microsoft.com/pricing/details/kubernetes-service/)
- [Stop/Start AKS Clusters](https://learn.microsoft.com/azure/aks/start-stop-cluster)
- [Azure Cost Management](https://learn.microsoft.com/azure/cost-management-billing/)

## 🆘 Support

En cas de problème :

1. Vérifier les logs : `az monitor activity-log list`
2. Contacter le support Azure si cluster bloqué
3. Backup de secours disponible dans `scripts/backup-ocis-users.ps1`
