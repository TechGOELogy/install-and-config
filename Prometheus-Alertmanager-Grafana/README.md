## Prometheus Alertmanager Grafana Automated Installation
### Windows Server
**Script Location** : `/Prometheus-Alertmanager-Grafana/Windows Server/pga-setup.ps1`    

**Switches**    
`-PGAPath` : Location where stack will be installed.    
`-SSL` : Add this switch to enable HTTPS (DNS and Email are mandatory id SSL is supplied)    
`-DNS` : Your DNS: *Default* : `localhost`    
`-Email` : Email to be used for Let's Encrypt notifications. *Default* : `email@example.com`    
`-AdminUsername` : Prometheus and Alertmanager admin User. *Default* : `admin`    
`-AdminPassword` : Prometheus and Alertmanager admin Password. *Default* : `$(Get-Random)`    
`-PrometheusDownloadURL` : Prometheus Windows zip URL. *Default* : `https://github.com/prometheus/prometheus/releases/download/v2.37.0-rc.1/prometheus-2.37.0-rc.1.windows-amd64.zip`    
`-GrafanaDownloadURL` : Grafana Windows zip URL. *Default* : `https://dl.grafana.com/oss/release/grafana-9.0.4.windows-amd64.zip`    
`-AlertManagerDownloadURL` : Grafana Windows zip URL. *Default* : `https://github.com/prometheus/alertmanager/releases/download/v0.24.0/alertmanager-0.24.0.windows-amd64.zip`    

**Usage**    

Everything Default, No SSL    
`./pga-setup.ps1 -PGAPath C:\PGA`    

SSL    
`./pga-setup.ps1 -SSL -DNS your.dns.com -Email your@email.com`    

Custome Username and Password (Only for Prometheus and Alertmanager. FOr Grafana only default username and passwords are available as admin, admin which can be changed on first login)    
`./pga-setup.ps1 -AdminUsername your_user -AdminUsername your_strong_password`    

**Note** : DNS and Email is required if SSL is enabled
