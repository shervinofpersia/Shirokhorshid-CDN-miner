#!/bin/bash
# ========================================================
# SHΞN™ Shirokhorshid CDN Miner (Smart CIDR Scan)
# Developer: Shervin Nouri
# GitHub: https://github.com/shervinofpersia/Shirokhorshid-CDN-miner
# ========================================================

CYAN='\e[0;36m'
ORANGE='\e[38;5;208m'
GREEN='\e[0;32m'
DARK_GRAY='\e[1;30m'
NC='\e[0m'
BOLD='\e[1m'

clear
echo -e "${ORANGE}${BOLD}╭━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╮${NC}"
echo -e "${ORANGE}${BOLD}┃                                             ┃${NC}"
echo -e "${ORANGE}${BOLD}┃       SHΞN™ - Shirokhorshid CDN Miner       ┃${NC}"
echo -e "${ORANGE}${BOLD}┃                                             ┃${NC}"
echo -e "${ORANGE}${BOLD}╰━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╯${NC}"
echo -e "${DARK_GRAY}Securing environment and checking core infrastructure...${NC}\n"

spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "\r \033[36m[%c]\033[0m Installing requirements...    " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r                                           \r"
}

export DEBIAN_FRONTEND=noninteractive
(
    yes "" | pkg update -y -q > /dev/null 2>&1
    yes "" | pkg install -y -q termux-api python curl > /dev/null 2>&1
) & spinner

echo -e "${GREEN}[✔] System optimized and dependencies are ready.${NC}"

echo -e "${ORANGE}[*] Fetching latest unique payloads from GitHub...${NC}"
curl -s https://raw.githubusercontent.com/shervinofpersia/Shirokhorshid-CDN-miner/main/ips.txt -o ips.txt
curl -s https://raw.githubusercontent.com/shervinofpersia/Shirokhorshid-CDN-miner/main/snis.txt -o snis.txt

if [ -f "ips.txt" ] && [ -s "ips.txt" ] && [ -f "snis.txt" ] && [ -s "snis.txt" ]; then
    IP_COUNT=$(wc -l < ips.txt)
    SNI_COUNT=$(wc -l < snis.txt)
    echo -e "${GREEN}[✔] Loaded ${IP_COUNT} CIDRs and ${SNI_COUNT} SNIs.${NC}\n"
else
    echo -e "${CYAN}[!] Critical Error: Payload sync failed.${NC}"
    exit 1
fi

echo -e "${CYAN}[*] Deploying adaptive scanning engine...${NC}"

cat << 'PYEOF' > cdn_scanner.py
import socket
import ssl
import sys
import concurrent.futures
import time
import ipaddress
import random

MAX_TARGETS_PER_CIDR = 64   # حداکثر تعداد IP که از هر ساب‌نت اسکن می‌شود
MAX_TOTAL_TARGETS = 5000     # کل سقف اسکن برای جلوگیری از هنگ کردن

