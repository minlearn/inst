#anna-install network-console
mkdir -p /etc/ssh
# use echo "sshd::0:0:sshd:/:/bin/sh" instead of echo "sshd::100:65534::/run/sshd:/bin/sh" to avoid permission issues
ssh-keygen -b 2048 -t rsa -N '' -f /etc/ssh/ssh_host_rsa_key -q
echo "sshd::1:0:99999:7:::" >> /etc/shadow;grep -qs ^nogroup: /etc/group || echo "nogroup:*:65534:" >> /etc/group;grep -qs ^sshd: /etc/passwd || echo "sshd::0:0:sshd:/:/bin/sh" >> /etc/passwd;mkdir -p /run/sshd;chmod 0755 /run/sshd
echo -e "# Installer generated configuration file\n\nPort 22\nProtocol 2\nHostKey /etc/ssh/ssh_host_rsa_key\nLoginGraceTime 600\nPermitRootLogin yes\nStrictModes yes\nPermitEmptyPasswords yes\nPasswordAuthentication yes\n\nX11Forwarding no\nPrintMotd yes\nTCPKeepAlive yes" >> /etc/ssh/sshd_config
/usr/sbin/sshd
