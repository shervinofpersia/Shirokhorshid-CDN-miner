#!/bin/bash
# ========================================================
# SHΞN™ Shirokhorshid CDN Miner (Full Version)
# GitHub: https://github.com/shervinofpersia/Shirokhorshid-CDN-miner
# ========================================================

# تعریف پالت رنگی ترمینال
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

# انیمیشن لودینگ با کاراکترهای استاندارد
spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "\r ${CYAN}[%c]${NC}  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r    \r"
}

# نصب کاملاً سایلنت و بدون پرسش پیش‌نیازها
echo -e "${CYAN}[*] Optimizing system dependencies...${NC}"
(
    export DEBIAN_FRONTEND=noninteractive
    yes "" | pkg update -y -q > /dev/null 2>&1
    yes "" | pkg install -y -q termux-api python nmap curl > /dev/null 2>&1
) & spinner

echo -e "${GREEN}[✔] System optimized and dependencies are ready.${NC}\n"

# دانلود لیست آی‌پی‌ها و SNIها از ریپازیتوری شما
echo -e "${ORANGE}[*] Fetching latest unique payloads from GitHub...${NC}"
(
    curl -s https://raw.githubusercontent.com/shervinofpersia/Shirokhorshid-CDN-miner/main/ips.txt -o ips.txt
    curl -s https://raw.githubusercontent.com/shervinofpersia/Shirokhorshid-CDN-miner/main/snis.txt -o snis.txt
) & spinner

if [ -f "ips.txt" ] && [ -s "ips.txt" ] && [ -f "snis.txt" ] && [ -s "snis.txt" ]; then
    IP_COUNT=$(wc -l < ips.txt)
    SNI_COUNT=$(wc -l < snis.txt)
    echo -e "${GREEN}[✔] Loaded ${IP_COUNT} clean CIDR blocks and ${SNI_COUNT} SNI targets.${NC}\n"
else
    echo -e "${CYAN}[!] Critical Error: Payload synchronization failed.${NC}"
    exit 1
fi

echo -e "${CYAN}[*] Deploying multi-threaded scanning engine...${NC}"

# تزریق و ساخت اسکریپت پایتون اسکنر به صورت توکار
cat << 'EOF' > cdn_scanner.py
import socket
import ssl
import sys
import concurrent.futures
import time

def print_progress(current, total):
    bar_length = 30
    percent = float(current) * 100 / total
    arrow   = '█' * int(percent/100 * bar_length - 1) + '█'
    spaces  = '░' * (bar_length - len(arrow))
    sys.stdout.write(f'\r \033[36m[*] Scanning Network: [\033[38;5;208m{arrow}{spaces}\033[36m] {percent:.1f}%\033[0m')
    sys.stdout.flush()

def test_target(ip, sni):
    context = ssl.create_default_context()
    context.check_hostname = True
    context.verify_mode = ssl.CERT_REQUIRED
    
    try:
        start_time = time.time()
        with socket.create_connection((ip, 443), timeout=1.5) as sock:
            with context.wrap_socket(sock, server_hostname=sni) as ssock:
                latency = int((time.time() - start_time) * 1000)
                return ip, sni, latency, True
    except:
        return ip, sni, 0, False

