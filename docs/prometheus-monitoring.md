# Prometheus Monitoring Documentation

## Vue d'ensemble

Prometheus est déployé **uniquement en production** pour surveiller :
- Infrastructure AKS (nœuds, pods, services)
- Application OCIS (métriques applicatives)
- Ressources système (CPU, mémoire, disque, réseau)

## Architecture

Le stack de monitoring inclut :

- **Prometheus** : Collecte et stockage des métriques
- **Grafana** : Visualisation et dashboards
- **Alertmanager** : Gestion des alertes
- **Node Exporter** : Métriques système des nœuds
- **Kube-State-Metrics** : Métriques Kubernetes

## Accès

### Grafana

**URL** : `https://grafana.prod.lesaiglesbraves.online`

**Identifiants par défaut** :
- Username: `admin`
- Password: `5T3phane`

⚠️ **IMPORTANT** : Changez ce mot de passe immédiatement après la première connexion !

### Prometheus

Prometheus n'est pas exposé publiquement par défaut. Pour y accéder :

```bash
# Port-forward vers Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Puis accédez à : `http://localhost:9090`

### Alertmanager

```bash
# Port-forward vers Alertmanager
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
```

Puis accédez à : `http://localhost:9093`

## Métriques collectées

### Métriques OCIS

OCIS expose des métriques Prometheus sur le port 9205 :
- Nombre de requêtes HTTP
- Temps de réponse
- Erreurs applicatives
- Utilisateurs connectés
- Statistiques de stockage

### Métriques Kubernetes

- État des pods (Running, Pending, Failed)
- Utilisation CPU/Mémoire par pod
- État des deployments et statefulsets
- Événements du cluster

### Métriques Infrastructure

- Utilisation CPU par nœud
- Utilisation mémoire par nœud
- Espace disque disponible
- Trafic réseau

## Configuration

### Rétention des données

- **Durée** : 30 jours
- **Taille** : 50 GB maximum
- **Stockage** : Azure Premium Managed Disk (50 GB)

### Intervalle de scraping

- **Défaut** : 30 secondes
- **OCIS** : 30 secondes

### Ressources allouées

**Prometheus** :
- CPU : 500m (request) / 2000m (limit)
- Mémoire : 2Gi (request) / 4Gi (limit)
- Stockage : 50Gi (Premium SSD)

**Grafana** :
- CPU : 100m (request) / 500m (limit)
- Mémoire : 256Mi (request) / 512Mi (limit)
- Stockage : 10Gi (Premium SSD)

**Alertmanager** :
- CPU : 50m (request) / 200m (limit)
- Mémoire : 128Mi (request) / 256Mi (limit)
- Stockage : 10Gi (Premium SSD)

## Dashboards Grafana recommandés

### Dashboards pré-installés

1. **Kubernetes / Compute Resources / Cluster** : Vue d'ensemble du cluster
2. **Kubernetes / Compute Resources / Namespace (Pods)** : Ressources par namespace
3. **Kubernetes / Compute Resources / Pod** : Détails par pod
4. **Node Exporter / Nodes** : Métriques système des nœuds

### Dashboards communautaires à importer

ID des dashboards à importer depuis https://grafana.com/grafana/dashboards/ :

- **13770** : Kubernetes Cluster Monitoring
- **15760** : Kubernetes Views - Global
- **15761** : Kubernetes Views - Namespaces
- **7249** : Kubernetes Cluster Monitoring (Prometheus)

## Alertes recommandées

### Alertes critiques

1. **PodCrashLooping** : Un pod redémarre en boucle
2. **HighMemoryUsage** : Utilisation mémoire > 90%
3. **HighCPUUsage** : Utilisation CPU > 90%
4. **PodNotReady** : Pod non prêt pendant > 5 minutes
5. **DiskSpaceRunningLow** : Espace disque < 10%

### Configuration Alertmanager

Éditez la ConfigMap pour configurer les notifications :

```bash
kubectl edit configmap -n monitoring alertmanager-prometheus-kube-prometheus-alertmanager
```

Exemple de configuration pour envoyer des alertes par email :

```yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alertmanager@lesaiglesbraves.online'
  smtp_auth_username: 'stephane.nzali@gmail.com'
  smtp_auth_password: '5T3ph@ne'

route:
  receiver: 'email-notifications'
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10m
  repeat_interval: 12h

receivers:
  - name: 'email-notifications'
    email_configs:
      - to: 'stephane.nzali@gmail.com'
        headers:
          Subject: '[ALERT] {{ .GroupLabels.alertname }}'
```

## Requêtes PromQL utiles

### Utilisation CPU par pod

```promql
rate(container_cpu_usage_seconds_total{namespace="owncloud"}[5m])
```

### Utilisation mémoire par pod

```promql
container_memory_usage_bytes{namespace="owncloud"}
```

### Requêtes HTTP OCIS

```promql
rate(http_requests_total{job="ocis"}[5m])
```

### Temps de réponse HTTP moyen

```promql
rate(http_request_duration_seconds_sum{job="ocis"}[5m]) / rate(http_request_duration_seconds_count{job="ocis"}[5m])
```

### Pods en erreur

```promql
kube_pod_status_phase{phase="Failed",namespace="owncloud"} > 0
```

## Maintenance

### Changer le mot de passe Grafana

1. Connectez-vous à Grafana
2. Cliquez sur votre profil (icône en haut à gauche)
3. Allez dans "Profile" → "Change Password"

Ou via kubectl :

```bash
kubectl exec -n monitoring deployment/prometheus-grafana -- grafana-cli admin reset-admin-password "NewSecurePassword123!"
```

### Augmenter la rétention

Éditez le fichier `k8s/overlays/prod/prometheus-values.yaml` :

```yaml
prometheus:
  prometheusSpec:
    retention: 60d  # Augmenter à 60 jours
    retentionSize: "100GB"  # Augmenter à 100GB
```

Puis redéployez :

```bash
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f k8s/overlays/prod/prometheus-values.yaml
```

### Augmenter le stockage

```bash
# Augmenter le PVC de Prometheus
kubectl patch pvc -n monitoring prometheus-prometheus-kube-prometheus-prometheus-db-prometheus-kube-prometheus-prometheus-0 -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'
```

### Backup des données

```bash
# Snapshot du PVC Prometheus
kubectl exec -n monitoring prometheus-kube-prometheus-prometheus-0 -- tar czf - /prometheus | gzip > prometheus-backup-$(date +%Y%m%d).tar.gz

# Snapshot du PVC Grafana
kubectl exec -n monitoring deployment/prometheus-grafana -- tar czf - /var/lib/grafana | gzip > grafana-backup-$(date +%Y%m%d).tar.gz
```

## Troubleshooting

### Prometheus ne collecte pas les métriques OCIS

Vérifiez que le ServiceMonitor est créé :

```bash
kubectl get servicemonitor -n monitoring
```

Vérifiez les targets dans Prometheus UI (Status → Targets)

### Grafana ne démarre pas

Vérifiez les logs :

```bash
kubectl logs -n monitoring deployment/prometheus-grafana
```

Vérifiez le PVC :

```bash
kubectl get pvc -n monitoring
```

### Alertmanager ne reçoit pas d'alertes

Vérifiez la configuration :

```bash
kubectl get secret -n monitoring alertmanager-prometheus-kube-prometheus-alertmanager -o yaml
```

Consultez les logs :

```bash
kubectl logs -n monitoring alertmanager-prometheus-kube-prometheus-alertmanager-0
```

## Désinstallation

Pour supprimer complètement Prometheus :

```bash
# Supprimer le Helm release
helm uninstall prometheus -n monitoring

# Supprimer les CRDs
kubectl delete crd prometheuses.monitoring.coreos.com
kubectl delete crd prometheusrules.monitoring.coreos.com
kubectl delete crd servicemonitors.monitoring.coreos.com
kubectl delete crd podmonitors.monitoring.coreos.com
kubectl delete crd alertmanagers.monitoring.coreos.com
kubectl delete crd thanosrulers.monitoring.coreos.com

# Supprimer le namespace
kubectl delete namespace monitoring
```

## Ressources supplémentaires

- [Documentation Prometheus](https://prometheus.io/docs/)
- [Documentation Grafana](https://grafana.com/docs/)
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet/)
