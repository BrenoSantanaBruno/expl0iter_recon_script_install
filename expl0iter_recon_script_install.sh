#!/bin/bash

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Banner EXPL0ITER
echo -e "${MAGENTA}"
cat << "EOF"
███████╗██╗  ██╗██████╗ ██╗      ██████╗ ██╗████████╗███████╗██████╗
██╔════╝╚██╗██╔╝██╔══██╗██║     ██╔═████╗██║╚══██╔══╝██╔════╝██╔══██╗
█████╗   ╚███╔╝ ██████╔╝██║     ██║██╔██║██║   ██║   █████╗  ██████╔╝
██╔══╝   ██╔██╗ ██╔═══╝ ██║     ████╔╝██║██║   ██║   ██╔══╝  ██╔══██╗
███████╗██╔╝ ██╗██║     ███████╗╚██████╔╝██║   ██║   ███████╗██║  ██║
╚══════╝╚═╝  ╚═╝╚═╝     ╚══════╝ ╚═════╝ ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝

  RECON TOOLSET v3.0
EOF
echo -e "${NC}"

# Verificar root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[!] Execute como root: sudo ./install.sh${NC}"
    exit 1
fi

# ==============================================
# 1. DETECÇÃO DE CLOUD PROVIDER
# ==============================================
detect_cloud() {
    if [ -f /sys/hypervisor/uuid ] && [[ $(head -c 3 /sys/hypervisor/uuid) == "ec2" ]]; then
        echo "AWS"
    elif curl -s --max-time 1 http://169.254.169.254/metadata/v1/id | grep -q "DigitalOcean"; then
        echo "DigitalOcean"
    elif curl -s --max-time 1 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/id >/dev/null 2>&1; then
        echo "GCP"
    elif curl -s --max-time 1 -H "Metadata-Flavor: Oracle" http://169.254.169.254/opc/v1/instance/ | grep -q "ocid1.instance"; then
        echo "Oracle"
    elif curl -s --max-time 1 -H "Metadata: true" http://169.254.169.254/metadata/instance?api-version=2021-02-01 | grep -q "azEnvironment"; then
        echo "Azure"
    else
        echo "Local"
    fi
}

cloud_provider=$(detect_cloud)
echo -e "${YELLOW}[*] Ambiente detectado: ${CYAN}$cloud_provider${NC}"

# ==============================================
# 2. CONFIGURAÇÃO INICIAL
# ==============================================
echo -e "\n${BLUE}[*] Configurando sistema...${NC}"
apt update && apt upgrade -y
apt install -y git wget curl build-essential python3 python3-pip python3-venv ruby gem libpcap-dev sqlite3 libsqlite3-dev jq xargs nmap masscan

# Configurar pip para evitar erro de ambiente gerenciado
export PIP_BREAK_SYSTEM_PACKAGES=1

