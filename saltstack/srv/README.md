saltstack
=========

Install
-------
    cd /root
    git clone https://github.com/mds1455975151/tools.git
    ln -s /root/tools/saltstack/srv/salt /srv/salt
    ln -s /root/tools/saltstack/srv/pillar /srv/pillar

Demo
----
    salt '*' state.sls init.init-all

- - -

Node
----
    rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
    yum install -y salt-minion
    chkconfig salt-minion on

    cp /etc/salt/minion{,.original}
    sed -i '12,12imaster: salt.example.org' /etc/salt/minion

    cat >> /etc/hosts <<'EOF'

    192.168.2.1    salt.example.org
    EOF

    service salt-minion start
    grep HOSTNAME /etc/sysconfig/network

Master
------
    salt-key -a host.example.org

    salt 'localhost.localdomain' state.sls ntp
    salt 'localhost.localdomain' state.sls vim
    salt 'localhost.localdomain' state.sls rsync
    salt 'localhost.localdomain' state.sls nginx
    salt 'localhost.localdomain' state.sls php.cli
    salt 'localhost.localdomain' state.sls php.php-fpm
