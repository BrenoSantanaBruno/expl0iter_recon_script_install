#!/bin/bash

# Recon Toolset Installation Script v4.0
# Enhanced with proper dependency management and error handling

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
INSTALL_DIR="/opt"
GO_BIN_PATH="/usr/local/bin"
PYTHON_REQUIREMENTS="requirements.txt"
LOG_FILE="recon_install.log"

# Banner
echo -e "${BLUE}
███████╗██╗  ██╗██████╗ ██╗      ██████╗ ██╗████████╗███████╗██████╗
██╔════╝╚██╗██╔╝██╔══██╗██║     ██╔═████╗██║╚══██╔══╝██╔════╝██╔══██╗
█████╗   ╚███╔╝ ██████╔╝██║     ██║██╔██║██║   ██║   █████╗  ██████╔╝
██╔══╝   ██╔██╗ ██╔═══╝ ██║     ████╔╝██║██║   ██║   ██╔══╝  ██╔══██╗
███████╗██╔╝ ██╗██║     ███████╗╚██████╔╝██║   ██║   ███████╗██║  ██║
╚══════╝╚═╝  ╚═╝╚═╝     ╚══════╝ ╚═════╝ ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝
${NC}"
echo -e "${YELLOW}RECON TOOLSET v4.0 - Refactored Installation Script${NC}"
echo -e "${YELLOW}--------------------------------------------------${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[!] Please run as root${NC}"
    exit 1
fi

# Create log file
echo -e "${BLUE}[*] Starting installation - logging to ${LOG_FILE}${NC}"
echo "Recon Toolset Installation Log" > $LOG_FILE
echo "Started at: $(date)" >> $LOG_FILE

# Function to log messages
log() {
    echo -e "$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${1//\\033\[[0-9;]*m/}" >> $LOG_FILE
}

# Function to install system dependencies
install_dependencies() {
    log "${BLUE}[*] Installing system dependencies${NC}"

    apt update &>> $LOG_FILE

    local dependencies=(
        "git" "curl" "wget" "jq" "xargs" "python3" "python3-pip" "python3-dev"
        "libpcap-dev" "libssl-dev" "build-essential" "cmake" "ruby"
        "unzip" "nmap" "dnsutils" "whois" "libffi-dev" "zlib1g-dev"
    )

    for dep in "${dependencies[@]}"; do
        if ! dpkg -l | grep -q "^ii  $dep "; then
            log "${YELLOW}[+] Installing $dep${NC}"
            apt install -y $dep &>> $LOG_FILE
            if [ $? -ne 0 ]; then
                log "${RED}[!] Failed to install $dep${NC}"
            fi
        else
            log "${GREEN}[*] $dep already installed${NC}"
        fi
    done

    # Install Go if not present
    if ! command -v go &> /dev/null; then
        log "${BLUE}[*] Installing Go${NC}"
        wget https://golang.org/dl/go1.21.0.linux-amd64.tar.gz -O /tmp/go.tar.gz &>> $LOG_FILE
        tar -C /usr/local -xzf /tmp/go.tar.gz &>> $LOG_FILE
        export PATH=$PATH:/usr/local/go/bin
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
        source ~/.bashrc
    else
        log "${GREEN}[*] Go already installed: $(go version)${NC}"
    fi
}

