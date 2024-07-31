#!/bin/bash

# 确保脚本在 Bash 解释器下执行
set -e

# 获取脚本所在目录的绝对路径
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# 创建存放日志文件的目录，如果不存在的话
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

# 获取当前时间的毫秒级时间戳，并格式化为年月日时分秒形式，使用东八区时间
TIMESTAMP=$(TZ=Asia/Shanghai date +"%Y-%m-%d_%H-%M-%S.%3N")

# 日志文件路径，包含精确到毫秒的时间戳，并保存在 logs 目录下
LOG_FILE="$LOG_DIR/upgrade-$TIMESTAMP.log"

# 定义日志输出函数，包含时间戳和级别
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(TZ=Asia/Shanghai date +"%Y-%m-%d %H:%M:%S.%3N")
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# 查找当前目录下的所有 Docker Compose YAML 文件
CONFIG_FILES=$(find "$SCRIPT_DIR" -maxdepth 1 -type f \( -name "*.yaml" -o -name "*.yml" \))

# 遍历每个配置文件并进行升级操作
for file in $CONFIG_FILES
do
    log_message "INFO" "====================================================================="
    log_message "INFO" "当前配置文件: $file"
    log_message "INFO" "开始升级 $file..."

    # 拉取最新的镜像并输出到终端和日志文件
    log_message "INFO" "拉取最新的镜像..."
    if docker compose -f "$file" pull -q 2>&1 | tee -a "$LOG_FILE"; then
        log_message "INFO" "镜像拉取成功."
    else
        log_message "ERROR" "镜像拉取失败."
        continue  # 继续下一个配置文件的升级
    fi

    # 重新创建容器并移除孤立的容器
    log_message "INFO" "重新创建容器并移除孤立的容器..."
    if docker compose -f "$file" up -d --remove-orphans | tee -a "$LOG_FILE"; then
        log_message "INFO" "容器重新创建成功."
    else
        log_message "ERROR" "容器重新创建失败."
        continue  # 继续下一个配置文件的升级
    fi

    log_message "INFO" "$file 升级完成."
done
log_message "INFO" "所有配置文件升级完成."
log_message "INFO" "====================================================================="
log_message "INFO" "开始清理未使用的 Docker 镜像..."

# 清理未使用的镜像
docker image prune -a -f | tee -a "$LOG_FILE"

# 检查是否有清理操作的错误
if [ $? -eq 0 ]; then
  log_message "INFO" "未使用的 Docker 镜像已成功清理。"
else
  log_message "ERROR" "清理未使用的 Docker 镜像时发生错误。"
fi
