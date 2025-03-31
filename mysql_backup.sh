#!/bin/bash
# mysql_backup.sh: backup MySQL databases and keep the newest backups.
# 每天凌晨3:00执行数据库备份
# 0 3 * * * /root/mysql_backup.sh

# ======================= 配置项 =======================

# MySQL 配置
db_user="root"  # MySQL 用户名
db_password="difh47fhwwefd"  # MySQL 密码
db_host="localhost"  # MySQL 服务器地址
backup_dir="/home/backup/mysql/"  # 备份文件存放目录
backup_day=10  # 保留的备份天数
logfile="/var/log/mysql_backup.log"  # 备份日志文件

# 需要备份的数据库
all_db=""  # 例子：all_db="mydb1 mydb2"

# SSH 远程同步（用于备份到其他服务器）
# id_rsa 为本机私钥地址，如果找不到或不确定，可以通过以下命令生成（所有选项都回车）：ssh-keygen -t rsa -b 4096 -f ~/.ssh/my_backup_key
# 记得公钥需要配置到远程服务器上，通常在 ~/.ssh/authorized_keys 中
enable_ssh_sync=false  # 是否启用 SSH 同步（true/false）
enable_ssh_clean=false  # 是否清理远程服务器上的备份（true/false）
ssh_ip="182.22.13.33"  # 远程服务器 IP
ssh_port=22  # SSH 端口
ssh_user="root"  # 登录远程服务器的用户名
clientPath="/home/backup/mysql/"  # 远程服务器存储路径
serverPath=${backup_dir}  # 本地备份目录
id_rsa="/root/.ssh/my_backup_key"  # 本机 SSH 私钥路径

# 阿里云 OSS 备份
enable_oss_upload=false  # 是否启用 OSS 上传（true/false）
enable_oss_clean=false  # 是否清理阿里云 OSS 上的备份（true/false）
oss_bucket="oss://Bucket名称/想存储的文件夹路径/"  # OSS 目标路径
oss_access_key="your-access-key-id"  # 阿里云 AccessKey
oss_secret_key="your-access-key-secret"  # 阿里云 Secret
oss_endpoint="oss-cn-hangzhou.aliyuncs.com"  # OSS 访问地址


# ======================= 初始化 =======================

time="$(date +"%Y-%m-%d")"
now="$(date +"%H%M%S")"

# 命令配置
mysql="/usr/bin/mysql"
mysqldump="/usr/bin/mysqldump"

# 确保备份目录存在
test ! -d ${backup_dir} && mkdir -p ${backup_dir}

# ======================= 备份函数 =======================

# 备份 MySQL 数据库
backup_mysql() {
    echo "====== 开始数据库备份 $(date +'%Y-%m-%d %T') ======" >> ${logfile}

    # 创建当天日期的备份文件夹
    backup_folder="${backup_dir}${time}/"
    test ! -d ${backup_folder} && mkdir -p ${backup_folder}

    # 如果 all_db 为空，则获取所有数据库
    if [[ -z "$all_db" ]]; then
        all_db="$(${mysql} -u ${db_user} -h ${db_host} -p${db_password} -Bse 'SHOW DATABASES' | grep -Ev '(^information_schema$|^performance_schema$|^mysql$|^sys$)')"
    fi

    # 遍历所有数据库并备份
    for db in ${all_db}; do
        backup_name="${db}.${time}.${now}"
        dump_file="${backup_folder}${backup_name}.sql"

        echo "正在备份数据库: ${db}" >> ${logfile}
        ${mysqldump} -F -u${db_user} -h${db_host} -p${db_password} ${db} > ${dump_file} 2>>${logfile}

        # 压缩备份文件
        echo "压缩 ${dump_file}" >> ${logfile}
        tar -czvf "${dump_file}.tar.gz" "${dump_file}" >> ${logfile} 2>&1 && rm "${dump_file}"

        echo "备份完成: ${dump_file}.tar.gz" >> ${logfile}
    done
}

