param (
    [Parameter(Mandatory=$true)]$ELKPath,
    $Version = "8.1.0",
    [switch]$SSL,
    $DNS = ""
)

if($SSL) {
    if($DNS -eq "") {
        Write-Host "DNS address is not defined. If SSL is selected, then DNS address should be defined."
        Exit 0
    }    
}

if(-not (Test-Path $ELKPath)) {
    New-Item -ItemType Directory -Path $ELKPath -Force
}

$ElasticsearchFile = "elasticsearch-$Version-windows-x86_64.zip"
$KibanaFile = "kibana-$Version-windows-x86_64.zip"
$LogStashFile = "logstash-$Version-windows-x86_64.zip"

$ElasticsearchURL = "https://artifacts.elastic.co/downloads/elasticsearch/$ElasticsearchFile"
$KibanaURL = "https://artifacts.elastic.co/downloads/kibana/$KibanaFile"
$LogstashURL = "https://artifacts.elastic.co/downloads/logstash/$LogStashFile"
$WinACMEURL = "https://github.com/win-acme/win-acme/releases/download/v2.1.20.1/win-acme.v2.1.20.1185.x64.trimmed.zip"
$NSSMURL = "https://nssm.cc/ci/nssm-2.24-103-gdee49fc.zip"

Write-Host "Downloading Elasticsearch..."
Start-BitsTransfer $ElasticsearchURL -Destination $ELKPath
Write-Host "Downloading Kibana..."
Start-BitsTransfer $KibanaURL -Destination $ELKPath
Write-Host "Downloading Logstash..."
Start-BitsTransfer $LogstashURL -Destination $ELKPath
Write-Host "Downloading Win ACME..."
Start-BitsTransfer $WinACMEURL -Destination $ELKPath
Write-Host "Downloading NSSM..."
Start-BitsTransfer $NSSMURL -Destination $ELKPath

Write-Host "Extracting Elsticsearch..."
Expand-Archive $ELKPath\$ElasticsearchFile -DestinationPath $ELKPath
Rename-Item $ELKPath\elasticsearch-$Version -NewName elasticsearch
Write-Host "Extracting Kibana..."
# Expand-Archive $ELKPath\$KibanaFile -DestinationPath $ELKPath
Rename-Item $ELKPath\kibana-$Version -NewName kibana
Write-Host "Extracting Logstash..."
Expand-Archive $ELKPath\$LogStashFile -DestinationPath $ELKPath
Rename-Item $ELKPath\logstash-$Version -NewName logstash
Write-Host "Extracting Win ACME..."
Expand-Archive $ELKPath\win-acme.v2.1.20.1185.x64.trimmed.zip -DestinationPath $ELKPath\wacs
Write-Host "Extracting NSSM..."
Expand-Archive $ELKPath\nssm-2.24-103-gdee49fc.zip -DestinationPath $ELKPath

Write-Host "Installing elasticsearch as service..."

$Service = Get-Service elasticsearch-service-x64 -ErrorAction SilentlyContinue
if($Service -eq $null) {
    & $ELKPath\elasticsearch\bin\elasticsearch-service.bat install
}
else {
    Write-Host "Service elasticsearch-service-x64 already exists"
}

if($SSL) {
    Write-Host "Generating Certificates..."
    & $ELKPath\wacs\wacs.exe --source manual --host $DNS --store pemfiles --pemfilespath $ELKPath
    New-Item -ItemType Directory -Path $ELKPath\elasticsearch\config\certs -Force
    New-Item -ItemType Directory -Path $ELKPath\kibana\config\certs -Force
    Copy-Item $ELKPath\$DNS-key.pem -Destination $ELKPath\elasticsearch\config\certs
    Copy-Item $ELKPath\$DNS-crt.pem -Destination $ELKPath\elasticsearch\config\certs
    Copy-Item $ELKPath\$DNS-key.pem -Destination $ELKPath\kibana\config\certs
    Copy-Item $ELKPath\$DNS-crt.pem -Destination $ELKPath\kibana\config\certs
}

$ElasticsearchYML = '
xpack.security.enabled: true
xpack.security.enrollment.enabled: true
cluster.initial_master_nodes: ["elk"]
http.host: [_local_, _site_]
'

