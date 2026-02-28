🚀 Alpine Cloudflare DDNS
一个专为 Alpine Linux 和 BusyBox 环境设计的轻量化 Cloudflare 动态域名解析（DDNS）工具。
### 🌟 项目亮点
极致轻量：纯 sh 编写，无 Bash 依赖，完美适配容器及嵌入式设备。
安全优先：原生支持 Cloudflare API Token，无需暴露全局密钥。
智能更新：内置本地缓存机制，仅在 IP 变动时调用 API，规避速率限制。
全栈支持：完美支持 IPv4 (A) 与 IPv6 (AAAA) 双栈解析。
## ⚡ 快速开始
1. 一键安装 (推荐)
在终端执行以下命令即可完成环境检查、下载及权限设置：

Bash


apk add curl && \
curl -sSL https://raw.githubusercontent.com/blassck/alpine_cf-ddns/main/alpine_cf-ddns.sh -o /usr/local/bin/cf-ddns && \
chmod +x /usr/local/bin/cf-ddns


2. 配置参数
你可以通过修改脚本内置变量或使用环境变量。主要配置项如下：
变量名
说明
示例
CFTOKEN
推荐：Cloudflare API 令牌
zh-xxxxxxxxxxxxxxxx
CFRECORD_NAME
完整域名 (FQDN)
ddns.example.com
CFZONE_NAME
根域名
example.com
CFRECORD_TYPE
记录类型
A 或 AAAA
WANIPSITE
获取公网 IP 的接口
https://4.icanhazip.com

## 🛠 进阶用法
自动化：设置 Cron 定时任务
建议每 5-10 分钟运行一次。执行 crontab -e 并添加：

Bash


# 每 5 分钟静默执行一次
*/5 * * * * /usr/local/bin/cf-ddns >/dev/null 2>&1

# 若需保留日志以供排错
*/5 * * * * /usr/local/bin/cf-ddns >> /var/log/cf-ddns.log 2>&1


IPv6 专用配置
若需更新 IPv6 记录，请确保 CFRECORD_TYPE 设为 AAAA，并建议更换 IP 获取地址：

Bash


cf-ddns -t "your_token" -h "ipv6.example.com" -z "example.com"
# 内部建议将 WANIPSITE 修改为 https://6.icanhazip.com


## 🔍 运行逻辑示意图
## ❓ 常见问题 (FAQ)
Q: 为什么提示 curl: not found?
A: Alpine 默认不带 curl。请先执行 apk add curl。
Q: 我应该给 API Token 哪些权限？
A: 为了安全，请仅授予：
Zone - Zone - Read
Zone - DNS - Edit
Resources - Include - Specific Zone - [你的域名]
Q: 脚本支持 Docker 吗？
A: 绝配！你可以直接在 Dockerfile 中 FROM alpine:latest 并打包此脚本，或者挂载到现有的 Alpine 容器中。
## 📜 开源协议
本项目基于 MIT License 开源。欢迎提交 Pull Request 以增强兼容性。
