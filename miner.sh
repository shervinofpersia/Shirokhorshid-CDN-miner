#!/bin/bash
# ========================================================
# SHΞN™ Shirokhorshid CDN Miner (Ultimate Deep Scan)
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

# اسپینر خطی بهینه‌شده برای ترموکس
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

echo -e "${CYAN}[*] Deploying multi-threaded scanning engine...${NC}"

# ---------------------------------------------------------
# تزریق اسکریپت پایتون (اسکن عمیق)
# ---------------------------------------------------------
cat << 'EOF' > cdn_scanner.py
import socket
import ssl
import sys
import concurrent.futures
import time

def print_progress(current, total, found):
    if total == 0: return
    percent = (current / total) * 100
    bar_length = 10 # طول نوار کوتاه‌تر شد تا در صفحه موبایل نشکند
    filled = int(bar_length * current // total)
    bar = '█' * filled + '░' * (bar_length - filled)
    
    # استفاده از کاراکترهای کمتر و فضای خالی برای جلوگیری از باگ لاین جدید در اندروید
    text = f"\r \033[36m[*] Scan:\033[0m [\033[38;5;208m{bar}\033[0m] {percent:.0f}% | \033[32mFound: {found}\033[0m"
    sys.stdout.write(text + " " * 10)
    sys.stdout.flush()

def test_target(ip, sni):
    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE
    
    try:
        start_time = time.time()
        with socket.create_connection((ip, 443), timeout=1.8) as sock:
            with context.wrap_socket(sock, server_hostname=sni) as ssock:
                latency = int((time.time() - start_time) * 1000)
                return ip, sni, latency, True
    except:
        return ip, sni, 0, False

def main():
    try:
        with open('ips.txt', 'r') as f:
            cidrs = [line.strip() for line in f if line.strip()]
        with open('snis.txt', 'r') as f:
            snis = [line.strip() for line in f if line.strip()]
    except Exception:
        print("Error reading payload data.")
        return

    # اسکن عمیق: گام ۸ برای پوشش رنج (حدود ۳۲ آی‌پی از هر ساب‌نت)
    targets = []
    for cidr in cidrs:
        base_ip = ".".join(cidr.split('.')[:3])
        for host in range(1, 254, 8): 
            targets.append(f"{base_ip}.{host}")

    clean_ips = set()
    working_snis = set()
    
    total_tasks = len(targets)
    completed_tasks = 0
    found_count = 0

    print_progress(0, total_tasks, 0)

    # اجرای همزمان روی 100 ترد موازی
    with concurrent.futures.ThreadPoolExecutor(max_workers=100) as executor:
        futures = []
        for i, ip in enumerate(targets):
            sni = snis[i % len(snis)]
            futures.append(executor.submit(test_target, ip, sni))
            
        for future in concurrent.futures.as_completed(futures):
            completed_tasks += 1
            ip, sni, latency, success = future.result()
            
            if success:
                clean_ips.add(ip)
                working_snis.add(sni)
                found_count += 1
                
            print_progress(completed_tasks, total_tasks, found_count)

    print("\n\n\033[32m [✔] Analysis completed successfully.\033[0m\n")

    ip_str = "\n".join(sorted(list(clean_ips))) if clean_ips else "No clean IP found. Retry."
    sni_str = "\n".join(sorted(list(working_snis))) if working_snis else "No valid SNI connection."
    
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
            <span>آی‌پی‌های تمیز و فعال یافت‌شده</span>
            <button class="btn" onclick="copyToClipboard('ip-box', this)">کپی همه IPها</button>
        </div>
        <div id="ip-box" class="box">__IP_LIST__</div>

        <div class="section-title">
            <span>دامنه‌های SNI معتبر متصل‌شده</span>
            <button class="btn btn-sni" onclick="copyToClipboard('sni-box', this)">کپی همه SNIها</button>
        </div>
        <div id="sni-box" class="box" style="color: #00f0ff;">__SNI_LIST__</div>
    </div>
    <footer>  Exclusive SHΞN™ made ☬ Shirokhorshid Pro tools</footer>
    <script>
        function copyToClipboard(id, btn) {
            var text = document.getElementById(id).innerText;
            navigator.clipboard.writeText(text).then(() => {
                var orig = btn.innerText;
                btn.innerText = "کپی شد! ✓";
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
EOF

# اجرای اسکنر عمیق
python cdn_scanner.py

# راه‌اندازی سرور لوکال برای دور زدن محدودیت‌های امنیتی اندروید و نمایش ۱۰۰٪ گرافیکی
if [ -f "shirokhorshid_result.html" ]; then
    echo -e "${ORANGE}[*] Rendering Glassmorphism UI via Localhost...${NC}"
    
    # روشن کردن سرور پایتون در پس‌زمینه
    python -m http.server 8765 > /dev/null 2>&1 &
    SERVER_PID=$!
    
    # باز کردن آدرس سرور به جای فایل مستقیم
    sleep 1.5
    termux-open "http://127.0.0.1:8765/shirokhorshid_result.html"
    
    echo -e "${GREEN}[✔] Dashboard successfully opened in your browser!${NC}"
    echo -e "${CYAN}[!] Press [ CTRL + C ] to close the server when you are done.${NC}\n"
    
    # باز نگه داشتن اسکریپت تا زمانی که کاربر صفحه وب را می‌بیند
    wait $SERVER_PID
else
    echo -e "${CYAN}[!] Error: Web dashboard generation failed.${NC}"
fi

# این بخش بعد از زدن Ctrl+C اجرا می‌شود تا فایل‌های موقت را پاک کند
rm -f cdn_scanner.py ips.txt snis.txt
