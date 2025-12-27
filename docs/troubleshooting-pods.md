# Troubleshooting: Pods ne démarrent pas

## Problème
Les pods dans le namespace `owncloud` ne démarrent pas et l'étape "Wait for Deployments" timeout.

## Diagnostic

### 1. Vérifier l'état des pods
```bash
kubectl get pods -n owncloud
```

### 2. Décrire les pods qui ne démarrent pas
```bash
# Lister tous les pods non-Running
kubectl get pods -n owncloud --field-selector=status.phase!=Running

# Décrire un pod spécifique pour voir les erreurs
kubectl describe pod <pod-name> -n owncloud
```

### 3. Vérifier les secrets TLS
```bash
# Lister les secrets
kubectl get secrets -n owncloud

# Vous devriez voir :
# - ocis-tls (type: kubernetes.io/tls)
# - keycloak-tls (type: kubernetes.io/tls)

# Vérifier le contenu d'un secret
kubectl describe secret ocis-tls -n owncloud
```

### 4. Vérifier le SecretProviderClass
```bash
# Lister les SecretProviderClass
kubectl get secretproviderclass -n owncloud

# Décrire pour voir la configuration
kubectl describe secretproviderclass ocis-keyvault-certs -n owncloud
```

### 5. Vérifier le pod de synchronisation
```bash
# Vérifier le pod secrets-sync-pod
kubectl get pod secrets-sync-pod -n owncloud

# Voir les logs
kubectl logs secrets-sync-pod -n owncloud

# Décrire pour voir les events
kubectl describe pod secrets-sync-pod -n owncloud
```

### 6. Vérifier les événements du namespace
```bash
# Voir tous les événements récents
kubectl get events -n owncloud --sort-by='.lastTimestamp'

# Filtrer les warnings et erreurs
kubectl get events -n owncloud --field-selector type=Warning
```

## Solutions courantes

### Problème: Les secrets ne sont pas créés

**Symptôme:**
```
kubectl get secrets -n owncloud
# Manque ocis-tls ou keycloak-tls
```

**Solution:**
1. Vérifier que le CSI Driver est installé :
   ```bash
   kubectl get pods -n kube-system | grep csi-secrets-store
   ```

2. Vérifier les logs du CSI Driver :
   ```bash
   kubectl logs -n kube-system -l app=csi-secrets-store-provider-azure
   ```

3. Forcer la synchronisation en redéployant le pod de sync :
   ```bash
   kubectl delete pod secrets-sync-pod -n owncloud
   kubectl apply -k k8s/overlays/dev
   ```

### Problème: Permission denied sur Key Vault

**Symptôme:**
```
Events:
  Warning  FailedMount  failed to mount secrets store objects for pod: 
  rpc error: code = Unknown desc = failed to mount secrets store objects:
  Azure.ResponseError: Operation returned an invalid status code 'Forbidden'
```

**Solution:**
Vérifier les permissions du Managed Identity :
```bash
# Obtenir l'ID du kubelet identity
KUBELET_IDENTITY=$(az aks show --resource-group owncloud-rg-dev --name owncloud-aks-dev --query identityProfile.kubeletidentity.clientId -o tsv)

# Vérifier les rôles
az role assignment list --assignee $KUBELET_IDENTITY --scope "/subscriptions/<subscription-id>/resourcegroups/owncloud-rg-dev/providers/microsoft.keyvault/vaults/owncloudkvdev"

# Ajouter les permissions si nécessaires
az role assignment create --role "Key Vault Secrets User" --assignee $KUBELET_IDENTITY --scope "/subscriptions/<subscription-id>/resourcegroups/owncloud-rg-dev/providers/microsoft.keyvault/vaults/owncloudkvdev"
```

### Problème: Certificats manquants dans Key Vault

**Symptôme:**
```
Warning  FailedMount  object not found: keycloak-tls-cert
```

**Solution:**
Générer et uploader les certificats :
```powershell
# Sur Windows
.\scripts\create-certificates-simple.ps1 -Environment dev

# Vérifier qu'ils sont bien uploadés
az keyvault certificate list --vault-name owncloudkvdev --output table
az keyvault secret list --vault-name owncloudkvdev --query "[?contains(name, 'tls')]" --output table
```

### Problème: SecretProviderClass mal configuré

**Symptôme:**
```
Error: failed to get keyvaultName
```

**Solution:**
Vérifier que le patch Kustomize est correct :
```bash
# Générer le manifest et vérifier
kustomize build k8s/overlays/dev | grep -A 20 "SecretProviderClass"
```

Les valeurs doivent être renseignées :
- `keyvaultName`: owncloudkvdev
- `tenantId`: adb4b793-234b-4db7-8a27-1eb5a79637e2
- `userAssignedIdentityID`: 15e0ba3e-2f37-4612-985f-fd8525b62b83

### Problème: Ingress sans certificat

**Symptôme:**
L'Ingress est créé mais n'utilise pas les certificats TLS.

**Solution:**
Vérifier la configuration de l'Ingress :
```bash
kubectl describe ingress -n owncloud

# Vérifier que la section TLS référence bien les secrets
kubectl get ingress -n owncloud -o yaml | grep -A 5 "tls:"
```

## Checklist complète

- [ ] Certificats créés dans Key Vault (keycloak-tls-cert, keycloak-tls-key, ocis-tls-cert, ocis-tls-key)
- [ ] CSI Driver installé et running
- [ ] Managed Identity a les permissions sur Key Vault
- [ ] SecretProviderClass configuré avec les bonnes valeurs
- [ ] Pod secrets-sync-pod créé et running
- [ ] Secrets Kubernetes créés (ocis-tls, keycloak-tls)
- [ ] Autres pods peuvent démarrer

## Commandes de redéploiement

Si tout échoue, redéployer complètement :

```bash
# 1. Supprimer le namespace
kubectl delete namespace owncloud

# 2. Attendre que tout soit supprimé
kubectl get namespace owncloud

# 3. Redéployer
kubectl apply -k k8s/overlays/dev

# 4. Surveiller le déploiement
watch kubectl get pods -n owncloud
```

## Logs utiles

```bash
# Logs du CSI Driver
kubectl logs -n kube-system -l app=csi-secrets-store-provider-azure --tail=100

# Logs du pod de sync
kubectl logs secrets-sync-pod -n owncloud

# Events du namespace
kubectl get events -n owncloud --sort-by='.lastTimestamp' | tail -20

# Statut des deployments
kubectl get deployments -n owncloud
kubectl rollout status deployment/<deployment-name> -n owncloud
```

## Ressources supplémentaires

- [Azure Key Vault CSI Driver Troubleshooting](https://azure.github.io/secrets-store-csi-driver-provider-azure/docs/troubleshooting/)
- [Kubernetes Events](https://kubernetes.io/docs/reference/kubectl/cheatsheet/#interacting-with-running-pods)
