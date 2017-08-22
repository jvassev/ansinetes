#!/bin/bash

log() {
  echo >&2 "$@"
}

if [ "$USER" != "ansinetes" ]; then
  # assume root
  adduser --uid $OUTER_USER ansinetes
  echo >> ~ansinetes/.bashrc
  echo  source "$(readlink -f $BASH_SOURCE)" >> ~ansinetes/.bashrc
  echo "export ANSINETES_PROJECT=${ANSINETES_PROJECT}" >> ~ansinetes/.bashrc
  echo "[ -e /etc/ansible/shell.inc ] && source /etc/ansible/shell.inc" >> ~ansinetes/.bashrc
  mkdir /ansinetes &> /dev/null
  chown ansinetes. /ansinetes
  chown ansinetes. /tmp/ansible
  if [ "$RUN_FILE" == "" ]; then
    mkdir -p ~ansinetes/.ssh
    ln -s /ansinetes/tmp/ssh_config ~ansinetes/.ssh/config
    exec su ansinetes -l
  else
    exec su ansinetes $RUN_FILE
  fi
fi

chmod go-rwx /ansinetes/security/ansible-ssh-key || true > /dev/null
export PATH=$PATH:/ansinetes/bin

if [ "$DEVMODE" == "" ]; then
  HISTFILE=/tmp/ansible/history
  if [ `ls -1 /ansinetes/ansible 2> /dev/null | wc -l` = '0' 2> /dev/null ]; then
    log ' ***' First run, copying default configuration
    cp /_defaults/* /ansinetes -R

    log ' ***' Generating ssh key...
    ssh-keygen -t rsa -N "" -q -f /ansinetes/security/ansible-ssh-key -C "ansible-generated/initial"

    log ' ***' Use this key for ssh:
    cat /ansinetes/security/ansible-ssh-key.pub

    log ' ***' Generating config.rb for Vagrant
    mkdir /ansinetes/vagrant &> /dev/null
    pushd /ansinetes/vagrant > /dev/null

    cat << EOF > config.rb
\$num_instances = 4
\$instance_name_prefix = "core"
\$update_channel = "beta"
\$image_version = "current"
EOF

    cat << EOF > user-data
#cloud-config

ssh_authorized_keys:
  - "$(cat /ansinetes/security/ansible-ssh-key.pub)"
  - "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key"
EOF

  popd > /dev/null

  cat << EOF > /ansinetes/.gitignore
tmp/
vagrant/.vagrant
*.retry
EOF
  fi
fi