# 删除过期的备份文件夹及内容
delete_old_backups() {
    echo "====== 清理过期备份 $(date +'%Y-%m-%d %T') ======" >> ${logfile}

    # 删除远程备份文件夹
    if [ "$enable_ssh_clean" = true ]; then
        echo "====== 开始删除远程备份 $(date +'%Y-%m-%d %T') ======" >> ${logfile}
        
        for folder in $(find ${backup_dir} -type d -mtime +${backup_day} -name "20*"); do
            remote_folder="${folder/${backup_dir}/}"
            ssh -p ${ssh_port} -i ${id_rsa} -o StrictHostKeyChecking=no ${ssh_user}@${ssh_ip} "rm -rf ${clientPath}${remote_folder}" >> ${logfile} 2>&1
            echo "已删除远程备份: ${remote_folder}" >> ${logfile}
        done

        echo "====== 远程备份删除完成 $(date +'%Y-%m-%d %T') ======" >> ${logfile}
    fi

    # 删除 OSS 备份文件夹
    if [ "$enable_oss_clean" = true ]; then
        echo "====== 开始删除 OSS 备份 $(date +'%Y-%m-%d %T') ======" >> ${logfile}

        for folder in $(find ${backup_dir} -type d -mtime +${backup_day} -name "20*"); do
            oss_folder="${folder/${backup_dir}/}"
            ossutil rm -r ${oss_bucket}${oss_folder} -f >> ${logfile} 2>&1
            echo "已删除 OSS 备份: ${oss_folder}" >> ${logfile}
        done

        echo "====== OSS 备份删除完成 $(date +'%Y-%m-%d %T') ======" >> ${logfile}
    fi
    
    # 删除本地备份文件夹
    find ${backup_dir} -type d -mtime +${backup_day} -name "20*" | tee delete_local_list.log | xargs rm -rf
    cat delete_local_list.log >> ${logfile}
}


# 远程同步到其他服务器
sync_to_remote() {
    if [ "$enable_ssh_sync" = true ]; then
        echo "====== 开始同步到远程服务器 $(date +'%Y-%m-%d %T') ======" >> ${logfile}
        
        # 创建目标目录（如果不存在）
        ssh -p ${ssh_port} -i ${id_rsa} -o StrictHostKeyChecking=no ${ssh_user}@${ssh_ip} "mkdir -p ${clientPath}${time}" >> ${logfile} 2>&1
        
        # 执行 rsync 同步
        rsync -avz --progress --delete ${backup_dir}${time}/ -e "ssh -p ${ssh_port} -i ${id_rsa} -o StrictHostKeyChecking=no" ${ssh_user}@${ssh_ip}:${clientPath}${time} >> ${logfile} 2>&1

        echo "====== 远程同步完成 $(date +'%Y-%m-%d %T') ======" >> ${logfile}
    fi
}

# 上传到阿里云 OSS
upload_to_aliyun_oss() {
    if [ "$enable_oss_upload" = true ]; then
        echo "====== 开始上传到阿里云 OSS $(date +'%Y-%m-%d %T') ======" >> ${logfile}

        for file in ${backup_folder}*.tar.gz; do
            ossutil cp -f /${file} ${oss_bucket}${time}/ \
                --access-key-id=${oss_access_key} \
                --access-key-secret=${oss_secret_key} \
                --endpoint=${oss_endpoint} >> ${logfile} 2>&1
            
            echo "已上传到 OSS: ${oss_bucket}${time}/$(basename ${file})" >> ${logfile}
        done

        echo "====== 阿里云 OSS 上传完成 $(date +'%Y-%m-%d %T') ======" >> ${logfile}
    fi
}

# ======================= 执行备份流程 =======================

cd ${backup_dir}

backup_mysql
delete_old_backups
sync_to_remote
upload_to_aliyun_oss

echo "====== 所有任务完成 $(date +'%Y-%m-%d %T') ======" >> ${logfile}
