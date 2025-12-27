# ✅ Résolution du problème de permissions Key Vault

## Problème rencontré
```
ERROR: (Forbidden) Caller is not authorized to perform action on resource.
Action: 'Microsoft.KeyVault/vaults/certificates/import/action'
```

## Solution appliquée

### 1. Vérification de la configuration du Key Vault
Le Key Vault `owncloudkvdev` utilise **RBAC** (Role-Based Access Control) et non les Access Policies.

### 2. Attribution du rôle nécessaire
Ajout du rôle **Key Vault Administrator** à votre utilisateur :
```powershell
az role assignment create `
  --role "Key Vault Administrator" `
  --assignee "32cad029-773f-4bed-ab80-59906f6ff7f8" `
  --scope "/subscriptions/2f24c81b-6238-4f79-bfd9-4a472fdb702e/resourcegroups/owncloud-rg-dev/providers/microsoft.keyvault/vaults/owncloudkvdev"
```

### 3. Création du script simplifié
Création de `create-certificates-simple.ps1` qui :
- ✅ Génère des certificats SSL auto-signés
- ✅ Crée des fichiers PFX compatibles Azure
- ✅ Upload automatiquement dans Key Vault
- ✅ Gère les erreurs proprement
- ✅ Nettoie les fichiers temporaires

## Résultat

```powershell
.\scripts\create-certificates-simple.ps1 -Environment dev
```

**Sortie :**
```
=== Generation et Upload des Certificats ===
Environnement: dev
Domaine: dev.lesaiglesbraves.online
Key Vault: owncloudkvdev

[1/6] Generation du certificat Keycloak...
[2/6] Generation du certificat OCIS...
[3/6] Creation des fichiers PFX...
[4/6] Upload du certificat Keycloak vers Key Vault...
  OK - Certificat Keycloak uploade
  OK - Cle privee Keycloak uploadee
[5/6] Upload du certificat OCIS vers Key Vault...
  OK - Certificat OCIS uploade
  OK - Cle privee OCIS uploadee
[6/6] Nettoyage des fichiers temporaires...

=== Terminé avec succes! ===

Verification des certificats dans Key Vault:
Name               Enabled
-----------------  ---------
keycloak-tls-cert  True
ocis-tls-cert      True
```

## Certificats créés dans Key Vault

| Nom | Type | Description |
|-----|------|-------------|
| `keycloak-tls-cert` | Certificate | Certificat public Keycloak |
| `keycloak-tls-key` | Secret | Clé privée Keycloak |
| `ocis-tls-cert` | Certificate | Certificat public OCIS |
| `ocis-tls-key` | Secret | Clé privée OCIS |

## Prochaines étapes

1. **Déployer l'infrastructure Terraform** (si pas déjà fait)
   ```powershell
   cd terraform/environments/dev
   terraform init
   terraform plan
   terraform apply
   ```

2. **Configurer kubectl pour AKS**
   ```powershell
   az aks get-credentials --resource-group owncloud-rg-dev --name <cluster-name>
   ```

3. **Déployer avec Ansible**
   ```powershell
   ansible-playbook ansible/deploy.yml -e "target_env=dev"
   ```

## Permissions nécessaires

Pour que le déploiement fonctionne, vous devez avoir :

### Sur Azure
- ✅ **Contributor** sur le Resource Group `owncloud-rg-dev`
- ✅ **Key Vault Administrator** sur le Key Vault `owncloudkvdev`
- ✅ **Azure Kubernetes Service Cluster User Role** sur l'AKS (après création)

### Commande pour vérifier vos rôles
```powershell
az role assignment list --assignee "32cad029-773f-4bed-ab80-59906f6ff7f8" --output table
```

## Résumé des fichiers créés/modifiés

- ✅ `scripts/create-certificates-simple.ps1` - **NOUVEAU** - Script simplifié pour Windows
- ✅ `scripts/manage-certificates.ps1` - Corrigé (encodage et syntaxe)
- ✅ `scripts/README.md` - Mis à jour avec le nouveau script
- ✅ `docs/certificate-deployment-guide.md` - Mis à jour
- ✅ `SOLUTION-TIMEOUT.md` - Mis à jour
- ✅ Permission ajoutée sur `owncloudkvdev`

## Troubleshooting

### Erreur: "Caller is not authorized"
**Solution:** Vérifiez que vous avez le rôle "Key Vault Administrator" sur le Key Vault

### Erreur: "OpenSSL not found"
**Solution:** Le script utilise OpenSSL de Git for Windows automatiquement

### Les certificats n'apparaissent pas dans Key Vault
**Solution:** Attendez 30 secondes pour la propagation des permissions, puis réessayez

## Support

En cas de problème :
1. Vérifiez que vous êtes connecté à Azure : `az account show`
2. Vérifiez vos permissions : `az role assignment list --assignee <your-object-id>`
3. Consultez les logs détaillés en exécutant les commandes az avec `--debug`
