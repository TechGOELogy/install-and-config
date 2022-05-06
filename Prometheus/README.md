## Prometheus Automated Installation
### Ubuntu Server
**Script Location** : `/Prometheus/Ubuntu Server/prometheus-setup.sh`    

**Switches**    
`-l` : Location where Prometheus will be installed. *Default* : `/etc/prometheus`    
`-s` : `true` if SSL should be enabled, should be used along with `-d` for DNS and `-e` for Let's Encrypt Email. *Default* : `false`    
`-d` : Your DNS: *Default* : `localhost`    
`-e` : Email to be used for Let's Encrypt notifications. *Default* : `email@example.com`    
`-u` : Prometheus admin User. *Default* : `admin`    
`-p` : Prometheus admin Password. *Default* : `$RANDOM`    

**Usage**    

Everything Default, No SSL    
`./prometheus-setup.sh`    

Custom prometheus location    
`./prometheus-setup.sh -l /etc/prometheus`    

SSL    
`./prometheus-setup.sh -s true -d your.dns.com -e your@email.com`    

Custome Username and Password    
`./prometheus-setup.sh -u your_user -p your_strong_password`    
    
**Note** : DNS and Email is required if SSL is enabled