# Function to install Go tools
install_go_tools() {
    local tools=(
        "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
        "github.com/projectdiscovery/httpx/cmd/httpx@latest"
        "github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest"
        "github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
        "github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
        "github.com/projectdiscovery/katana/cmd/katana@latest"
        "github.com/ffuf/ffuf@latest"
        "github.com/hakluke/hakrawler@latest"
        "github.com/jaeles-project/gospider@latest"
        "github.com/tomnomnom/assetfinder@latest"
        "github.com/lc/gau/v2/cmd/gau@latest"
        "github.com/tomnomnom/waybackurls@latest"
        "github.com/projectdiscovery/chaos-client/cmd/chaos@latest"
        "github.com/hakluke/hakrevdns@latest"
        "github.com/tomnomnom/qsreplace@latest"
        "github.com/haccer/subjack@latest"
        "github.com/lc/subjs@latest"
        "github.com/Emoe/kxss@latest"
        "github.com/tomnomnom/unfurl@latest"
        "github.com/tomnomnom/anew@latest"
        "github.com/tomnomnom/gf@latest"
        "github.com/003random/getJS@latest"
        "github.com/anshumanbh/tko-subs@latest"
        "github.com/dwisiswant0/crlfuzz/cmd/crlfuzz@latest"
        "github.com/jaeles-project/jaeles@latest"
        "github.com/ferreiraklet/airixss@latest"
        "github.com/projectdiscovery/notify/cmd/notify@latest"
        "github.com/projectdiscovery/uncover/cmd/uncover@latest"
        "github.com/projectdiscovery/mapcidr/cmd/mapcidr@latest"
        "github.com/projectdiscovery/tlsx/cmd/tlsx@latest"
        "github.com/projectdiscovery/alterx/cmd/alterx@latest"
    )

    log "${BLUE}[*] Installing Go tools${NC}"

    for tool in "${tools[@]}"; do
        tool_name=$(basename $(echo $tool | cut -d'@' -f1))
        if command -v $tool_name &> /dev/null; then
            log "${GREEN}[*] $tool_name already installed${NC}"
            continue
        fi

        log "${YELLOW}[+] Installing $tool_name${NC}"
        go install $tool &>> $LOG_FILE

        if [ $? -eq 0 ]; then
            # Move binary to /usr/local/bin if not there
            if [ -f ~/go/bin/$tool_name ]; then
                mv ~/go/bin/$tool_name $GO_BIN_PATH/
                log "${GREEN}[+] $tool_name installed to $GO_BIN_PATH${NC}"
            else
                log "${RED}[!] $tool_name binary not found after installation${NC}"
            fi
        else
            log "${RED}[!] Failed to install $tool_name${NC}"
        fi
    done

    # Install tools that need special handling
    special_go_tools
}

# Special Go tools that need custom installation
special_go_tools() {
    # Kiterunner
    if ! command -v kr &> /dev/null; then
        log "${YELLOW}[+] Installing kiterunner${NC}"
        git clone https://github.com/assetnote/kiterunner.git $INSTALL_DIR/kiterunner &>> $LOG_FILE
        cd $INSTALL_DIR/kiterunner
        make build &>> $LOG_FILE
        ln -s $INSTALL_DIR/kiterunner/dist/kr /usr/local/bin/kr
        log "${GREEN}[+] kiterunner installed${NC}"
    fi

    # Arjun
    if ! command -v arjun &> /dev/null; then
        log "${YELLOW}[+] Installing Arjun${NC}"
        pip3 install arjun &>> $LOG_FILE
        log "${GREEN}[+] Arjun installed${NC}"
    fi
}

# Function to install Python tools
install_python_tools() {
    local tools=(
        "https://github.com/obheda12/GitDorker.git"
        "https://github.com/0x240x23elu/JSScanner.git"
        "https://github.com/xnl-h4ck3r/xnLinkFinder.git"
        "https://github.com/xnl-h4ck3r/waymore.git"
        "https://github.com/s0md3v/Photon.git"
        "https://github.com/s0md3v/XSStrike.git"
        "https://github.com/m4ll0k/SecretFinder.git"
        "https://github.com/UnaPibaGeek/ctfr.git"
        "https://github.com/GerbenJavado/LinkFinder.git"
    )

    log "${BLUE}[*] Installing Python tools${NC}"

    for tool in "${tools[@]}"; do
        tool_name=$(basename $tool .git)

        if [ -d "$INSTALL_DIR/$tool_name" ]; then
            log "${YELLOW}[*] Updating $tool_name${NC}"
            cd "$INSTALL_DIR/$tool_name"
            git pull &>> $LOG_FILE
        else
            log "${YELLOW}[+] Installing $tool_name${NC}"
            git clone $tool "$INSTALL_DIR/$tool_name" &>> $LOG_FILE
        fi

        # Install Python dependencies if requirements.txt exists
        if [ -f "$INSTALL_DIR/$tool_name/requirements.txt" ]; then
            pip3 install -r "$INSTALL_DIR/$tool_name/requirements.txt" &>> $LOG_FILE
        fi

        # Create symlinks for commonly used tools
        case $tool_name in
            "XSStrike")
                ln -sf "$INSTALL_DIR/XSStrike/xsstrike.py" /usr/local/bin/xsstrike
                ;;
            "LinkFinder")
                cd "$INSTALL_DIR/LinkFinder" && python3 setup.py install &>> $LOG_FILE
                ;;
            "SecretFinder")
                ln -sf "$INSTALL_DIR/SecretFinder/SecretFinder.py" /usr/local/bin/secretfinder
                ;;
        esac

        log "${GREEN}[+] $tool_name installed/updated${NC}"
    done

    # Install Sublist3r separately due to its requirements
    if [ ! -d "$INSTALL_DIR/Sublist3r" ]; then
        log "${YELLOW}[+] Installing Sublist3r${NC}"
        git clone https://github.com/aboul3la/Sublist3r.git $INSTALL_DIR/Sublist3r &>> $LOG_FILE
        pip3 install -r $INSTALL_DIR/Sublist3r/requirements.txt &>> $LOG_FILE
        ln -sf "$INSTALL_DIR/Sublist3r/sublist3r.py" /usr/local/bin/sublist3r
        log "${GREEN}[+] Sublist3r installed${NC}"
    fi
}

