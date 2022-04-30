PROMETHEUS_DIR=/etc/prometheus
SSL=false
DNS=localhost
ADMIN_USER=admin
ADMIN_PASSWORD=$RANDOM

while getopts ":p:s:d:" opt; do
    case $opt in
        l) PROMETHEUS_DIR="$OPTARG"
        ;;
        s) SSL="$OPTARG"
        ;;
        d) DNS="$OPTARG"
        ;;
        u) ADMIN_USER="$OPTARG"
        ;;
        p) ADMIN_PASSWORD="$OPTARG"
        ;;
        \?) echo "Invalid option -$OPTARG"
        exit 1
        ;;
    esac

    case $OPTARG in
        -*) echo "Option $opt needs a valid argument"
        exit 1
        ;;
    esac
done

if [ "$SSL" = true ] ; then
    if [ "$DNS" = "localhost" ] ; then
        echo "Please provide a valid DNS with -d when SSL is true"
        exit 1
    fi
fi

if [ -d "$PROMETHEUS_DIR" ] ; then
    echo "$PROMETHEUS_DIR already exists"
    exit 1
else
    echo "$PROMETHEUS_DIR does not exist"
fi

wget https://github.com/prometheus/prometheus/releases/download/v2.35.0/prometheus-2.35.0.linux-amd64.tar.gz
tar -xvzf prometheus-2.35.0.linux-amd64.tar.gz
mv prometheus-2.35.0.linux-amd64 "$PROMETHEUS_DIR"

apt -y install apache2-utils
BCRYPT_WITH_USER=$(htpasswd -nbBC 10 $ADMIN_USER $ADMIN_PASSWORD)
BCRYPT=$(echo $BCRYPT_WITH_USER | cut -d ":" -f 2)

if [ "$SSL" = true ] ; then

    apt -y install certbot
    certbot certonly -n -d $DNS --standalone
    mkdir $PROMETHEUS_DIR/ssl
    cp /etc/letsencrypt/live/$DNS/fullchain.pem $PROMETHEUS_DIR/ssl
    cp /etc/letsencrypt/live/$DNS/privkey.pem $PROMETHEUS_DIR/ssl

    cat >$PROMETHEUS_DIR/web-config.yml<<EOF
tls_server_config:
    cert_file: ${PROMETHEUS_DIR}/ssl/fullchain.pem
    key_file: ${PROMETHEUS_DIR}/ssl/privkey.pem
basic_auth_users:
    ${ADMIN_USER}: ${BCRYPT}
EOF

    cat >/etc/systemd/system/prometheus.service<<EOF
[Unit]
Description=Prometheus systemd service unit
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=root
Group=root
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/etc/prometheus/prometheus \
--config.file=/etc/prometheus/prometheus.yml \
--storage.tsdb.path=/etc/prometheus/data \
--web.config.file=/etc/prometheus/web-config.yml \
--web.console.templates=/etc/prometheus/consoles \
--web.console.libraries=/etc/prometheus/console_libraries \
--web.listen-address=0.0.0.0:9090 \
--web.external-url=${DNS}
--web.enable-lifecycle \
--storage.tsdb.retention.size=10GB

SyslogIdentifier=prometheus
Restart=always

[Install]
WantedBy=multi-user.target
EOF

else

    cat >$PROMETHEUS_DIR/web-config.yml<<EOF
basic_auth_users:
    ${ADMIN_USER}: ${BCRYPT}
EOF

    cat >/etc/systemd/system/prometheus.service<<EOF
[Unit]
Description=Prometheus systemd service unit
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=root
Group=root
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/etc/prometheus/prometheus \
--config.file=/etc/prometheus/prometheus.yml \
--storage.tsdb.path=/etc/prometheus/data \
--web.config.file=/etc/prometheus/web-config.yml \
--web.console.templates=/etc/prometheus/consoles \
--web.console.libraries=/etc/prometheus/console_libraries \
--web.listen-address=0.0.0.0:9090 \
--web.enable-lifecycle \
--storage.tsdb.retention.size=10GB

SyslogIdentifier=prometheus
Restart=always

[Install]
WantedBy=multi-user.target
EOF

fi

cat >password.txt<<EOF
ADMIN_USER: ${ADMIN_USER}
ADMIN_PASSWORD: ${ADMIN_PASSWORD}
EOF

systemctl daemon-reload
systemctl start prometheus

rm -rf prometheus-2.35.0.linux-amd64
rm prometheus-2.35.0.linux-amd64.tar.gz
