🚀 Alpine Cloudflare DDNS (POSIX Shell 版)
这是一个专为 Alpine Linux、BusyBox 及 Docker 环境优化的 Cloudflare 动态域名解析（DDNS）脚本。基于 yulewang/cloudflare-api-v4-ddns 改编，剔除了对 Bash 的依赖，完全兼容 POSIX 标准。
📖 目录
特性
环境准备
安装步骤
配置详解
使用方法
自动化任务 (Cron)
原理说明
故障排查
## 特性
✅ 超轻量：仅依赖 curl，脚本体积 < 10KB。
✅ 多认证支持：支持最新的 API Token（限定权限，更安全）和传统的 Global API Key。
✅ 双栈支持：支持 IPv4 (A 记录) 和 IPv6 (AAAA 记录)。
✅ 智能减压：对比本地缓存 IP，仅在公网 IP 变动时请求 Cloudflare API。
✅ 静默运行：支持命令行参数模式，方便脚本化调用。
## 环境准备
在使用脚本前，请确保系统已安装 curl。在 Alpine Linux 上执行：

Bash


apk add --no-cache curl


## 安装步骤
下载脚本：
Bash
curl -sSL https://raw.githubusercontent.com/blassck/alpine_cf-ddns/main/alpine_cf-ddns.sh -o /usr/local/bin/alpine_cf-ddns.sh
chmod +x /usr/local/bin/alpine_cf-ddns.sh


获取 Cloudflare API Token (推荐)：
进入 Cloudflare 控制面板 -> My Profile -> API Tokens。
点击 Create Token -> 使用 Edit zone DNS 模板。
权限需包含：Zone:Read 和 DNS:Edit。
资源范围选定你的特定域名。
## 配置详解
使用 vi /usr/local/bin/alpine_cf-ddns.sh 编辑以下关键变量：
变量名
默认值
详细说明
CFTOKEN
""
首选。填写你的 API Token。若填写此项，则无需填写下方的 Key 和 User。
CFKEY
""
备选。Global API Key。不建议在生产环境使用。
CFUSER
""
配合 Global Key 使用的 Cloudflare 账号邮箱。
CFZONE_NAME
example.com
你的主域名（根域名）。
CFRECORD_NAME
ddns.example.com
你想要指向动态 IP 的完整域名。
CFRECORD_TYPE
A
解析类型。IPv4 填 A，IPv6 填 AAAA。
WANIPSITE
https://4.icanhazip.com
用于检测本机公网 IP 的接口。IPv6 建议用 https://6.icanhazip.com。

## 使用方法
### 手动运行

Bash


# 使用脚本内的配置文件运行
/usr/local/bin/alpine_cf-ddns.sh

# 强制更新（忽略本地 IP 缓存直接同步至 Cloudflare）
/usr/local/bin/alpine_cf-ddns.sh -f true


### 命令行参数模式
你可以在不修改脚本文件的情况下直接运行，这对于在一台机器上更新多个域名非常有用：

Bash


/usr/local/bin/alpine_cf-ddns.sh -t "YOUR_TOKEN" -h "home.example.com" -z "example.com"


## 自动化任务 (Cron)
使用 crontab -e 设定定时任务，实现无人值守更新：

Bash


# 每 5 分钟检查一次 IP
*/5 * * * * /usr/local/bin/alpine_cf-ddns.sh >> /var/log/cf-ddns.log 2>&1


## 原理说明
获取公网 IP：通过 WANIPSITE 定义的接口获取本机当前 IP。
本地对比：检查 /root/.cf-wan_ip_<hostname>.txt（或脚本定义的路径）中的记录。如果一致，直接退出。
API 交互：
获取 Zone ID：通过域名查询所属的区域 ID。
获取 Record ID：查询该子域名的唯一记录 ID。
提交更新：发送 PUT 请求至 Cloudflare API，更新解析记录。
持久化：更新本地缓存文件，记录日志。
## 故障排查
curl: (6) Could not resolve host：
Alpine 的 DNS 配置问题。请检查 /etc/resolv.conf，建议添加 nameserver 1.1.1.1。
Authentication Error：
请确认 Token 权限是否包含 Zone:Read。如果是用 Global Key，请确保 CFUSER 邮箱填写正确。
Record not found：
脚本不会自动创建解析记录。请先在 Cloudflare 后台手动创建一个子域名的 A 记录（IP 随便填），脚本随后会自动接管它。
📜 开源协议
本项目采用 MIT License。
