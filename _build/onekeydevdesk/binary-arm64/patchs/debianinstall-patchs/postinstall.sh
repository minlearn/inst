  core=$1
  sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/g' /target/etc/ssh/sshd_config
  sed -i 's/http:\/\/github/https:\/\/github/g;s/http:\/\/gitee/https:\/\/gitee/g;s/${core}\/debianbase/http:\/\/deb.debian.org\/debian/g' /target/etc/apt/sources.list
