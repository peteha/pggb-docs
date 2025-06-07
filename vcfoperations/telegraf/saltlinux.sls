{% set ops_user = 'admin' %}
{% set ops_password = '##$$VMware123' %}
{% set ops_proxyip= '10.205.16.57' %}
{% set opshost= 'pgops.pggb.net' %}
{% set collectiongroup= '10.205.16.57' %}
{% set telegraf= '/usr/bin/telegraf' %}
{% set telegrafconfig= '/etc/telegraf/telegraf.d' %}
{% set temp= '/opt/deploy/temp' %}

install-base-packages:
  pkg.installed:
    - pkgs:
      - unzip
      - coreutils
      - net-tools
      - jq

create-deploy-temp:
  file.directory:
    - name: {{ temp }}
    - makedirs: True
    - unless: 'test -d {{ temp }}'
    - require:
      - pkg: install-base-packages


add-influxdata-repo:
  cmd.run:
    - name: >
        cd {{ temp }} &&
        curl --silent --location -O https://repos.influxdata.com/influxdata-archive.key &&
        echo "943666881a1b8d9b849b74caebf02d3465d6beb716510d86a39f6c8e8dac7515  influxdata-archive.key" | sha256sum -c - &&
        cat influxdata-archive.key | gpg --dearmor | tee /etc/apt/trusted.gpg.d/influxdata-archive.gpg > /dev/null &&
        echo 'deb [signed-by=/etc/apt/trusted.gpg.d/influxdata-archive.gpg] https://repos.influxdata.com/debian stable main' | tee /etc/apt/sources.list.d/influxdata.list
    - creates: /etc/apt/trusted.gpg.d/influxdata-archive.gpg

update-apt:
  cmd.run:
    - name: apt-get update
    - require:
      - cmd: add-influxdata-repo

install-telegraf:
  pkg.installed:
    - name: telegraf
    - require:
      - cmd: update-apt

create-telegraf-config-dir:
  file.directory:
    - name: {{ telegrafconfig }}
    - require:
      - pkg: install-telegraf
    - unless: 'test -d {{telegrafconfig}}'

download-telegraf-mod:
  cmd.run:
    - name: >
        curl --insecure -L -o /opt/deploy/temp/telegraf-utils.sh https://{{ ops_proxyip }}/downloads/salt/telegraf-utils.sh &&
        chmod +x {{ temp }}/telegraf-utils.sh
    - unless: 'test -f {{ temp }}/telegraf-utils.sh'


get-auth-token:
  cmd.run:
    - name: >
        curl -X POST "https://{{ opshost }}/suite-api/api/auth/token/acquire?_no_links=true" -H "accept: application/json" -H "Content-Type: application/json" -d '{"username": "{{ ops_user }}", "password": "{{ ops_password }}"}' --insecure | jq -r .token > /opt/deploy/temp/auth_token.txt
    - require:
      - pkg: install-base-packages

verify-auth-token:
  file.exists:
    - name: {{ temp }}/auth_token.txt
    - require:
      - cmd: get-auth-token

register-telegraf:
  cmd.run:
    - name: >
        token=$(cat {{ temp }}/auth_token.txt) &&
        {{ temp }}/telegraf-utils.sh opensource -c {{ collectiongroup }} -t "$token" -d {{ telegrafconfig }} -e {{ telegraf }} -v {{ opshost }}
    - require:
      - file: verify-auth-token


set-telegraf-perms:
  file.managed:
    - names:
      - {{ telegrafconfig }}/cert.pem
      - {{ telegrafconfig }}/key.pem
    - mode: '0644'

restart-telegraf:
  service.running:
    - name: telegraf
    - enable: True
    - reload: False
    - watch:
      - cmd: register-telegraf
    - require:
      - file: set-telegraf-perms