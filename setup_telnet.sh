#!/bin/bash

# OpenSSH升级准备脚本
# 功能：创建临时用户并安装配置telnet作为备用连接

# 检查root权限
if [ "$EUID" -ne 0 ]; then
    echo "错误：请以root用户运行此脚本"
    exit 1
fi

echo "=== 开始配置telnet备用连接 ==="

# 步骤1：创建临时用户sshuser
echo "1. 创建临时用户sshuser..."
useradd -m -s /bin/bash sshuser 2>/dev/null

# 设置密码
echo "为sshuser设置密码：1"
echo "sshuser:1" | chpasswd

# 添加sudo权限
usermod -aG wheel sshuser 2>/dev/null || usermod -aG sudo sshuser

# 步骤2：安装telnet
echo "2. 安装telnet-server..."
yum install -y telnet-server

# 步骤3：启动telnet服务
echo "3. 启动telnet服务..."
systemctl start telnet.socket
systemctl enable telnet.socket

# 步骤4：配置防火墙（优化版）
echo "4. 配置防火墙开放23端口..."
# 检查防火墙是否运行
if systemctl is-active --quiet firewalld; then
    echo "防火墙正在运行，开放23端口..."
    firewall-cmd --zone=public --add-port=23/tcp --permanent 2>/dev/null
    firewall-cmd --reload 2>/dev/null
    echo "23端口已开放"
else
    echo "防火墙未运行，跳过防火墙配置"
fi

echo ""
echo "=== 配置完成 ==="
echo ""
echo "重要信息："
echo "1. Telnet用户：sshuser"
echo "2. Telnet密码：1"
echo "3. Telnet端口：23"
echo ""
echo "升级完成后建议："
echo "   userdel -r sshuser"
echo "   firewall-cmd --remove-port=23/tcp --permanent"

