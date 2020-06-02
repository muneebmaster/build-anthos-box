# GKE On-Prem Out-of-the-Box Dashboard

## Overview
The directory is to provide out-of-the-box dashboard to monitor GKE On-Prem Clusters in [cloud monitoring console](https://cloud.google.com/monitoring/charts/dashboards?hl=en).

## Catalog
1. **control-plane-status.json**: availability of apiserver, scheduler, controller manager and etcd
2. **pod-status.json**: memory / cpu / network usage, restart times and pod phase of each component
3. **node-status.json**: cpu usage, allocatable cpu cores, memory usage, allocatable memory and disk usage
4. **cluster-information.json**: node kubernetes version and pod count

## How to create a dashboard in cloud monitoring console

### Before you begin
This method requires the monitoring.dashboards.create permission on the specified project.
1. Enable Cloud Monitoring API in the project
2. If you manage the dashboard via service account, you should grant 'Monitoring Dashboard Configuration Editor'
```
gcloud projects add-iam-policy-binding $PROJECT_ID \
   --member "serviceAccount:$SERVICE_ACCOUNT \
   --role "roles/monitoring.dashboardEditor"
```
### Create a dashboard ([reference](https://cloud.google.com/monitoring/dashboards/api-dashboard?hl=en#creating_a_dashboard))

Here are two ways to create a dashboard.
#### 1. gcloud command
```
gcloud monitoring dashboards create --config-from-file=my-dashboard.json
```
#### 2. Protocol
1. [Authentication](https://cloud.google.com/monitoring/dashboards/api-dashboard?hl=en#examples_using_curl)

2. Post request
```
curl -d @my-dashboard.json -H "Authorization: Bearer $ACCESS_TOKEN" -H 'Content-Type: application/json' -X POST https://monitoring.googleapis.com/v1/projects/${PROJECT_ID}/dashboards
```

## Related doc
[go/onyx-monitoring-best-practices](go/onyx-monitoring-best-practices)