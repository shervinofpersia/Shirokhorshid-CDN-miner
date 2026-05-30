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

echo -e "${CYAN}[✔] System optimized and dependencies are ready.${NC}"

echo -e "${ORANGE}[*] Fetching latest unique payloads from GitHub...${NC}"
curl -s https://raw.githubusercontent.com/shervinofpersia/Shirokhorshid-CDN-miner/main/ips.txt -o ips.txt
curl -s https://raw.githubusercontent.com/shervinofpersia/Shirokhorshid-CDN-miner/main/snis.txt -o snis.txt

if [ -f "ips.txt" ] && [ -s "ips.txt" ] && [ -f "snis.txt" ] && [ -s "snis.txt" ]; then
    IP_COUNT=$(wc -l < ips.txt)
    SNI_COUNT=$(wc -l < snis.txt)
    echo -e "${CYAN}[✔] Loaded ${IP_COUNT} CIDRs and ${SNI_COUNT} SNIs.${NC}\n"
else
    echo -e "${CYAN}[!] Critical Error: Payload sync failed.${NC}"
    exit 1
fi

echo
echo -e "${CYAN}[*] Deploying adaptive scanning engine...${NC}"

cat << 'PYEOF' > cdn_scanner.py
import socket
import ssl
import sys
import concurrent.futures
import time
import ipaddress
import random

MAX_TARGETS_PER_CIDR = 64
MAX_TOTAL_TARGETS = 5000