# Function to install additional tools
install_special_tools() {
    log "${BLUE}[*] Installing special tools${NC}"

    # Findomain
    if ! command -v findomain &> /dev/null; then
        log "${YELLOW}[+] Installing Findomain${NC}"
        curl -LO https://github.com/Findomain/Findomain/releases/latest/download/findomain-linux.zip &>> $LOG_FILE
        unzip findomain-linux.zip -d $GO_BIN_PATH &>> $LOG_FILE
        chmod +x $GO_BIN_PATH/findomain
        rm findomain-linux.zip
        log "${GREEN}[+] Findomain installed${NC}"
    fi

    # Dirsearch
    if [ ! -d "$INSTALL_DIR/dirsearch" ]; then
        log "${YELLOW}[+] Installing Dirsearch${NC}"
        git clone https://github.com/maurosoria/dirsearch.git $INSTALL_DIR/dirsearch &>> $LOG_FILE
        ln -sf "$INSTALL_DIR/dirsearch/dirsearch.py" /usr/local/bin/dirsearch
        log "${GREEN}[+] Dirsearch installed${NC}"
    fi

    # Sudomy
    if [ ! -d "$INSTALL_DIR/Sudomy" ]; then
        log "${YELLOW}[+] Installing Sudomy${NC}"
        git clone --recursive https://github.com/screetsec/Sudomy.git $INSTALL_DIR/Sudomy &>> $LOG_FILE
        pip3 install -r $INSTALL_DIR/Sudomy/requirements.txt &>> $LOG_FILE
        ln -sf "$INSTALL_DIR/Sudomy/sudomy" /usr/local/bin/sudomy
        log "${GREEN}[+] Sudomy installed${NC}"
    fi

    # GF patterns
    log "${YELLOW}[+] Setting up GF patterns${NC}"
    mkdir -p ~/.gf
    if [ -d "$INSTALL_DIR/tomnomnom/gf" ]; then
        cp -r $INSTALL_DIR/tomnomnom/gf/examples ~/.gf
    fi
    log "${GREEN}[+] GF patterns configured${NC}"
}

# Main installation function
main() {
    install_dependencies
    install_go_tools
    install_python_tools
    install_special_tools

    # Ask about Axiom
    read -p "[?] Install Axiom? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "${YELLOW}[+] Installing Axiom${NC}"
        bash <(curl -s https://raw.githubusercontent.com/pry0cc/axiom/master/interact/axiom-configure)
        log "${GREEN}[+] Axiom installed${NC}"
    fi

    log "${GREEN}[+] Installation completed!${NC}"
    log "${BLUE}[*] Some tools may need additional configuration:"
    log "${BLUE}[*] - Add API keys to ~/.config/ (check each tool's documentation)"
    log "${BLUE}[*] - Configure notify providers in ~/.config/notify/provider-config.yaml"
    log "${BLUE}[*] - Set up GF patterns in ~/.gf/"
    log "${BLUE}[*] Full installation log: $LOG_FILE${NC}"
}

# Execute main function
main