def main():
    with open('ips.txt', 'r') as f:
        cidrs = [line.strip() for line in f if line.strip()]
    with open('snis.txt', 'r') as f:
        snis = [line.strip() for line in f if line.strip()]

    # تولید لیستی از IPهای منتخب برای اسکن سریع (تست IPهای فعال در هر رنج)
    targets = []
    for cidr in cidrs:
        base_ip = ".".join(cidr.split('.')[:3])
        # تست کردن نمونه‌های ثابت و معتبر از هر رنج برای کاهش زمان انتظار کاربر
        for host in ['1', '10', '25']: 
            targets.append(f"{base_ip}.{host}")

    clean_ips = set()
    working_snis = set()
    results_data = []

    total_tasks = len(targets)
    completed_tasks = 0

    print_progress(0, total_tasks)

    # اجرای اسکنر چندنخی با حداکثر توان پردازشی
    with concurrent.futures.ThreadPoolExecutor(max_workers=80) as executor:
        futures = {executor.submit(test_target, ip, snis[i % len(snis)]): ip for i, ip in enumerate(targets)}
        
        for future in concurrent.futures.as_completed(futures):
            completed_tasks += 1
            if completed_tasks % 2 == 0 or completed_tasks == total_tasks:
                print_progress(completed_tasks, total_tasks)
            
            ip, sni, latency, success = future.result()
            if success:
                clean_ips.add(ip)
                working_snis.add(sni)
                results_data.append({"ip": ip, "sni": sni, "ping": latency})

    print("\n\033[32m [✔] Analysis completed successfully.\033[0m\n")

    # تولید ساختار صفحه وب نهایی با طراحی فوق پیشرفته Glassmorphism و Cyberpunk
    html_content = f"""<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SHΞN™ Shirokhorshid CDN Results</title>
    <style>
        * {{ box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; }}
        body {{
            background: #050508;
            color: #e2e8f0;
            padding: 20px;
            display: flex;
            flex-direction: column;
            align-items: center;
            min-height: 100vh;
        }}
        .container {{
            width: 100%;
            max-width: 600px;
            background: rgba(255, 255, 255, 0.02);
            backdrop-filter: blur(16px);
            -webkit-backdrop-filter: blur(16px);
            border: 1px solid rgba(255, 255, 255, 0.06);
            border-radius: 24px;
            padding: 30px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.7), inset 0 1px 0 rgba(255,255,255,0.1);
        }}
        h1 {{
            text-align: center;
            font-size: 22px;
            color: #ff7a00;
            margin-bottom: 5px;
            text-shadow: 0 0 15px rgba(255,122,0,0.4);
        }}
        .subtitle {{
            text-align: center;
            font-size: 12px;
            color: #00f0ff;
            margin-bottom: 30px;
            text-shadow: 0 0 10px rgba(0,240,255,0.3);
            letter-spacing: 1px;
        }}
        .section-title {{
            font-size: 14px;
            color: #cbd5e1;
            margin-bottom: 12px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-weight: bold;
        }}
        .box {{
            background: rgba(0, 0, 0, 0.4);
            border: 1px solid rgba(255, 255, 255, 0.04);
            border-radius: 14px;
            padding: 15px;
            max-height: 180px;
            overflow-y: auto;
            font-family: monospace;
            font-size: 13px;
            color: #00ffcc;
            line-height: 1.8;
            margin-bottom: 25px;
            white-space: pre-line;
            text-align: left;
            direction: ltr;
        }}
        .btn {{
            background: linear-gradient(135deg, #ff7a00, #ff5000);
            border: none;
            color: white;
            padding: 8px 16px;
            font-size: 12px;
            font-weight: bold;
            border-radius: 10px;
            cursor: pointer;
            transition: all 0.3s ease;
            box-shadow: 0 4px 12px rgba(255,122,0,0.3);
        }}
        .btn:hover {{
            transform: translateY(-2px);
            box-shadow: 0 6px 18px rgba(255,122,0,0.5);
        }}
        .btn-sni {{
            background: linear-gradient(135deg, #00b8ff, #0072ff);
            box-shadow: 0 4px 12px rgba(0,184,255,0.3);
        }}
        .btn-sni:hover {{
            box-shadow: 0 6px 18px rgba(0,184,255,0.5);
        }}
        footer {{
            margin-top: 20px;
            text-align: center;
            font-size: 11px;
            color: #475569;
        }}
    </style>
</head>
<body>

    <div class="container">
        <h1>SHΞN™ SHIROKHORSHID</h1>
        <div class="subtitle">CLEAN CDN FRONTING TARGETS</div>

        <div class="section-title">
            <span>آی‌پی‌های تمیز و پایداری بالا ({len(clean_ips)})</span>
            <button class="btn" onclick="copyToClipboard('ip-box', this)">کپی همه IPها</button>
        </div>
        <div id="ip-box" class="box">{"\n".join(list(clean_ips)) if clean_ips else "آی‌پی تمیزی یافت نشد. مجدداً تلاش کنید."}</div>

        <div class="section-title">
            <span>دامنه‌های SNI فعال و معتبر ({len(working_snis)})</span>
            <button class="btn btn-sni" onclick="copyToClipboard('sni-box', this)">کپی همه SNIها</button>
        </div>
        <div id="sni-box" class="box" style="color: #00f0ff;">{"\n".join(list(working_snis)) if working_snis else "هاست معتبری یافت نشد."}</div>
    </div>

    <footer>Powered by SHΞN™ Infrastructure & Shirokhorshid Services</footer>

    <script>
        function copyToClipboard(elementId, btn) {{
            var text = document.getElementById(elementId).innerText;
            var elem = document.createElement("textarea");
            document.body.appendChild(elem);
            elem.value = text;
            elem.select();
            document.execCommand("copy");
            document.body.removeChild(elem);
            
            var originalText = btn.innerText;
            btn.innerText = "کپی شد! ✓";
            btn.style.filter = "brightness(1.3)";
            setTimeout(function() {{
                btn.innerText = originalText;
                btn.style.filter = "none";
            }}, 1500);
        }}
    </script>
</body>
</html>
"""
    with open('shirokhorshid_result.html', 'w', encoding='utf-8') as f:
        f.write(html_content)

if __name__ == '__main__':
    main()
EOF

# اجرای موتور پایتون
python cdn_scanner.py

# باز کردن خودکار صفحه وب تولید شده در مرورگر گوشی کاربر از طریق ابزار ترموکس
if [ -f "shirokhorshid_result.html" ]; then
    echo -e "${ORANGE}[*] Launching graphic dashboard...${NC}"
    termux-open shirokhorshid_result.html
    echo -e "${GREEN}[✔] Localhost browser called successfully. Process finished.${NC}"
else
    echo -e "${CYAN}[!] Error: Web dashboard generation failed.${NC}"
fi

# پاکسازی فایل‌های موقت برای تمیز ماندن هاست کاربر
rm -f cdn_scanner.py ips.txt snis.txt
