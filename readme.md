# monddns

强大易用的ddns脚本

## 🤔为什么选择monddns

- ✅支持多个账号的多个域名与多个ip间的绑定
- ✅支持单子域名多A/AAAA记录
- (未来将)支持多个服务商

  - ~~好吧这事实上取决于我本人使用什么服务商~~
  - ~~主要是lua的sdk真没人给啊~~
- ✅支持多种ip获取方式，支持一次获取多个ip

  - 未来还可以方便地扩展
- ✅依赖精简，按需加载

## ☁️目前支持的服务商

- Cloudflare
- NameSilo
- 阿里云

## 🛠️目前支持的ip获取方式

- http/https
- 命令获取
- 固定值

## 📦依赖

**环境依赖：** Lua5.1或者更高(但是仅在lua5.1和lua5.4上进行测试)

**全局依赖：** `cjson`、`LuaSocket`

### 额外的依赖

仅在使用以下模块/功能时需要

- Cloudflare

  - ltn12
- 阿里云

  - ltn12
  - basexx
  - luaossl.hmac
  - ~~喜欢自研签名~~

## 🚀部署

首先将项目克隆到本地

`git clone https://github.com/Yue-bin/monddns.git && cd monddns`

然后选择你喜欢的配置文件格式，检查对应的example并完成配置。

运行时会按照如下顺序查找配置文件：

```
config.{format}
~/.config/monddns/config.{format}
/usr/local/etc/monddns/config.{format}
/etc/monddns/config.{format}
```

如果使用 `-c`或者 `--conf`选项手动指定配置文件，则会直接使用指定的配置文件

最后使用cron等定时任务来完成部署
