# 🚀 Cloudflare DDNS for Alpine Linux

这是一个专为 Alpine Linux、BusyBox 及 Docker 环境优化的 Cloudflare 动态域名解析（DDNS）脚本。基于 [yulewang/cloudflare-api-v4-ddns](https://github.com/yulewang/cloudflare-api-v4-ddns) 改编，剔除了对 Bash 的依赖，完全使用 POSIX sh 编写。

---

## 📖 目录

- [特性](#-特性)
- [快速开始](#-快速开始)
- [配置详解](#-配置详解)
- [获取 Cloudflare API Token](#-获取-cloudflare-api-token)
- [使用方法](#-使用方法)
- [自动化任务 (Cron)](#-自动化任务-cron)
- [技术细节对比](#-技术细节对比)
- [故障排查](#-故障排查)

---

## ✨ 特性

- **极简依赖**：仅需 `curl`，无需 Bash，完美适配超精简系统
- **安全认证**：支持 API Token（限定权限，推荐）及 Global API Key
- **智能更新**：本地缓存 Zone ID、Record ID 和 IP 地址，仅在 IP 变动时请求 API，避免触发频率限制
- **全栈解析**：完美支持 IPv4 (A) 与 IPv6 (AAAA)
- **日志友好**：提供详细的执行日志与错误提示

---

## ⚡ 快速开始

### 1. 安装依赖

```bash
apk add curl
```

### 2. 下载并赋权

```bash
curl -o /usr/local/bin/alpine_cf-ddns.sh https://raw.githubusercontent.com/blassck/alpine_cf-ddns/refs/heads/main/alpine_cf-ddns.sh
chmod +x /usr/local/bin/alpine_cf-ddns.sh
```

### 3. 编辑配置

```bash
vi /usr/local/bin/alpine_cf-ddns.sh
```

---

## ⚙️ 配置详解

在脚本中修改以下变量：

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `CFTOKEN` | 首选。Cloudflare API 令牌 | `zh-xxxxxxxxxxxxxxxx` |
| `CFKEY` | 备选。Global API Key (不推荐) | `1a2b3c4d5e6f...` |
| `CFUSER` | Cloudflare 账号邮箱 | `user@example.com` |
| `CFZONE_NAME` | 你的主域名 (根域名) | `example.com` |
| `CFRECORD_NAME` | 需要解析的子域名 | `ddns.example.com` |
| `CFRECORD_TYPE` | 记录类型 | `A` (IPv4) 或 `AAAA` (IPv6) |
| `WANIPSITE` | 获取公网 IP 的接口 | `https://4.icanhazip.com` |

---

## 🔑 获取 Cloudflare API Token

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com)
2. 点击右上角头像 → **My Profile** → **API Tokens** → **Create Token**
3. 选择 **Edit zone DNS** 模板或手动配置：
   - **Permissions**: `Zone:Read` (读取) 和 `DNS:Edit` (编辑)
   - **Zone Resources**: Include → Specific zone → 选择你的域名
4. 复制生成的 Token 填入 `CFTOKEN`

---

## 🚀 使用方法

### 手动触发

```bash
# 基本运行
/usr/local/bin/alpine_cf-ddns.sh

# 强制更新（无视缓存）
/usr/local/bin/alpine_cf-ddns.sh -f true

# 命令行覆盖配置
/usr/local/bin/alpine_cf-ddns.sh -t "TOKEN" -h "home.example.com" -z "example.com"
```

### 自动化（Cron）

建议每 5 分钟执行一次：

```bash
crontab -e
# 添加以下行
*/5 * * * * /usr/local/bin/alpine_cf-ddns.sh >> /var/log/cf-ddns.log 2>&1
```

---

## 🔍 技术细节对比

| 特性 | 原版 (yulewang) | Alpine 版 (本项目) |
|------|-----------------|-------------------|
| 解释器 | Bash | POSIX sh (BusyBox) |
| 认证方式 | Global API Key | Token / Global Key |
| JSON 解析 | `grep -P` (依赖 PCRE) | `sed` (纯原生工具流) |
| IP 校验 | 无 | 正则格式校验 |
| IPv6 | 支持 | 支持 |

---

## 🛠 故障排查

### DNS 解析错误 (transient error)

Alpine 默认 DNS 可能不稳定。尝试修复：

```bash
echo "nameserver 1.1.1.1" > /etc/resolv.conf
```

### 权限错误 (Authentication Error)

检查 API Token 是否有 `DNS:Edit` 权限，且是否关联了正确的域名。

### 找不到记录

本脚本不会自动新建解析记录。请先在 Cloudflare 后台手动创建一个 A 记录（IP 随便填），脚本随后会自动接管。

### IPv6 更新失败

确保 `CFRECORD_TYPE="AAAA"` 且 `WANIPSITE` 使用支持 IPv6 的地址（如 `https://6.icanhazip.com`）。

---

## 📜 开源协议

基于 MIT License 开源。