# ==============================================
# 3. INSTALAÇÃO DO GOLANG
# ==============================================
echo -e "\n${BLUE}[*] Instalando Go...${NC}"
latest_go=$(curl -s https://go.dev/dl/ | grep -oP 'go[0-9.]+\.linux-amd64\.tar\.gz' | head -n 1)
wget "https://dl.google.com/go/$latest_go" -O /tmp/go.tar.gz
tar -C /usr/local -xzf /tmp/go.tar.gz
rm /tmp/go.tar.gz

# Configurar environment
echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
echo 'export GOPATH=$HOME/go' >> /etc/profile
echo 'export PATH=$PATH:$GOPATH/bin' >> /etc/profile
source /etc/profile

echo -e "${GREEN}[+] Go instalado: $(go version)${NC}"

# ==============================================
# 4. FUNÇÕES DE INSTALAÇÃO
# ==============================================
install_go_tool() {
    local tool_path=$1
    local tool_name=$(basename $tool_path)

    echo -e "${YELLOW}[*] Instalando $tool_name...${NC}"
    GO111MODULE=on go install -v $tool_path@latest

    if [ -f "$GOPATH/bin/$tool_name" ]; then
        mv "$GOPATH/bin/$tool_name" /usr/local/bin/
        echo -e "${GREEN}[+] $tool_name instalado em /usr/local/bin${NC}"
    else
        echo -e "${RED}[!] Falha ao instalar $tool_name${NC}"
    fi
}

install_python_tool() {
    local repo_url=$1
    local tool_name=$2
    local install_path="/opt/$tool_name"

    echo -e "${YELLOW}[*] Instalando $tool_name...${NC}"
    git clone $repo_url $install_path

    python3 -m venv $install_path/venv
    source $install_path/venv/bin/activate
    pip install -r $install_path/requirements.txt
    deactivate

    echo -e "#!/bin/bash\nsource $install_path/venv/bin/activate\npython $install_path/\$(basename $install_path).py \"\$@\"" > /usr/local/bin/$tool_name
    chmod +x /usr/local/bin/$tool_name

    echo -e "${GREEN}[+] $tool_name instalado com venv em $install_path${NC}"
}

# ==============================================
# 5. INSTALAÇÃO DAS FERRAMENTAS
# ==============================================
echo -e "\n${MAGENTA}[*] Instalando ferramentas de recon...${NC}"

# Ferramentas Go
go_tools=(
    "github.com/projectdiscovery/subfinder/v2/cmd/subfinder"
    "github.com/tomnomnom/assetfinder"
    "github.com/projectdiscovery/httpx/cmd/httpx"
    "github.com/lc/gau/v2/cmd/gau"
    "github.com/bp0lr/gauplus"
    "github.com/tomnomnom/waybackurls"
    "github.com/projectdiscovery/nuclei/v2/cmd/nuclei"
    "github.com/projectdiscovery/naabu/v2/cmd/naabu"
    "github.com/projectdiscovery/dnsx/cmd/dnsx"
    "github.com/projectdiscovery/katana/cmd/katana"
    "github.com/ffuf/ffuf"
    "github.com/hakluke/hakrawler"
    "github.com/hahwul/dalfox/v2"
    "github.com/sensepost/gowitness"
    "github.com/projectdiscovery/chaos-client/cmd/chaos"
    "github.com/deletescape/goop"
    "github.com/hakluke/hakrevdns"
    "github.com/hakluke/hakcheckurl"
    "github.com/tomnomnom/qsreplace"
    "github.com/haccer/subjack"
    "github.com/lc/subjs"
    "github.com/assetnote/kiterunner/cmd/kr"
    "github.com/dwisiswant0/arjun"
    "github.com/jaeles-project/gospider"
    "github.com/Emoe/kxss"
    "github.com/shenwei356/rush"
    "github.com/tomnomnom/unfurl"
    "github.com/tomnomnom/anew"
    "github.com/tomnomnom/gf"
    "github.com/003random/getJS"
    "github.com/anshumanbh/tko-subs"
    "github.com/dwisiswant0/crlfuzz/cmd/crlfuzz"
    "github.com/jaeles-project/jaeles"
    "github.com/devanshbatham/paradox"
    "github.com/j3ssie/jldc"
    "github.com/takshal/freq"
    "github.com/ThreatUnkown/jsubfinder"
    "github.com/d3mondev/puredns/v2"
    "github.com/signedsecurity/sigurlfind3r/cmd/sigurlfind3r"
    "github.com/chromedp/chromedp"
    "github.com/ferreiraklet/airixss"
    "github.com/ferreiraklet/nilo"
    "github.com/owasp-amass/amass/v3/..."
    "github.com/OJ/gobuster/v3"  # Gobuster adicionado
)

for tool in "${go_tools[@]}"; do
    install_go_tool $tool
done

# Ferramentas Python (com venv)
python_tools=(
    "https://github.com/obheda12/GitDorker GitDorker"
    "https://github.com/0x240x23elu/JSScanner JSScanner"
    "https://github.com/xnl-h4ck3r/xnLinkFinder xnLinkFinder"
    "https://github.com/xnl-h4ck3r/waymore waymore"
    "https://github.com/s0md3v/Photon Photon"
    "https://github.com/s0md3v/XSStrike XSStrike"
)

for tool in "${python_tools[@]}"; do
    repo_url=$(echo $tool | awk '{print $1}')
    tool_name=$(echo $tool | awk '{print $2}')
    install_python_tool "$repo_url" "$tool_name"
done

# Ferramentas especiais
echo -e "${YELLOW}[*] Instalando Findomain...${NC}"
findomain_latest=$(curl -s https://api.github.com/repos/findomain/findomain/releases/latest | grep -oP 'https://github.com/findomain/findomain/releases/download/[^/]+/findomain-linux' | head -n 1)
wget -q "$findomain_latest" -O /usr/local/bin/findomain
chmod +x /usr/local/bin/findomain

# Dirsearch
echo -e "${YELLOW}[*] Instalando Dirsearch...${NC}"
git clone https://github.com/maurosoria/dirsearch /opt/dirsearch
ln -s /opt/dirsearch/dirsearch.py /usr/local/bin/dirsearch
echo -e "${GREEN}[+] Dirsearch instalado em /opt/dirsearch${NC}"

# Gobuster (já incluso nas ferramentas Go acima)
echo -e "${YELLOW}[*] Verificando Gobuster...${NC}"
if [ -f "/usr/local/bin/gobuster" ]; then
    echo -e "${GREEN}[+] Gobuster já instalado${NC}"
else
    GO111MODULE=on go install github.com/OJ/gobuster/v3@latest
    mv "$GOPATH/bin/gobuster" /usr/local/bin/
    echo -e "${GREEN}[+] Gobuster instalado${NC}"
fi

# GF Patterns
echo -e "${YELLOW}[*] Configurando GF patterns...${NC}"
git clone https://github.com/1ndianl33t/Gf-Patterns /opt/Gf-Patterns
mkdir -p ~/.gf
cp /opt/Gf-Patterns/*.json ~/.gf/
git clone https://github.com/tomnomnom/gf /opt/gf
cd /opt/gf && go build && cp gf /usr/local/bin/
cd -

# Sudomy
echo -e "${YELLOW}[*] Instalando Sudomy...${NC}"
git clone --recursive https://github.com/screetsec/Sudomy /opt/Sudomy
cd /opt/Sudomy
python3 -m pip install -r requirements.txt
ln -s /opt/Sudomy/sudomy /usr/local/bin/sudomy
echo -e "${GREEN}[+] Sudomy instalado em /opt/Sudomy${NC}"
echo -e "${YELLOW}[!] Configure as APIs em /opt/Sudomy/api_config.yaml${NC}"

# ==============================================
# 6. INSTALAÇÃO DO AXIOM (OPCIONAL)
# ==============================================
if [[ "$cloud_provider" != "Local" ]]; then
    echo -e "${YELLOW}[?] Você está em $cloud_provider. Instalar Axiom mesmo assim? [s/N]${NC}"
    read -r install_axiom
else
    echo -e "${YELLOW}[?] Instalar Axiom? [s/N]${NC}"
    read -r install_axiom
fi

if [[ "$install_axiom" =~ ^[SsYy]$ ]]; then
    echo -e "${BLUE}[*] Instalando Axiom...${NC}"
    bash <(curl -s https://raw.githubusercontent.com/pry0cc/axiom/master/interact/axiom-configure)
    echo -e "${GREEN}[+] Axiom instalado!${NC}"
else
    echo -e "${YELLOW}[*] Pulando instalação do Axiom.${NC}"
fi

# ==============================================
# 7. FINALIZAÇÃO
# ==============================================
echo -e "${GREEN}"
cat << "EOF"
╔════════════════════════════════════════╗
║                                        ║
║   Instalação concluída com sucesso!    ║
║                                        ║
║   Feito por EXPL0ITER                  ║
║   expl0iter@devstorm.io                ║
║   https://brenosantana.com             ║
║                                        ║
╚════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${CYAN}[*] Todas as ferramentas estão em /usr/local/bin${NC}"
echo -e "${CYAN}[*] Execute 'source /etc/profile' ou reinicie o terminal${NC}"
echo -e "\n${MAGENTA}[*] Ferramentas instaladas:"
echo -e "  - Subfinder, Assetfinder, httpx, gau, nuclei, ffuf"
echo -e "  - Amass, Dirsearch, Gobuster, Katana, Dalfox"
echo -e "  - Gowitness, Chaos, Jaeles, GF, Kiterunner"
echo -e "  - E +50 outras ferramentas de recon${NC}"