def print_progress(current, total, found, first=False):
    if total == 0:
        return
    percent = (current / total) * 100
    bar_length = 10
    filled = int(bar_length * current // total)
    bar = '█' * filled + '░' * (bar_length - filled)
    if not first:
        sys.stdout.write('\033[2A')
    sys.stdout.write('\033[K')
    sys.stdout.write(f"\033[36m  [*] Scan: [{bar}] {percent:.0f}% \033[0m\n")
    sys.stdout.write('\033[K')
    sys.stdout.write(f"\033[36m  Found: {found} valid IPs\033[0m\n")
    sys.stdout.flush()

def generate_targets(cidr_lines):
    targets = []
    for line in cidr_lines:
        line = line.strip()
        if not line:
            continue
        try:
            if '/' not in line:
                ip = ipaddress.ip_address(line)
                targets.append(str(ip))
                continue
            net = ipaddress.ip_network(line, strict=False)
            hosts = list(net.hosts())
            if not hosts:
                continue
            total_hosts = len(hosts)
            step = 1 if total_hosts <= MAX_TARGETS_PER_CIDR else max(1, total_hosts // MAX_TARGETS_PER_CIDR)
            chosen = hosts[::step]
            if len(chosen) > MAX_TARGETS_PER_CIDR:
                chosen = random.sample(hosts, MAX_TARGETS_PER_CIDR)
            targets.extend([str(ip) for ip in chosen])
        except:
            continue
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

    print_progress(0, total, 0, first=True)

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

    sys.stdout.write('\033[2A\033[J')
    print("\n\033[36m [✔] Analysis completed successfully.\033[0m\n")

    ip_str = "\n".join(sorted(clean_ips)) if clean_ips else "No clean IP found. Retry."
    sni_str = "\n".join(sorted(working_snis)) if working_snis else "No valid SNI connection."

    html_template = """<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SHΞN™ Shirokhorshid CDN Results</title>
    <style>
        * { 
            box-sizing: border-box; 
            margin: 0; 
            padding: 0; 
            font-family: 'Segoe UI', Tahoma, sans-serif; 
        }
        body { 
            background: linear-gradient(135deg, #0a0a0c 0%, #1c1c21 100%); 
            color: #d1d5db; 
            padding: 20px; 
            display: flex; 
            flex-direction: column; 
            align-items: center; 
            min-height: 100vh; 
        }
        .container { 
            width: 100%; 
            max-width: 650px; 
            background: rgba(20, 20, 25, 0.6); 
            backdrop-filter: blur(16px); 
            -webkit-backdrop-filter: blur(16px);
            border: 1px solid rgba(255, 122, 0, 0.15); 
            border-radius: 20px; 
            padding: 30px; 
            box-shadow: 0 20px 40px rgba(0,0,0,0.9), inset 0 1px 0 rgba(255,122,0,0.1); 
        }
        h1 { 
            text-align: center; 
            font-size: 26px; 
            color: #ff7a00; 
            margin-bottom: 5px; 
            text-shadow: 0 0 15px rgba(255,122,0,0.5); 
            font-weight: 900; 
            letter-spacing: 1px;
        }
        .subtitle { 
            text-align: center; 
            font-size: 11px; 
            color: #9ca3af; 
            margin-bottom: 35px; 
            letter-spacing: 3px; 
            font-weight: bold; 
        }
        .section-title { 
            font-size: 14px; 
            color: #e5e7eb; 
            margin-bottom: 12px; 
            display: flex; 
            justify-content: space-between; 
            align-items: center; 
            font-weight: 700; 
            border-bottom: 1px solid rgba(255, 122, 0, 0.2);
            padding-bottom: 8px;
        }
        .button-group {
            display: flex;
            gap: 8px;
        }
        .box { 
            background: #0d0d10; 
            border: 1px solid #33333b; 
            border-radius: 12px; 
            padding: 18px; 
            max-height: 220px; 
            overflow-y: auto; 
            font-family: 'Courier New', monospace; 
            font-size: 13.5px; 
            line-height: 1.9; 
            margin-bottom: 35px; 
            white-space: pre-line; 
            text-align: left; 
            direction: ltr; 
            box-shadow: inset 0 4px 10px rgba(0,0,0,0.5);
        }
        #ip-box { 
            color: #39ff14; 
            text-shadow: 0 0 5px rgba(57, 255, 20, 0.3);
        }
        #sni-box { 
            color: #00f0ff; 
            text-shadow: 0 0 5px rgba(0, 240, 255, 0.3);
        }
        .btn { 
            background: #1f1f26; 
            border: 1px solid #ff7a00; 
            color: #ff7a00; 
            padding: 6px 14px; 
            font-size: 11px; 
            font-weight: bold;
            border-radius: 8px; 
            cursor: pointer; 
            transition: all 0.3s ease;
        }
        .btn:hover { 
            background: #ff7a00; 
            color: #000; 
            box-shadow: 0 0 15px rgba(255,122,0,0.5); 
        }
        .btn-download {
            background: linear-gradient(135deg, #ff7a00, #d96500);
            border: none;
            color: white;
            padding: 7px 14px;
            font-size: 11px;
            font-weight: bold;
            border-radius: 8px;
            cursor: pointer;
            transition: all 0.3s ease;
            box-shadow: 0 4px 10px rgba(255,122,0,0.2);
        }
        .btn-download:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 18px rgba(255,122,0,0.5);
        }
        ::-webkit-scrollbar { width: 6px; }
        ::-webkit-scrollbar-track { background: #0d0d10; border-radius: 10px; }
        ::-webkit-scrollbar-thumb { background: #ff7a00; border-radius: 10px; }

        footer { 
            margin-top: 25px; 
            text-align: center; 
            font-size: 11px; 
            letter-spacing: 0.5px; 
        }
        footer a {
            color: #9ca3af;
            text-decoration: none;
            transition: all 0.3s ease;
        }
        footer a strong {
            color: #ff7a00;
        }
        footer a:hover {
            color: #e5e7eb;
            text-shadow: 0 0 10px rgba(255,122,0,0.5);
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>SHΞNoKHORSHID</h1>
        <div class="subtitle">CLEAN CDN FRONTING TARGETS</div>

        <div class="section-title">
            <span>E2E Pass IPs</span>
            <div class="button-group">
                <button class="btn" onclick="copyToClipboard('ip-box', this)">Copy</button>
                <button class="btn-download" onclick="downloadTxt('ip-box', 'SHEN_Clean_IPs.txt')">Download.txt</button>
            </div>
        </div>
        <div id="ip-box" class="box">__IP_LIST__</div>

        <div class="section-title">
            <span>Valid SNIs</span>
            <div class="button-group">
                <button class="btn" onclick="copyToClipboard('sni-box', this)">Copy</button>
                <button class="btn-download" onclick="downloadTxt('sni-box', 'SHEN_Valid_SNIs.txt')">Download.txt</button>
            </div>
        </div>
        <div id="sni-box" class="box">__SNI_LIST__</div>
    </div>
    
    <footer>
        <a href="https://t.me/shervini" target="_blank">
            Exclusive <strong>SHΞN™</strong> made ☬ Shirokhorshid Pro Tools
        </a>
    </footer>

    <script>
        function copyToClipboard(id, btn) {
            var text = document.getElementById(id).innerText;
            var tempTextArea = document.createElement("textarea");
            tempTextArea.value = text;
            document.body.appendChild(tempTextArea);
            tempTextArea.select();
            document.execCommand("copy");
            document.body.removeChild(tempTextArea);
            
            var orig = btn.innerText;
            btn.innerText = "Copied! ✓";
            setTimeout(() => { 
                btn.innerText = orig; 
            }, 1500);
        }

        function downloadTxt(id, filename) {
            var text = document.getElementById(id).innerText;
            if (text.includes("No clean IP") || text.includes("No valid SNI")) {
                alert("Nothing to download yet!");
                return;
            }
            var element = document.createElement('a');
            element.setAttribute('href', 'data:text/plain;charset=utf-8,' + encodeURIComponent(text));
            element.setAttribute('download', filename);
            element.style.display = 'none';
            document.body.appendChild(element);
            element.click();
            document.body.removeChild(element);
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

    # ★★★ قسمت اصلاح‌شده ★★★
    PORT_FILE=$(mktemp)
    python - << 'SRVEOF' > "$PORT_FILE" 2>&1 &
import http.server, socketserver, os

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
        pass

with socketserver.TCPServer(("127.0.0.1", 0), Handler) as httpd:
    port = httpd.server_address[1]
    print(port)   # این خط پورت رو توی فایل موقت می‌نویسه
    httpd.serve_forever()
SRVEOF

    SERVER_PID=$!
    sleep 0.8

    # خوندن پورت از فایل موقت
    PORT=$(cat "$PORT_FILE" 2>/dev/null)
    rm -f "$PORT_FILE"

    if [ -n "$PORT" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        termux-open "http://127.0.0.1:${PORT}/shirokhorshid_result.html" 2>/dev/null
        echo -e "${CYAN}[✔] Dashboard opened on port ${PORT}. Press Ctrl+C to exit server.${NC}"
        wait $SERVER_PID
    else
        echo -e "${CYAN}[!] Server could not start. Opening directly...${NC}"
        HTML_FILE="$PWD/shirokhorshid_result.html"
        termux-open --view "file://${HTML_FILE}" 2>/dev/null || \
        echo -e "${CYAN}[!] Please open manually: file://${HTML_FILE}${NC}"
    fi
else
    echo -e "${CYAN}[!] HTML dashboard generation failed.${NC}"
fi

rm -f cdn_scanner.py ips.txt snis.txt
