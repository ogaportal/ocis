# Guide de contribution

Merci de votre intérêt pour contribuer à ce projet ! Ce document fournit des lignes directrices pour contribuer efficacement.

## 🎯 Types de contributions

- 🐛 Signalement de bugs
- ✨ Proposition de nouvelles fonctionnalités
- 📝 Amélioration de la documentation
- 🔧 Corrections de code
- ⚡ Optimisations de performance

## 🚀 Processus de contribution

### 1. Fork et Clone

```bash
# Fork le repository sur GitHub
# Ensuite clonez votre fork
git clone https://github.com/VOTRE_USERNAME/ocis.git
cd ocis
git checkout -b feature/ma-nouvelle-fonctionnalite
```

### 2. Développement

- Suivez les conventions de code existantes
- Testez vos modifications localement
- Documentez les nouvelles fonctionnalités

### 3. Commit

Utilisez des messages de commit clairs et descriptifs :

```bash
git commit -m "feat: ajout de la gestion automatique des certificats"
git commit -m "fix: correction du problème d'upload Key Vault"
git commit -m "docs: mise à jour du guide de démarrage rapide"
```

**Convention de messages** :
- `feat:` Nouvelle fonctionnalité
- `fix:` Correction de bug
- `docs:` Documentation uniquement
- `style:` Formatage, points-virgules manquants, etc.
- `refactor:` Refactoring de code
- `test:` Ajout de tests
- `chore:` Mise à jour de tâches de build, etc.

### 4. Pull Request

1. Poussez votre branche :
```bash
git push origin feature/ma-nouvelle-fonctionnalite
```

2. Créez une Pull Request sur GitHub
3. Décrivez clairement les changements
4. Référencez les issues liées

## 📋 Checklist PR

Avant de soumettre une Pull Request :

- [ ] Le code suit les conventions du projet
- [ ] Les tests passent (si applicable)
- [ ] La documentation est à jour
- [ ] Le CHANGELOG.md est mis à jour
- [ ] Les commits ont des messages clairs
- [ ] Pas de fichiers sensibles (secrets, clés, etc.)

## 🏗️ Structure du projet

```
.
├── .github/workflows/     # GitHub Actions workflows
├── ansible/              # Playbooks Ansible
├── docs/                 # Documentation
├── k8s/                  # Manifests Kubernetes
│   ├── base/            # Ressources de base
│   └── overlays/        # Overlays par environnement
├── scripts/             # Scripts utilitaires
└── terraform/           # Infrastructure as Code
    ├── modules/         # Modules réutilisables
    └── environments/    # Configurations par environnement
```

## 🛠️ Environnement de développement

### Prérequis

- Terraform >= 1.6.0
- Azure CLI >= 2.50.0
- kubectl >= 1.28.0
- Ansible >= 2.15.0
- Python 3.11+
- PowerShell 7+ (Windows) ou Bash (Linux/Mac)

### Configuration locale

1. **Installer les outils** :
```bash
# Windows (Chocolatey)
choco install terraform azure-cli kubernetes-helm kubectl python

# macOS (Homebrew)
brew install terraform azure-cli kubernetes-helm kubectl python@3.11

# Linux (apt)
sudo apt install terraform azure-cli kubernetes-helm kubectl python3
```

2. **Installer les dépendances Python** :
```bash
pip install ansible kubernetes openshift PyYAML
ansible-galaxy collection install kubernetes.core
ansible-galaxy collection install azure.azcollection
```

3. **Se connecter à Azure** :
```bash
az login
az account set --subscription <SUBSCRIPTION_ID>
```

## 🧪 Tests

### Tester Terraform

```bash
cd terraform/environments/dev
terraform init
terraform validate
terraform plan
```

### Tester Ansible

```bash
cd ansible
ansible-playbook deploy.yml --check -i inventories/hosts -e @inventories/dev.yml -e target_env=dev
```

### Tester les scripts

```bash
# Windows
.\scripts\manage-certificates.ps1 -Environment dev -Action verify

# Linux/Mac
./scripts/manage-certificates.sh dev verify
```

## 📝 Documentation

### Où documenter

- **README.md** : Vue d'ensemble et guide principal
- **SETUP.md** : Configuration pré-déploiement
- **QUICKSTART.md** : Guide de démarrage rapide
- **docs/** : Documentation détaillée par sujet
- **CHANGELOG.md** : Historique des modifications

### Style de documentation

- Utilisez des exemples concrets
- Incluez des commandes copy-paste
- Ajoutez des captures d'écran si pertinent
- Utilisez des emojis pour la lisibilité (avec modération)
- Soyez clair et concis

## 🔒 Sécurité

### Ne commitez JAMAIS

- ❌ Secrets, tokens, mots de passe
- ❌ Clés privées, certificats
- ❌ Fichiers `.tfvars` avec données sensibles
- ❌ Credentials Azure
- ❌ Kubeconfig files

### Bonnes pratiques

- ✅ Utilisez des variables d'environnement
- ✅ Stockez les secrets dans Azure Key Vault
- ✅ Utilisez `.gitignore` correctement
- ✅ Scannez le code avec des outils de sécurité
- ✅ Reviewez les PR pour détecter les secrets

## 🎨 Conventions de code

### Terraform

- Utilisez des noms de variables explicites
- Documentez les variables avec `description`
- Groupez les ressources logiquement
- Utilisez des modules pour la réutilisation

### Ansible

- Nommez clairement les tasks
- Utilisez des variables pour la configuration
- Idempotence obligatoire
- Handlers pour les redémarrages

### Kubernetes

- Utilisez Kustomize pour la configuration
- Labels cohérents sur toutes les ressources
- Resource limits et requests définis
- Namespaces pour l'isolation

### Scripts Shell/PowerShell

- Commentaires pour la logique complexe
- Gestion d'erreurs robuste
- Messages informatifs pour l'utilisateur
- Nettoyage des ressources temporaires

## 🐛 Signalement de bugs

### Template d'issue

```markdown
**Description**
Description claire et concise du bug.

**Comment reproduire**
1. Aller à '...'
2. Cliquer sur '...'
3. Voir l'erreur

**Comportement attendu**
Ce qui devrait se passer.

**Comportement observé**
Ce qui se passe réellement.

**Environnement**
- OS: [ex: Windows 11, Ubuntu 22.04]
- Version Terraform:
- Version Azure CLI:
- Environnement: [dev/prod]

**Logs**
```
Coller les logs pertinents ici
```

**Captures d'écran**
Si applicable.
```

## ✨ Proposition de fonctionnalités

### Template d'issue

```markdown
**Problème à résoudre**
Quel problème cette fonctionnalité résout-elle ?

**Solution proposée**
Comment devrait fonctionner cette nouvelle fonctionnalité ?

**Alternatives considérées**
Quelles autres solutions avez-vous envisagées ?

**Impact**
- Qui bénéficiera de cette fonctionnalité ?
- Y a-t-il des breaking changes ?
```

## 🤝 Code de conduite

- Soyez respectueux et constructif
- Acceptez les critiques constructives
- Concentrez-vous sur ce qui est meilleur pour la communauté
- Montrez de l'empathie envers les autres membres

## 📞 Contact

- Issues GitHub pour les bugs et fonctionnalités
- Discussions GitHub pour les questions
- Pull Requests pour les contributions de code

## 🙏 Remerciements

Merci à tous les contributeurs qui rendent ce projet meilleur !

---

**Happy Contributing! 🎉**
