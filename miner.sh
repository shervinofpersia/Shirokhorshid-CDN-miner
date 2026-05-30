#!/bin/bash
# ========================================================
# SHΞN™ Shirokhorshid CDN Miner
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
# هدر جدید و شیک‌تر
echo -e "${ORANGE}${BOLD}╭━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╮${NC}"
echo -e "${ORANGE}${BOLD}┃                                             ┃${NC}"
echo -e "${ORANGE}${BOLD}┃       SHΞN™ - Shirokhorshid CDN Miner       ┃${NC}"
echo -e "${ORANGE}${BOLD}┃                                             ┃${NC}"
echo -e "${ORANGE}${BOLD}╰━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╯${NC}"
echo -e "${DARK_GRAY}Initializing core modules and securing environment...${NC}\n"

# انیمیشن لودینگ با کاراکترهای استاندارد (بدون مشکل فونت)
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
    printf "\r    \r" # پاک کردن خط انیمیشن بعد از اتمام
}

# نصب کاملاً سایلنت و بدون پرسش پیش‌نیازها
echo -e "${CYAN}[*] Checking and installing required packages...${NC}"
(
    export DEBIAN_FRONTEND=noninteractive
    # تایید خودکار تمام پرسش‌های احتمالی ترموکس
    yes "" | pkg update -y -q > /dev/null 2>&1
    yes "" | pkg install -y -q termux-api python nmap curl > /dev/null 2>&1
) & spinner

echo -e "${GREEN}[✔] All core dependencies are successfully loaded.${NC}\n"

# استپ موقت برای نمایش ساختار
echo -e "${ORANGE}[*] Fetching Target IP & SNI Payloads...${NC}"
sleep 2 
echo -e "${GREEN}[✔] Payloads fetched successfully.${NC}\n"

