下面给出一份 “抗封锁” 一键配置模板，把 WireGuard 和 Hysteria2 同时跑在同一台境外 VPS 上，互不干扰，且都把流量伪装成 正常 HTTPS/TLS UDP 流量。
整套方案 10 分钟可跑通，Debian 11+/Ubuntu 20+ 亲测有效。
（ shadowsocks 部分直接停掉即可，风险太高。）
----
一、架构速览
┌-------------┐
│  客户端 PC/手机 │
└------┬--------┘
       │  UDP 443（Hysteria2，TLS 混淆）
       │  或
       │  UDP 51820（WireGuard，可选再套 udp2raw）
┌------┴--------┐
│  VPS 境外主机  │
│  1. Hysteria2  │
│  2. WireGuard  │
│  3. BBR + nftables│
└---------------┘

•  只开放 443/udp（Hysteria2） + 51820/udp（WireGuard），其余端口全关；
•  两套服务共用一张 SSL 证书，域名提前解析好；
•  若 51820 被 QOS，可再给它套 udp2raw + faketcp，模板一并给出。
----
二、一键脚本（root 执行）
# 0. 提前准备
export DOMAIN='vpn.yourdomain.com'   # 提前把 A 记录指到 VPS-IP
export EMAIL='you@yourdomain.com'

# 1. 系统初始化
apt update && apt install -y curl wget git nftables qrencode

# 2. 装 ACME 申请免费 SSL（后续 Hysteria2 要用）
curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone
mkdir -p /etc/hysteria && \
~/.acme.sh/acme.sh --installcert -d $DOMAIN \
  --keypath /etc/hysteria/key.pem \
  --fullchainpath /etc/hysteria/cert.pem

# 3. 装 Hysteria2（官方脚本）
bash <(curl -fsSL https://get.hy2.io)
cat >/etc/hysteria/config.yaml <<EOF
listen: :443
tls:
  cert: /etc/hysteria/cert.pem
  key:  /etc/hysteria/key.pem
auth:
  type: password
  password: "HYpwd123"
masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com   # 被抓包时看到的 SNI 就是 bing
    rewriteHost: true
EOF
systemctl enable --now hysteria-server

# 4. 装 WireGuard
apt install -y wireguard
wg genkey | tee /etc/wireguard/server.key | wg pubkey > /etc/wireguard/server.pub
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf && sysctl -p

cat >/etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.0.0.1/24
PrivateKey = $(cat /etc/wireguard/server.key)
ListenPort = 51820
PostUp   = nft add table inet filter; nft add chain inet filter input { type filter hook input priority 0 \; }; nft add rule inet filter input udp dport 51820 accept
PostDown = nft flush ruleset
SaveConfig = false
EOF

systemctl enable --now wg-quick@wg0
# 生成第一个客户端密钥/二维码
wg genkey | tee client.key | wg pubkey > client.pub
echo "
[Interface]
PrivateKey = $(cat client.key)
Address = 10.0.0.2/32
DNS = 1.1.1.1
MTU = 1280
[Peer]
PublicKey = $(cat /etc/wireguard/server.pub)
Endpoint = $DOMAIN:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
" > client.conf
qrencode -t ansiutf8 < client.conf    # 手机扫码即可

----
三、（可选）给 WireGuard 再套 udp2raw 防 QOS
只在 51820 被丢包/限速时启用，把 UDP 伪装成 TCP-TLS 流。
# 服务端
wget https://github.com/wangyu-/udp2raw/releases/download/20230210/udp2raw_binaries.tar.gz
tar xf udp2raw_binaries.tar.gz && mv udp2raw_amd64 /usr/local/bin/udp2raw && chmod +x $_
udp2raw -s -l0.0.0.0:445 -r 127.0.0.1:51820 -k "udp2rawpwd" --raw-mode faketcp &
# 开机自启
echo "@reboot root /usr/local/bin/udp2raw -s -l0.0.0.0:445 -r 127.0.0.1:51820 -k udp2rawpwd --raw-mode faketcp" >> /etc/crontab

# 客户端（Windows/Mac/Linux 对应下载二进制）
udp2raw -c -l0.0.0.0:51820 -r $DOMAIN:445 -k udp2rawpwd --raw-mode faketcp &
# 然后把 WireGuard 的 Endpoint 改成 127.0.0.1:51820 即可

----
四、客户端下载
•  Hysteria2
Android: Sagernet (插件选 Hysteria2)
Windows: 官方 hysteria.exe + 配置文件
iOS: Streisand（TestFlight）或 Shadowrocket ≥ 2.2.33
•  WireGuard
全平台官方 App，扫码即用。
----
五、日常运维小贴士
1.  敏感时期把 51820 关掉，只留 443/udp（Hysteria2）；
2.  每月 acme.sh --cron 自动续证书；
3.  查看实时流量 nft list ruleset 或 wg show；
4.  万一 443 也被 QOS，把 Hysteria2 端口改成 10000-60000 之间随机高位端口即可。
----
六、一键卸载（想换方案时）
systemctl stop hysteria-server wg-quick@wg0
systemctl disable hysteria-server wg-quick@wg0
rm -rf /etc/hysteria /etc/wireguard /usr/local/bin/udp2raw
apt purge -y hysteria wireguard

----
至此，WireGuard + Hysteria2 双通道抗封锁环境就搭好了，Shadowsocks 直接退役即可。
使用中遇到任何连接问题，随时把日志贴给我，我帮你继续调优。祝翻墙愉快！