def print_progress(current, total, found):
    if total == 0:
        return
    percent = (current / total) * 100
    bar_length = 10
    filled = int(bar_length * current // total)
    bar = '█' * filled + '░' * (bar_length - filled)
    line = f"  [*] Scan: [{bar}] {percent:.0f}% | Found: {found}"
    sys.stdout.write('\r' + ' ' * 90 + '\r' + line)
    sys.stdout.flush()

def generate_targets(cidr_lines):
    targets = []
    for line in cidr_lines:
        line = line.strip()
        if not line:
            continue
        try:
            # اگر خط خودش IP تکی باشد
            if '/' not in line:
                ip = ipaddress.ip_address(line)
                targets.append(str(ip))
                continue
            # CIDR
            net = ipaddress.ip_network(line, strict=False)
            hosts = list(net.hosts())
            if not hosts:
                continue
            total_hosts = len(hosts)
            if total_hosts <= MAX_TARGETS_PER_CIDR:
                step = 1
            else:
                step = max(1, total_hosts // MAX_TARGETS_PER_CIDR)
            # انتخاب اولین و سپس با گام جلو می‌رویم
            chosen = hosts[::step]
            # اگر خیلی زیاد بود باز هم محدود می‌کنیم
            if len(chosen) > MAX_TARGETS_PER_CIDR:
                chosen = random.sample(hosts, MAX_TARGETS_PER_CIDR)
            targets.extend([str(ip) for ip in chosen])
        except Exception:
            # خط خراب را نادیده می‌گیریم
            continue
    # اگه از سقف کلی بیشتر شد، به صورت تصادفی نمونه برداری کن
    if len(targets) > MAX_TOTAL_TARGETS:
        random.shuffle(targets)
        targets = targets[:MAX_TOTAL_TARGETS]
    return targets

def test_target(ip, sni):
    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE
    try:
        start = time.time()
        with socket.create_connection((ip, 443), timeout=1.8) as sock:
            with context.wrap_socket(sock, server_hostname=sni) as ssock:
                lat = int((time.time() - start) * 1000)
                return ip, sni, lat, True
    except:
        return ip, sni, 0, False

def main():
    try:
        with open('ips.txt', 'r') as f:
            cidrs = [line.strip() for line in f if line.strip()]
        with open('snis.txt', 'r') as f:
            snis = [line.strip() for line in f if line.strip()]
    except Exception as e:
        print(f"Error reading payload data: {e}")
        return

    targets = generate_targets(cidrs)
    if not targets:
        print("No valid targets generated. Check ips.txt format.")
        return

    clean_ips = set()
    working_snis = set()
    total = len(targets)
    completed = 0
    found = 0

    print_progress(0, total, 0)

    with concurrent.futures.ThreadPoolExecutor(max_workers=100) as executor:
        futures = {}
        for i, ip in enumerate(targets):
            sni = snis[i % len(snis)]
            futures[executor.submit(test_target, ip, sni)] = (ip, sni)

        for future in concurrent.futures.as_completed(futures):
            completed += 1
            ip, sni, latency, success = future.result()
            if success:
                clean_ips.add(ip)
                working_snis.add(sni)
                found += 1
            print_progress(completed, total, found)

    print("\n\n\033[32m [✔] Analysis completed successfully.\033[0m\n")

    ip_str = "\n".join(sorted(clean_ips)) if clean_ips else "No clean IP found. Retry."
    sni_str = "\n".join(sorted(working_snis)) if working_snis else "No valid SNI connection."

    html_template = """<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SHΞN™ Shirokhorshid CDN Results</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, sans-serif; }
        body { 
            background: #030305; 
            color: #e2e8f0; 
            padding: 20px; 
            display: flex; 
            flex-direction: column; 
            align-items: center; 
            min-height: 100vh; 
        }
        .container { 
            width: 100%; 
            max-width: 600px; 
            background: rgba(255, 255, 255, 0.01); 
            backdrop-filter: blur(20px); 
            -webkit-backdrop-filter: blur(20px);
            border: 1px solid rgba(255, 255, 255, 0.05); 
            border-radius: 24px; 
            padding: 30px; 
            box-shadow: 0 24px 50px rgba(0,0,0,0.8), inset 0 1px 0 rgba(255,255,255,0.05); 
        }
        h1 { text-align: center; font-size: 24px; color: #ff7a00; margin-bottom: 5px; text-shadow: 0 0 20px rgba(255,122,0,0.3); font-weight: 800; }
        .subtitle { text-align: center; font-size: 11px; color: #00f0ff; margin-bottom: 35px; letter-spacing: 2px; font-weight: bold; }
        .section-title { font-size: 13px; color: #94a3b8; margin-bottom: 12px; display: flex; justify-content: space-between; align-items: center; font-weight: 600; }
        .box { 
            background: rgba(0, 0, 0, 0.5); 
            border: 1px solid rgba(255, 255, 255, 0.03); 
            border-radius: 14px; 
            padding: 15px; 
            max-height: 200px; 
            overflow-y: auto; 
            font-family: 'Courier New', monospace; 
            font-size: 13px; 
            color: #00ffcc; 
            line-height: 1.8; 
            margin-bottom: 30px; 
            white-space: pre-line; 
            text-align: left; 
            direction: ltr; 
        }
        .btn { 
            background: linear-gradient(135deg, #ff7a00, #ff4500); 
            border: none; 
            color: white; 
            padding: 8px 18px; 
            font-size: 12px; 
            font-weight: bold;
            border-radius: 10px; 
            cursor: pointer; 
            transition: all 0.2s ease;
            box-shadow: 0 4px 15px rgba(255,122,0,0.2);
        }
        .btn:hover { transform: translateY(-1px); box-shadow: 0 6px 20px rgba(255,122,0,0.4); }
        .btn-sni { background: linear-gradient(135deg, #00b8ff, #0055ff); box-shadow: 0 4px 15px rgba(0,184,255,0.2); }
        .btn-sni:hover { box-shadow: 0 6px 20px rgba(0,184,255,0.4); }
        footer { margin-top: 25px; text-align: center; font-size: 10px; color: #475569; letter-spacing: 0.5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>SHΞN™ SHIROKHORSHID</h1>
        <div class="subtitle">CLEAN CDN FRONTING TARGETS</div>

        <div class="section-title">
            <span>Clean IPs Found</span>
            <button class="btn" onclick="copyToClipboard('ip-box', this)">Copy All IPs</button>
        </div>
        <div id="ip-box" class="box">__IP_LIST__</div>

        <div class="section-title">
            <span>Valid SNIs</span>
            <button class="btn btn-sni" onclick="copyToClipboard('sni-box', this)">Copy All SNIs</button>
        </div>
        <div id="sni-box" class="box" style="color: #00f0ff;">__SNI_LIST__</div>
    </div>
    <footer>Exclusive SHΞN™ made ☬ Shirokhorshid Pro tools</footer>
    <script>
        function copyToClipboard(id, btn) {
            var text = document.getElementById(id).innerText;
            navigator.clipboard.writeText(text).then(() => {
                var orig = btn.innerText;
                btn.innerText = "Copied! ✓";
                btn.style.filter = "brightness(1.2)";
                setTimeout(() => { 
                    btn.innerText = orig; 
                    btn.style.filter = "none";
                }, 1500);
            });
        }
    </script>
</body>
</html>"""
    
    html_content = html_template.replace("__IP_LIST__", ip_str).replace("__SNI_LIST__", sni_str)
    
    with open('shirokhorshid_result.html', 'w', encoding='utf-8') as f:
        f.write(html_content)

if __name__ == '__main__':
    main()
PYEOF

python cdn_scanner.py

if [ -f "shirokhorshid_result.html" ]; then
    echo -e "${ORANGE}[*] Rendering Glassmorphism UI via Localhost...${NC}"

    python - << 'SRVEOF' &
import http.server
import os

RESULT_FILE = "shirokhorshid_result.html"

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/", "/index.html", "/shirokhorshid_result.html"):
            self.send_response(200)
            self.send_header("Content-type", "text/html; charset=utf-8")
            self.end_headers()
            with open(RESULT_FILE, "rb") as f:
                self.wfile.write(f.read())
        else:
            super().do_GET()

    def log_message(self, format, *args):
        pass  # suppress logs

server = http.server.HTTPServer(("127.0.0.1", 8765), Handler)
server.serve_forever()
SRVEOF
    SERVER_PID=$!
    sleep 0.5

    termux-open "http://127.0.0.1:8765/shirokhorshid_result.html" 2>/dev/null

    if ! kill -0 $SERVER_PID 2>/dev/null; then
        echo -e "${CYAN}[!] Server could not start. Opening directly...${NC}"
        termux-open --view "file://$(realpath shirokhorshid_result.html)" 2>/dev/null || \
        echo -e "${CYAN}[!] Please open manually: file://$(realpath shirokhorshid_result.html)${NC}"
    else
        echo -e "${GREEN}[✔] Dashboard opened. Press Ctrl+C to exit server.${NC}"
        wait $SERVER_PID
    fi
else
    echo -e "${CYAN}[!] HTML dashboard generation failed.${NC}"
fi

rm -f cdn_scanner.py ips.txt snis.txt
