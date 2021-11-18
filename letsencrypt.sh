#!/bin/bash

cat<<'EOF'>/usr/local/bin/gencert
#!/bin/bash

[[ -z "$(type certbot)" ]] && apt-get -y install certbot apache2
[[ -z "$(type keytool)" ]] && apt-get -y install openjdk-11-jdk

runuser=$(whoami)
tempdir=$(pwd)
domain="$(hostname)"
password="XPASSWORD"
domainStore="java.keystore"
domainPkcs="$domain.pkcs12"

func_install_letsencrypt(){
  echo '[Starting] to build letsencrypt cert!'
  certbot certonly --standalone -d $domain -n --register-unsafely-without-email --agree-tos
  if [ -e /etc/letsencrypt/live/$domain/fullchain.pem ]; then
    echo '[Success] letsencrypt certs are built!'
  else
    echo "[ERROR] letsencrypt certs failed to build.  Check that DNS A record is properly configured for this domain"
  exit 1
  fi
}

func_build_pkcs(){
  cd /etc/letsencrypt/live/$domain
  echo '[Starting] Building PKCS12 .p12 cert.'
  openssl pkcs12 -export -in fullchain.pem -inkey privkey.pem -out $domainPkcs -name $domain -passout pass:$password
  echo '[Success] Built $domainPkcs PKCS12 cert.'
  echo '[Starting] Building Java keystore via keytool.'
  printf "yes" | keytool -importkeystore -deststorepass $password -destkeypass $password -destkeystore $domainStore -srckeystore $domainPkcs -srcstoretype PKCS12 -srcstorepass $password -alias $domain
  echo '[Success] Java keystore $domainStore built.'
  cp $domainStore $tempdir
  echo '[Success] Moved Java keystore to current working directory.'
}

main() {
  func_install_letsencrypt
  func_build_pkcs
}

main

printf "\n\033[1;32m Готово!\n\n\033[1;37m \033[1;33m /etc/letsencrypt/archive/$domain \033[0m $(ls --color=always -l /etc/letsencrypt/archive/$domain)\n\n \033[1;33m /etc/letsencrypt/live/$domain \033[0m  $(ls --color=always -l /etc/letsencrypt/live/$domain)\033[0m\n"

[[ -z "$(cat /var/spool/cron/crontabs/root | grep gencert)" ]] && (crontab -l | grep . ; echo -e "0 0 1,15 * * sudo /usr/local/bin/gencert") | crontab -
EOF
chmod +x /usr/local/bin/gencert && gencert ; rm /usr/local/bin/gencert