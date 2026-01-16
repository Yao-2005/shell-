#!/bin/bash
# BIND 9.11.36 → 9.19.21 升级脚本

set -e

echo "=== BIND 升级开始 ==="

# 1. 备份
BACKUP_DIR="/root/bind_upgrade_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR
cp -r /etc/named* $BACKUP_DIR/
cp -r /var/named $BACKUP_DIR/
cp /usr/sbin/named $BACKUP_DIR/named.old

# 2. 停止服务
systemctl stop named

# 安装编译依赖
dnf install -y gcc make libtool automake autoconf
dnf install -y libuv-devel libxml2-devel json-c-devel libnghttp2-devel userspace-rcu-devel libcap-devel

# 3. 下载和编译新版本
wget  https://ftp.isc.org/isc/bind9/9.19.21/bind-9.19.21.tar.xz
xz -d bind-9.19.21.tar.xz
tar xf bind-9.19.21.tar
cd bind-9.19.21

# 4. 编译安装
./configure --prefix=/usr \
            --sysconfdir=/etc \
            --localstatedir=/var \
            --with-openssl=no \
            --enable-threads \
            --enable-ipv6

make -j$(nproc)
make install

# 5. 修复权限（保持原有）
chown -R named:named /var/named
chmod 775 /var/named

# 6. 修复配置文件兼容性

echo "修复配置文件兼容性..."
sed -i '/dnssec-enable/d' /etc/named.conf
echo "检查配置文件..."
named-checkconf /etc/named.conf
#echo "检查区域文件..."
named-checkzone di.qihoo.net /var/named/di.qihoo.net.zone

# 7. 启动服务
systemctl daemon-reload
systemctl start named

# 8. 验证
echo "等待服务启动..."
sleep 3
systemctl status named --no-pager

#echo "测试解析..."
dig @127.0.0.1 di.qihoo.net SOA +short
dig @127.0.0.1 www.google.com +short

echo "=== 升级完成 ==="
echo "备份保存在: $BACKUP_DIR"
