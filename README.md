# Cloudflare DDNS for Alpine Linux

Alpine Linux 兼容的 Cloudflare 动态域名解析脚本，支持 IPv4/IPv6，使用 POSIX sh 编写，无需 bash。

## 特性

- ✅ Alpine Linux / BusyBox 完全兼容
- ✅ 支持 **API Token**（推荐）和 **Global API Key** 两种认证方式
- ✅ 支持 IPv4 (A记录) 和 IPv6 (AAAA记录)
- ✅ IP 变化检测，减少不必要的 API 调用
- ✅ Zone ID 和 Record ID 本地缓存
- ✅ 详细的日志记录
- ✅ 自动补全域名后缀

## 安装

### 1. 安装依赖

```bash
apk add curl
### 2. 下载脚本
curl -o /usr/local/bin/alpine_cf-ddns.sh https://raw.githubusercontent.com/blassck/alpine_cf-ddns/refs/heads/main/alpine_cf-ddns.sh
chmod +x /usr/local/bin/alpine_cf-ddns.sh
### 3. 编辑配置
vi /usr/local/bin/alpine_cf-ddns.sh
修改以下配置项：
# 方式一：使用 API Token（推荐，更安全）
CFTOKEN="your-api-token-here"
CFUSER=""  # 留空

# 方式二：使用 Global API Key
CFKEY="your-global-api-key"
CFUSER="your-email@example.com"

# 域名配置
CFZONE_NAME="example.com"           # 你的主域名
CFRECORD_NAME="ddns.example.com"    # 要更新的子域名
CFRECORD_TYPE="A"                   # A(IPv4) 或 AAAA(IPv6)
获取 Cloudflare API Token
1.	登录 Cloudflare Dashboard
2.	点击右上角头像 → My Profile → API Tokens → Create Token
3.	使用模板 “Edit zone DNS” 或手动创建权限：
–	Zone:Read（读取区域信息）
–	DNS:Edit（编辑 DNS 记录）
### 4.	Zone Resources: Include - Specific zone - your-domain.com
### 5.	复制生成的 Token，填入脚本的 CFTOKEN 变量
使用方法
手动运行
# 使用配置文件中的参数
/usr/local/bin/alpine_cf-ddns.sh

# 强制更新（无视 IP 是否变化）
/usr/local/bin/alpine_cf-ddns.sh -f true

# 命令行传入参数（覆盖配置文件）
/usr/local/bin/alpine_cf-ddns.sh -t "your-token" -h "sub.example.com" -z "example.com"
命令行参数
参数	说明	示例
-k	Global API Key	-k 1234567890abcdef
-u	邮箱地址（配合 Global Key）	-u user@example.com
-t	API Token（推荐）	-t abcdef123456
-h	主机名（子域名）	-h ddns.example.com
-z	主域名（Zone）	-z example.com
-f	强制更新	-f true
设置定时任务（Cron）
# 编辑 crontab
crontab -e

# 每 5 分钟检查一次（推荐）
*/5 * * * * /usr/local/bin/ >/dev/null 2>&1

# 或带日志记录
*/5 * * * * /usr/local/bin/alpine_cf-ddns.sh >> /var/log/cf-ddns.log 2>&1
查看日志
# 实时查看
tail -f /var/log/cf-ddns.log

# 查看最近记录
tail -n 50 /var/log/cf-ddns.log
日志示例
[2024-01-15 09:00:01] 获取当前公网 IP...
[2024-01-15 09:00:02] 当前公网 IP: 203.0.113.45
[2024-01-15 09:00:02] IP 未变化 (203.0.113.45)，跳过更新

[2024-01-15 09:05:01] 获取当前公网 IP...
[2024-01-15 09:05:02] 当前公网 IP: 203.0.113.88
[2024-01-15 09:05:02] 获取 Zone ID for example.com...
[2024-01-15 09:05:03] Zone ID: 1a2b3c4d5e6f...
[2024-01-15 09:05:03] 获取 Record ID for ddns.example.com...
[2024-01-15 09:05:03] Record ID: 7g8h9i0j1k2l...
[2024-01-15 09:05:03] 更新 DNS 记录 ddns.example.com -> 203.0.113.88
[2024-01-15 09:05:04] ✓ DNS 更新成功: ddns.example.com -> 203.0.113.88
文件说明
文件路径	说明
/usr/local/bin/alpine_cf-ddns.shh	脚本主体
/root/.cf-wan_ip_<hostname>.txt	上次更新的 IP 缓存
/root/.cf-id_<hostname>.txt	Zone ID 和 Record ID 缓存
/var/log/cf-ddns.log	运行日志
IPv6 支持
修改配置：
CFRECORD_TYPE="AAAA"
WANIPSITE="https://ipv6.icanhazip.com"
或使用命令行参数：
/usr/local/bin/alpine_cf-ddns.sh -t "token" -h "ipv6.example.com" -z "example.com"
# 然后修改脚本内 CFRECORD_TYPE="AAAA"
故障排查
DNS 解析错误
如果看到 DNS: transient error，先修复 Alpine DNS：
echo "nameserver 223.5.5.5" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
权限错误
确保脚本可执行：
chmod +x /usr/local/bin/alpine_cf-ddns.sh
API 认证失败
检查 Token/Key 是否正确，Token 需要以下权限： - Zone:Read - DNS:Edit
找不到记录
确保域名已添加到 Cloudflare，且存在对应类型的 DNS 记录（可以随便填个 IP，脚本会更新它）。
与原版脚本的区别
特性	原版 (yulewang)	Alpine 版
Shell	Bash	POSIX sh (BusyBox 兼容)
认证方式	Global API Key	API Token + Global Key
JSON 解析	grep -P (PCRE)	sed (兼容 BusyBox)
IP 验证	无	正则格式校验
日志	stdout	文件日志 + stdout
IPv6	支持	支持
开源协议
### MIT License
致谢
基于 yulewang/cloudflare-api-v4-ddns 改编，适配 Alpine Linux。 ```
这个 Markdown 文档包含了： - 完整的安装配置指南 - API Token 获取步骤 - 命令行参数说明 - Cron 定时任务设置 - 日志查看方法 - IPv6 配置 - 故障排查 - 与原版脚本的对比
