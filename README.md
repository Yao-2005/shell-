# 运维shell脚本

## 1.升级OpenSSH版本，用到一下两个脚本:setup_telnet.sh,update_openssh.sh

### 1.远程升级OpenSSH的先创建新增账号和安装telnet

**1.前提：**

	安装OpenSSH过程中需要删除OpenSSH和修改配置，因此如果是远程安装补丁的，切记要首选安装telnetServer ，通过telnet 方式连接到远程,升级完成后再卸载调telnet。 另外telnet默认不允许root账号进行远程连接的，需要建一个新的账号（如 sshuser）进行远程（telnet连接后，可以通过sudo su - 方式切换成 root ，进行后续的升级操作）
**2.在服务器上创建并执行脚本setup_telnet.sh**

```
#bash setup_telnet.sh

#成功升级后关闭telnet服务
#1.停止服务和禁用开机启动
systemctl stop telnet.socket && systemctl disable telnet.socket
#2.检查服务状态
systemctl status telnet.socket
```

### 2.通过telent远程连接到服务器，执行升级计划

**1.用户名：sshuser，密码：1，端口：23**

```
#telnet 服务器ip 23
#示例： telnet 123.124.11.12 23
```

**2.在服务器上创建并执行脚本update_openssh.sh**

```
#bash update_openssh.sh

#升级后相关启停命令
#/etc/init.d/sshd.init start  启动sshd服务
#/etc/init.d/sshd.init stop  停止sshd服务
#/etc/init.d/sshd.init status  查看sshd服务状态
“配置文件所在位置：/etc/ssh/sshd_config”
```

## 2.升级DNS服务版本用到以下脚本：update_dns.sh

1.登录到服务器上创建并执行update_dns.sh

```
#bash update_dns.sh

#升级后相关启停命令
#systemctl start named.service 启动dns服务
#systemctl stop named.service 停止dns服务
#systemctl status named.service 查看dns服务状态
“配置文件所在位置：/etc/named.conf”
```

