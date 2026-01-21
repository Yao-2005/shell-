#!/bin/bash
#Keeper升级脚本
# 从3.8.5升级到3.9.4

echo "=== ZooKeeper升级脚本 ==="
echo "当前版本: 3.8.5 → 目标版本: 3.9.4"
read -p "是否继续? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "取消操作"
    exit 1
fi

# 1. 备份
echo "1. 备份当前版本..."
BACKUP_DIR="/opt/zookeeper-backup-$(date +%Y%m%d)"
cp -rp /opt/zookeeper $BACKUP_DIR
cp /etc/systemd/system/zookeeper.service /etc/systemd/system/zookeeper.service.backup
echo "备份完成: $BACKUP_DIR"

# 2. 停止服务
echo "2. 停止服务..."
systemctl stop kafka
systemctl stop zookeeper
sleep 5
echo "服务已停止"

# 3. 下载新版本
echo "3. 下载ZooKeeper 3.9.4..."
cd /opt
wget -q https://mirrors.aliyun.com/apache/zookeeper/zookeeper-3.9.4/apache-zookeeper-3.9.4-bin.tar.gz
tar -xzf apache-zookeeper-3.9.4-bin.tar.gz

# 4. 迁移配置
echo "4. 迁移配置..."
cp /opt/zookeeper/conf/zoo.cfg /opt/apache-zookeeper-3.9.4-bin/conf/
mkdir -p /opt/apache-zookeeper-3.9.4-bin/data
cp /opt/zookeeper/data/myid /opt/apache-zookeeper-3.9.4-bin/data/

# 5. 备份旧版本并切换
echo "5. 切换版本..."
mv /opt/apache-zookeeper-3.8.5-bin /opt/apache-zookeeper-3.8.5-bin.backup

# 更新软链接
ln -sfn /opt/apache-zookeeper-3.9.4-bin /opt/zookeeper
echo "软链接已更新: /opt/zookeeper -> $(readlink /opt/zookeeper)"

# 6. 启动服务
echo "6. 启动ZooKeeper..."
systemctl start zookeeper
sleep 3

# 检查ZooKeeper状态
if systemctl is-active zookeeper >/dev/null; then
    echo "✅ ZooKeeper启动成功"
    echo "版本信息: $(/opt/zookeeper/bin/zkServer.sh version 2>/dev/null | head -1)"
else
    echo "❌ ZooKeeper启动失败"
    systemctl status zookeeper --no-pager
    exit 1
fi

# 7. 启动Kafka
echo "7. 启动Kafka..."
systemctl start kafka
sleep 5

if systemctl is-active kafka >/dev/null; then
    echo "✅ Kafka启动成功"

    # 测试功能
    echo "8. 测试集群功能..."
    /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ 集群功能正常"
    else
        echo "⚠️  功能测试异常，但服务在运行"
    fi
else
    echo "❌ Kafka启动失败"
    systemctl status kafka --no-pager
fi

echo "=== 升级完成 ==="
echo "旧版本备份:"
ls -d /opt/apache-zookeeper-*.backup 2>/dev/null || echo "无"
echo ""
echo "如需回滚:"
echo "  systemctl stop kafka zookeeper"
echo "  ln -sfn /opt/apache-zookeeper-3.8.5-bin.backup /opt/zookeeper"
echo "  systemctl start zookeeper kafka"