Remove-Item $ELKPath\elasticsearch\config\elasticsearch.yml -Force
Set-Content -Path $ELKPath\elasticsearch\config\elasticsearch.yml -Value $ElasticsearchYML
Start-Service elasticsearch-service-x64

Write-Host "Sleeping 30 seconds so that elasticsearch can start"
Start-Sleep -Seconds 30

Write-Host "Resetting Passwords..."
$ElasticPassword = (& "$ELKPath\elasticsearch\bin\elasticsearch-reset-password.bat" -u elastic -b)[1].Trim().Split(" ")[-1]
$KibanaSystemPassword = (& "$ELKPath\elasticsearch\bin\elasticsearch-reset-password.bat" -u kibana_system -b)[1].Trim().Split(" ")[-1]

if($SSL) {
    Stop-Service elasticsearch-service-x64 -Force -NoWait -ErrorAction SilentlyContinue
    Write-Host "Sleeping 30 seconds so that elasticsearch can stop"
    Start-Sleep -Seconds 30

    $ElasticsearchYML = 'xpack.security.enabled: true
xpack.security.enrollment.enabled: true
xpack.security.http.ssl:
    enabled: true
    key: ' + $ELKPath + '\elasticsearch\config\certs\' + $DNS + '-key.pem
    certificate: ' + $ELKPath + '\elasticsearch\config\certs\' + $DNS + '-crt.pem
cluster.initial_master_nodes: ["elk"]
http.host: [_local_, _site_]'
    Remove-Item $ELKPath\elasticsearch\config\elasticsearch.yml -Force
    Set-Content -Path $ELKPath\elasticsearch\config\elasticsearch.yml -Value $ElasticsearchYML
}

Write-Host "Installing Kibana..."
$KibanaYML = 'server.host: "0.0.0.0"
server.publicBaseUrl: "http://localhost"
elasticsearch.hosts: ["http://localhost:9200"]
elasticsearch.username: "kibana_system"
elasticsearch.password: "' + $KibanaSystemPassword + '"
elasticsearch.ssl.verificationMode: none'

if($SSL) {
    $KibanaYML = 'server.host: "0.0.0.0"
server.publicBaseUrl: "https://' + $DNS + '"
server.ssl.enabled: true
server.ssl.certificate: ' + $ELKPath + '\kibana\config\certs\' + $DNS + '-crt.pem
server.ssl.key: ' + $ELKPath + '\kibana\config\certs\' + $DNS + '-key.pem
elasticsearch.hosts: ["https://' + $DNS + ':9200"]
elasticsearch.username: "kibana_system"
elasticsearch.password: "' + $KibanaSystemPassword + '"
elasticsearch.ssl.verificationMode: none'
}

Remove-Item $ELKPath\kibana\config\kibana.yml -Force
Set-Content -Path $ELKPath\kibana\config\kibana.yml -Value $KibanaYML
& $ELKPath\nssm-2.24-103-gdee49fc\win64\nssm.exe install Kibana $ELKPath\kibana\bin\kibana.bat

Start-Service elasticsearch-service-x64 -ErrorAction SilentlyContinue
Start-Service Kibana

Set-Content $ELKPath\passwords.txt -Value "elastic: $ElasticPassword`nkibana_system: $KibanaSystemPassword"

Write-Host "Cleaning Files..."

Remove-Item $ELKPath\$ElasticsearchFile -Force
Remove-Item $ELKPath\$KibanaFile -Force
Remove-Item $ELKPath\$LogStashFile -Force
Remove-Item $ELKPath\win-acme.v2.1.20.1185.x64.trimmed.zip -Force
Remove-Item $ELKPath\nssm-2.24-103-gdee49fc.zip -Force

Write-Host "Password elastic: $ElasticPassword, kibana_system: $KibanaSystemPassword"
Write-Host "Passwords are also stored in passwords.txt file."
Write-Host "If elasticsearch or kibana doesn't work as expected then try to start the services manully from services.msc"
Write-Host "If kibana shows error that elasticsearch did not load properly or kibana doesn't start immediately, pleae wait for a minute or two and then try loading kibana again."
Write-Host "Install Location $ELKPath"
