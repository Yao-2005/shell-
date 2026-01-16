#!/bin/bash

# OpenSSH 9.8p1 升级脚本

# 检查root权限
if [ "$EUID" -ne 0 ]; then
    echo "错误：请以root用户运行此脚本"
    exit 1
fi

echo "=== 开始升级OpenSSH到9.8p1 ==="
echo "当前OpenSSH版本："
ssh -V 2>&1 || echo "未安装或无法获取版本"
echo ""

# 0. 安装依赖包
echo "0. 安装编译依赖包..."
yum install -y gcc make zlib-devel openssl-devel pam-devel wget
if [ $? -eq 0 ]; then
    echo "依赖包安装成功"
else
    echo "依赖包安装失败，请检查yum源"
    exit 1
fi
echo ""

# 1. 获取安装包
echo "1. 下载OpenSSH 9.8p1安装包..."
wget https://mirrors.bfsu.edu.cn/OpenBSD/OpenSSH/portable/openssh-9.8p1.tar.gz
if [ $? -eq 0 ]; then
    echo "下载成功"
else
    echo "下载失败，请检查网络连接"
    exit 1
fi
echo ""

# 2. 卸载旧版openssh
echo "2. 卸载旧版OpenSSH..."
for i in $(rpm -qa | grep openssh); do
    echo "卸载: $i"
    rpm -e $i --nodeps 2>/dev/null
done
echo "卸载完成"
echo ""

# 3. 解压安装包
echo "3. 解压openssh9.8p1安装包..."
tar zxf openssh-9.8p1.tar.gz -C /usr/local
if [ $? -eq 0 ]; then
    echo "解压成功"
else
    echo "解压失败"
    exit 1
fi
echo ""

# 4. 编译安装
echo "4. 编译安装OpenSSH 9.8p1..."
cd /usr/local/openssh-9.8p1/ || exit 1

echo "配置编译参数..."
./configure --prefix=/usr/local/openssh --sysconfdir=/etc/ssh --with-pam --with-md5-passwords --mandir=/usr/share/man --with-zlib=/usr/local/zlib --without-hardening

if [ $? -ne 0 ]; then
    echo "配置失败，请检查依赖包是否安装完整"
    exit 1
fi

echo "编译中..."
make
if [ $? -ne 0 ]; then
    echo "编译失败"
    exit 1
fi

echo "安装中..."
make install
if [ $? -ne 0 ]; then
    echo "安装失败"
    exit 1
fi

echo "编译安装完成"
echo ""

# 5. 修复密钥文件权限（关键步骤）
echo "5. 修复SSH密钥文件权限..."
echo "修复私钥文件权限为600..."
chmod 600 /etc/ssh/ssh_host_*_key 2>/dev/null
echo "修复公钥文件权限为644..."
chmod 644 /etc/ssh/ssh_host_*_key.pub 2>/dev/null
echo "权限修复完成"
echo ""

# 6. 配置服务
echo "6. 配置SSH服务..."
cp /usr/local/openssh-9.8p1/contrib/redhat/sshd.init /etc/init.d/
chmod +x /etc/init.d/sshd.init

# 更新SSHD路径
sed -i "s|SSHD=/usr/sbin/sshd|SSHD=/usr/local/openssh/sbin/sshd|g" /etc/init.d/sshd.init
sed -i "s|/usr/bin/ssh-keygen -A|/usr/local/openssh/bin/ssh-keygen -A|g" /etc/init.d/sshd.init

echo "路径更新完成："
grep "SSHD=" /etc/init.d/sshd.init
echo ""


# 7. 修改配置
echo "7. 更新SSH配置..."
# 备份原有配置
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# 确保必要的配置存在
grep -q "^X11Forwarding" /etc/ssh/sshd_config || echo 'X11Forwarding yes' >> /etc/ssh/sshd_config
grep -q "^PasswordAuthentication" /etc/ssh/sshd_config || echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config

echo "配置更新完成"
echo ""

# 8. 复制命令
echo "8. 复制命令文件..."
cp -arp /usr/local/openssh/bin/* /usr/bin/
echo "命令复制完成"
echo ""

# 9. 启动服务
echo "9. 启动SSH服务..."
# 先停止可能还在运行的旧SSH服务
pkill sshd 2>/dev/null
sleep 2

# 启动服务
/etc/init.d/sshd.init start
if [ $? -eq 0 ]; then
    echo "SSH服务启动成功"
else
    echo "SSH服务启动失败，尝试手动启动..."
    
    # 检查并再次修复权限
    echo "检查并修复权限..."
    ls -la /etc/ssh/ssh_host_*_key
    chmod 600 /etc/ssh/ssh_host_*_key
    
    # 尝试直接启动sshd
    echo "尝试直接启动sshd进程..."
    /usr/local/openssh/sbin/sshd
fi
echo ""

# 10. 检查服务状态
echo "10. 检查SSH服务状态..."
if ps aux | grep -v grep | grep -q "/usr/local/openssh/sbin/sshd"; then
    echo "✓ SSH服务正在运行"
    echo "进程信息："
    ps aux | grep "/usr/local/openssh/sbin/sshd" | grep -v grep
else
    echo "✗ SSH服务未运行"
    echo "显示当前密钥文件权限："
    ls -la /etc/ssh/ssh_host_*
fi
echo ""

# 11. 设置开机启动
echo "11. 设置开机启动..."
chmod +x /etc/rc.d/rc.local
grep -q "sshd.init" /etc/rc.d/rc.local || echo "/etc/init.d/sshd.init start" >> /etc/rc.d/rc.local
echo "开机启动设置完成"
echo ""

# 12. 验证安装
echo "12. 验证安装结果..."
echo "新的OpenSSH版本："
/usr/local/openssh/bin/ssh -V
echo ""
echo "SSH服务监听端口："
netstat -tlnp | grep sshd 2>/dev/null || echo "未检测到SSH监听端口"
echo ""

# 清理安装包
echo "清理安装包..."
rm -f openssh-9.8p1.tar.gz
echo ""

echo "=== OpenSSH升级完成 ==="
echo ""
echo "如果SSH服务未启动，请检查："
echo "1. 密钥文件权限：ls -la /etc/ssh/ssh_host_*"
echo "2. 手动修复：chmod 600 /etc/ssh/ssh_host_*_key"
echo "3. 手动启动：/usr/local/openssh/sbin/sshd"
echo ""
echo "配置文件：/etc/ssh/sshd_config"

