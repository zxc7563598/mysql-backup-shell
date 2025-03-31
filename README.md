# 🚀 项目简介
这是一个基于Shell脚本的MySQL数据库自动化备份工具，支持定时全量/增量备份、压缩存储、自动清理过期备份等功能。通过简单的配置即可实现企业级数据库备份方案，适用于开发运维、服务器维护等场景。

## 这个脚本做了什么？

这个脚本的核心功能包括：

* **自动备份 MySQL 数据库**，每天定时运行（可通过 `crontab`​ 设置）。
* **本地存储**：按日期分类存放备份文件，并自动删除过期备份，避免磁盘占满。
* **远程服务器同步**：支持通过 `rsync`​ 传输备份到另一台服务器，确保数据冗余。
* **阿里云 OSS 备份**：可以将备份文件上传到阿里云对象存储，进一步增强安全性。
* **自动清理过期备份**：定期清理本地、远程和 OSS 上的旧备份，减少存储成本。

你可以在 `mysql_backup.sh`​ 中修改配置，根据自己的需求调整备份策略。

---

## 如何使用？

### 1. 下载脚本

```bash
git clone https://github.com/zxc7563598/mysql-backup-shell.git
cd mysql-backup-shell
chmod +x mysql_backup.sh
```

然后修改 `mysql_backup.sh`​ 里的参数，确保 `MySQL`​ 连接信息正确。

### 2. 设置定时任务

执行 `crontab -e`​，然后添加：

```bash
0 3 * * * /path/to/mysql_backup.sh
```

这样每天凌晨 3:00 就会自动执行备份。

---

## 远程服务器同步配置

如果想把备份同步到另一台服务器，需要配置 SSH 免密登录。

### 1. 生成 SSH 密钥

在本机执行：

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/my_backup_key
```

然后把生成的 `my_backup_key.pub`​ 复制到远程服务器：

```bash
ssh-copy-id -i ~/.ssh/my_backup_key.pub user@remote_server_ip
```

修改脚本配置：

```bash
enable_ssh_sync=true  # 是否启用 SSH 同步（true/false）
enable_ssh_clean=true  # 是否清理远程服务器上的备份（true/false）
ssh_ip="182.22.13.33"  # 远程服务器 IP
ssh_port=22  # SSH 端口
ssh_user="root"  # 登录远程服务器的用户名
clientPath="/home/backup/mysql/"  # 远程服务器存储路径
```

配置完成后，脚本运行时就能把备份同步到远程服务器了。

---

## 阿里云 OSS 备份配置

### 1. 安装 `ossutil`​

需要安装 ossutil，阿里云有十分完善的文档，点击查看：[安装ossutil](https://help.aliyun.com/zh/oss/developer-reference/install-ossutil2)

> 仅需完成官方文档中的第一步安装 ossutil 使其命令可用即可，不需要执行官方文档中的 `ossutil config`​ 对 ossutil 进行配置

### 2. 创建Bucket

进入 [对象存储OSS - Bucket列表](https://oss.console.aliyun.com/bucket)，创建 Bucket，用于存放数据库备份文件

### 3. 获取阿里云 AccessKey

进入 [阿里云 AccessKey 管理](https://ram.console.aliyun.com/profile/access-keys)，创建 AccessKey 并记录 `AccessKey ID`​ 和 `AccessKey Secret`​。

### 3. 修改脚本配置

```bash
enable_oss_upload=true  # 是否启用 OSS 上传（true/false）
enable_oss_clean=true  # 是否清理阿里云 OSS 上的备份（true/false）
oss_bucket="oss://Bucket名称/想存储的文件夹路径/"  # OSS 目标路径
oss_access_key="your-access-key-id"  # 阿里云 AccessKey
oss_secret_key="your-access-key-secret"  # 阿里云 Secret
oss_endpoint="oss-cn-hangzhou.aliyuncs.com"  # OSS 访问地址，在对应 bucket 的概览中可以看到外网访问的 Endpoint
```

配置完成后，脚本运行时备份文件就会自动上传到 OSS 了。

---

如果有任何问题或改进建议，欢迎提 Issue 或 Fork 进行优化！
