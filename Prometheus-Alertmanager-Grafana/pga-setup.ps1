param (
    [Parameter(Mandatory=$true)]$PGAPath,
    [Switch]$SSL,
    $DNS="localhost",
    [MailAddress]$Email="email@example.com",
    $AdminUsername="admin",
    $Adminpassword=$(Get-Random),
    $PrometheusDownloadURL = "https://github.com/prometheus/prometheus/releases/download/v2.37.0-rc.1/prometheus-2.37.0-rc.1.windows-amd64.zip",
    $GrafanaDownloadURL = "https://dl.grafana.com/oss/release/grafana-9.0.4.windows-amd64.zip",
    $AlertManagerDownloadURL = "https://github.com/prometheus/alertmanager/releases/download/v0.24.0/alertmanager-0.24.0.windows-amd64.zip"
)

try {

    $WinACEMDownloadURL = "https://github.com/win-acme/win-acme/releases/download/v2.1.22.1267/win-acme.v2.1.22.1267.x64.trimmed.zip"
    $NSSMDownloadURL = "https://nssm.cc/ci/nssm-2.24-103-gdee49fc.zip"

    if($SSL) {
        if($DNS -eq "" -or $DNS.Equals("localhost")) {
            Write-Host "Please provide a valid DNS with -DNS when SSL is true."
            Exit 1
        }
    }

    if(-not (Test-Path $PGAPath)) {
        New-Item -ItemType Directory -Path $PGAPath -Force
    }
    else {
        Write-Host "$PGAPath already exists"
        exit 1
    }

    Write-Host "Downloading Prometheus..."
    Start-BitsTransfer $PrometheusDownloadURL -Destination $PGAPath\prometheus.zip
    Write-Host "Downloading Grafana..."
    Start-BitsTransfer $GrafanaDownloadURL -Destination $PGAPath\grafana.zip
    Write-Host "Downloading AlertManager..."
    Start-BitsTransfer $AlertManagerDownloadURL -Destination $PGAPath\alertmanager.zip
    Write-Host "Downloading Win ACME..."
    Start-BitsTransfer $WinACEMDownloadURL -Destination $PGAPath\wacs.zip
    Write-Host "Downloading NSSM..."
    Start-BitsTransfer $NSSMDownloadURL -Destination $PGAPath\nssm.zip

    Write-Host "Extracting Prometheus..."
    Expand-Archive "$PGAPath\prometheus.zip" -DestinationPath $PGAPath
    Get-ChildItem $PGAPath -Filter 'prometheus-*' | Rename-Item -NewName "prometheus"
    Remove-Item "$PGAPath\prometheus.zip" -Force
    Write-Host "Extracting Grafana..."
    Expand-Archive "$PGAPath\grafana.zip" -DestinationPath $PGAPath
    Get-ChildItem $PGAPath -Filter 'grafana-*' | Rename-Item -NewName "grafana"
    Remove-Item "$PGAPath\grafana.zip" -Force
    Write-Host "Extracting Alertmanager..."
    Expand-Archive "$PGAPath\alertmanager.zip" -DestinationPath $PGAPath
    Get-ChildItem $PGAPath -Filter 'alertmanager-*' | Rename-Item -NewName "alertmanager"
    Remove-Item "$PGAPath\alertmanager.zip" -Force
    Write-Host "Extracting Win ACME..."
    Expand-Archive "$PGAPath\wacs.zip" -DestinationPath $PGAPath\wacs
    Remove-Item "$PGAPath\wacs.zip" -Force
    Write-Host "Extracting NSSM..."
    Expand-Archive "$PGAPath\nssm.zip" -DestinationPath $PGAPath
    Get-ChildItem $PGAPath -Filter 'nssm-*' | Rename-Item -NewName "nssm"
    Remove-Item "$PGAPath\nssm.zip" -Force

    $BcryptPassword = $(Invoke-RestMethod https://www.toptal.com/developers/bcrypt/api/generate-hash.json -Body "password=$AdminPassword&cost=10" -Method Post).hash
    $WebConfig = 'basic_auth_users:
        ' + $AdminUsername + ': ' + $BcryptPassword + ''
    $GrafanaIni = '[paths]
    data = ' + $PGAPath + '\grafana\data' + '
    logs = ' + $PGAPath + '\grafana\logs' + '
    plugins = ' + $PGAPath + '\grafana\plugins' + '
    provisioning = ' + $PGAPath + '\grafana\conf\provisioning' + '
    [server]
    protocol = http
    http_addr = 0.0.0.0
    http_port = 80'

    New-Item -Name logs -Path $PGAPath\grafana -ItemType Directory
    New-Item -Name data -Path $PGAPath\grafana -ItemType Directory

    if($SSL) {
        New-Item -Name ssl -Path $PGAPath -ItemType Directory

        if(Test-Path C:\ProgramData\win-acme) {
            Remove-Item C:\ProgramData\win-acme -Recurse -Force
        }

        Write-Host "Generating Certificates..."
        & $PGAPath\wacs\wacs.exe --source manual --host $DNS --store pemfiles --pemfilespath "$PGAPath\ssl" --accepttos --emailaddress $Email
        $CertPath = $PGAPath + '\ssl\' + $DNS + '-crt.pem'
        $KeyPath = $PGAPath + '\ssl\' + $DNS + '-key.pem'

        $WebConfig = 'tls_server_config:
        cert_file: ' + $CertPath + '
        key_file: ' + $KeyPath + '
    basic_auth_users:
        ' + $AdminUsername + ': ' + $BcryptPassword + ''

        $GrafanaIni = '[paths]
    data = ' + $PGAPath + '\grafana\data' + '
    logs = ' + $PGAPath + '\grafana\logs' + '
    plugins = ' + $PGAPath + '\grafana\plugins' + '
    provisioning = ' + $PGAPath + '\grafana\conf\provisioning' + '
    [server]
    protocol = https
    http_addr = 0.0.0.0
    http_port = 443
    domain = ' + $DNS + '
    cert_file = ' + $CertPath + '
    cert_key = ' + $KeyPath + ''
    }

    Write-Host $AdminPassword

    Set-Content -Path $PGAPath\prometheus\web-config.yml -Value $WebConfig
    Set-Content -Path $PGAPath\alertmanager\web-config.yml -Value $WebConfig
    Set-Content -Path $PGAPath\grafana\conf\grafana.ini -Value $GrafanaIni

    & $PGAPath\nssm\win64\nssm.exe install Prometheus "$PGAPath\prometheus\prometheus.exe" `
        --config.file="$PGAPath\prometheus\prometheus.yml" `
        --storage.tsdb.path="$PGAPath\prometheus\data" `
        --web.config.file="$PGAPath\prometheus\web-config.yml" `
        --web.console.templates="$PGAPath\prometheus\consoles" `
        --web.console.libraries="$PGAPath\prometheus\console_libraries" `
        --web.listen-address=0.0.0.0:9090 `
        --web.external-url=$DNS `
        --web.enable-lifecycle `
        --storage.tsdb.retention.size=10GB

    & $PGAPath\nssm\win64\nssm.exe install Grafana "$PGAPath\grafana\bin\grafana-server.exe" --config="$PGAPath\grafana\conf\grafana.ini"

    & $PGAPath\nssm\win64\nssm.exe install Alertmanager "$PGAPath\alertmanager\alertmanager.exe" `
        --config.file="$PGAPath\alertmanager\alertmanager.yml" `
        --web.config.file="$PGAPath\alertmanager\web-config.yml" `
        --web.listen-address=0.0.0.0:9093 `
        --web.external-url=https:\\$DNS 

    Start-Service Prometheus
    Start-Service Grafana
    Start-Service Alertmanager

    Write-Host "Installation Complete. The passwords are stored in $PGAPath\passwords.txt file. If there were any issues then please raise an issue on Github."
}
catch {
    Write-Host $_
}
