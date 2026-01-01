#!/usr/bin/env pwsh
# Test Grafana Access Script

Write-Host "=== Testing Grafana Access ===" -ForegroundColor Cyan

# 1. Check pod status
Write-Host "`n1. Checking Grafana Pod Status..." -ForegroundColor Yellow
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# 2. Check service
Write-Host "`n2. Checking Grafana Service..." -ForegroundColor Yellow
kubectl get svc -n monitoring prometheus-grafana

# 3. Check ingress
Write-Host "`n3. Checking Grafana Ingress..." -ForegroundColor Yellow
kubectl get ingress -n monitoring prometheus-grafana

# 4. Check certificate
Write-Host "`n4. Checking Grafana Certificate..." -ForegroundColor Yellow
kubectl get certificate -n monitoring grafana-tls

# 5. Check DNS resolution
Write-Host "`n5. Checking DNS Resolution..." -ForegroundColor Yellow
nslookup grafana.prod.lesaiglesbraves.online

# 6. Test internal health endpoint
Write-Host "`n6. Testing Internal Health Endpoint..." -ForegroundColor Yellow
$podName = kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}'
kubectl exec -n monitoring $podName -- wget -O- -q http://localhost:3000/api/health

# 7. Check recent logs
Write-Host "`n7. Checking Recent Logs..." -ForegroundColor Yellow
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana --tail=10

# 8. Test external access via kubectl port-forward
Write-Host "`n8. Setting up port-forward to test local access..." -ForegroundColor Yellow
Write-Host "Starting port-forward on http://localhost:8080..." -ForegroundColor Green
Write-Host "Press Ctrl+C to stop and continue testing external URL" -ForegroundColor Yellow
kubectl port-forward -n monitoring svc/prometheus-grafana 8080:80
