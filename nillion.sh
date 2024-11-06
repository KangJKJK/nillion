#!/bin/bash

# 컬러 정의
export RED='\033[0;31m'
export YELLOW='\033[1;33m'
export GREEN='\033[0;32m'
export NC='\033[0m'  # No Color

# 안내 메시지
echo -e "${YELLOW}Nillion 노드 설치를 시작합니다.${NC}"

# 패키지 업데이트 및 필요한 패키지 설치
echo -e "${YELLOW}패키지 업데이트 및 필요한 패키지 설치 중...${NC}"
sudo apt update && sudo apt install -y ufw && sudo apt install -y net-tools
echo -e "${YELLOW}Node.js LTS 버전을 설치하고 설정 중...${NC}"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # nvm을 로드합니다
nvm install --lts
nvm use --lts

# 도커 설치
dockerSetup(){
    if ! command -v docker &> /dev/null; then
        echo "Docker 설치 중..."

        for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
            sudo apt-get remove -y $pkg
        done

        sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        
        sudo apt update -y && sudo apt install -y docker-ce
        sudo systemctl start docker
        sudo systemctl enable docker

        echo "Docker Compose 설치 중..."

        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose

        echo "Docker가 성공적으로 설치되었습니다."

    else
        echo "Docker가 이미 설치되어 있습니다."

    fi
}

# 노드 설치 함수
install_node() {
    docker container run --rm hello-world

    # 디렉토리 설정
    if [ -d "nillion" ]; then
        echo -e "${GREEN}/root/nillion 디렉토리가 이미 존재합니다. 삭제 중...${NC}"
        rm -rf /root/nillion  
        echo -e "${YELLOW}/root/nillion 디렉토리를 삭제했습니다.${NC}"  
    fi
    mkdir -p /root/nillion/verifier

    docker pull nillion/verifier:v1.0.1

    # 현재 사용 중인 포트 확인
    used_ports=$(ss -tuln | awk '{print $4}' | grep -o '[0-9]*$' | sort -u)

    # 각 포트에 대해 ufw allow 실행
    for port in $used_ports; do
        echo -e "${GREEN}포트 ${port}을(를) 허용합니다.${NC}"
        sudo ufw allow $port/tcp
    done

    echo -e "${GREEN}모든 사용 중인 포트가 허용되었습니다.${NC}"
    cd $HOME

    # 지갑 선택
    read -p "새 지갑을 원하시면 '1', 기존 지갑을 사용하시려면 '2'를 입력하세요: " wallet_choice

    generate_pub_key_address() {
        echo "공개 키와 주소를 생성하는 중입니다..."
        node -e "
    const { DirectSecp256k1Wallet } = require('@cosmjs/proto-signing');

    async function getAddressAndPubKeyFromPrivateKey(privateKeyHex) {
    const privateKeyBytes = Uint8Array.from(
        privateKeyHex.match(/.{1,2}/g).map((byte) => parseInt(byte, 16))
    );
    const wallet = await DirectSecp256k1Wallet.fromKey(privateKeyBytes, 'nillion');
    const [{ address, pubkey }] = await wallet.getAccounts();
    console.log(address);
    console.log(Buffer.from(pubkey).toString('hex'));
    }

    getAddressAndPubKeyFromPrivateKey('$private_key');
    " > address_and_pubkey.txt

        wallet_address=$(sed -n '1p' address_and_pubkey.txt)
        pub_key=$(sed -n '2p' address_and_pubkey.txt)

        echo "주소: $wallet_address"
        echo "공개 키: $pub_key"
        echo
    }

    if [[ "$wallet_choice" == "2" ]]; then
        # 개인 키 입력 요청
        read -p "개인 키를 입력하세요: " private_key
        echo

        npm install @cosmjs/proto-signing
        generate_pub_key_address
cat <<EOF > nillion/verifier/credentials.json
{
"priv_key": "$private_key",
"pub_key": "$pub_key",
"address": "$wallet_address"
}
EOF
        echo
        echo "다음 정보를 웹사이트에 입력하세요: https://verifier.nillion.com/verifier"
        read -p "해당 사이트에서 지갑을 연동하시고 Verifier를 선택하세요:https://verifier.nillion.com (엔터): "
        echo -e "주소: ${GREEN}$(jq -r '.address' nillion/verifier/credentials.json)${NC}"
        echo -e "공개 키: ${GREEN}$(jq -r '.pub_key' nillion/verifier/credentials.json)${NC}"
        read -p "Set up for Linux를 선택하시고 Initialising the verifie 탭으로 이동해서 verifier 인증을 해주세요 (엔터): "
        echo

    elif [[ "$wallet_choice" == "1" ]]; then
        echo "새로운 검증자 노드를 생성하는 중입니다..."
        docker run -v ./nillion/verifier:/var/tmp nillion/verifier:v1.0.1 initialise

        echo
        echo "이제 다음 링크를 방문하세요: https://verifier.nillion.com/verifier"
        echo "새로운 Keplr 지갑을 연결하세요."
        echo "nillion 주소로 faucet을 요청하세요: https://faucet.testnet.nillion.com"
        echo

        read -p "faucet을 요청하셨나요? (y/n): " faucet_requested
        if [[ ! "$faucet_requested" =~ ^[yY]$ ]]; then
            echo "faucet을 요청하시고 다시 시도하세요."
            exit 1
        fi

        echo
        echo "다음 정보를 웹사이트에 입력하세요: https://verifier.nillion.com/verifier"
        read -p "해당 사이트에서 지갑을 연동하시고 Verifier를 선택하세요:https://verifier.nillion.com (엔터): "
        echo -e "주소: ${GREEN}$(jq -r '.address' nillion/verifier/credentials.json)${NC}"
        echo -e "공개 키: ${GREEN}$(jq -r '.pub_key' nillion/verifier/credentials.json)${NC}"
        read -p "Set up for Linux를 선택하시고 Initialising the verifie 탭으로 이동해서 verifier 인증을 해주세요 (엔터): "
        echo

        read -p "웹사이트에 주소와 공개 키를 입력하셨나요? (y/n): " info_inputted
        if [[ ! "$info_inputted" =~ ^[yY]$ ]]; then
            echo "정보를 입력하시고 다시 시도하세요."
            exit 1
        fi
    else
        echo "잘못된 선택입니다. 1 또는 2를 선택하세요."
        exit 1
    fi

    echo "노드를 시작합니다."
    docker run -d --name nillion -v ./nillion/verifier:/var/tmp nillion/verifier:v1.0.1 verify --rpc-endpoint "https://testnet-nillion-rpc.lavenderfive.com"

    echo "로그를 표시합니다."
    sudo docker logs nillion -fn 50
}

# Verify 다시 진행 함수
verify() {
    echo -e "${YELLOW}베리파이중인 사이트에서 새로고침을 한 후 다시 Verify를 진행하세요: ${NC}"
    read -p "VERIFIER REGISTERED라고 화면에 뜨면 엔터를 눌러서 다음단계를 진행해주세요: "
    
    # 노드 실행
    docker run -v ./nillion/verifier:/var/tmp nillion/verifier:v1.0.1 verify --rpc-endpoint "https://testnet-nillion-rpc.lavenderfive.com"
    
    # 오류 확인
    read -p "오류가 발생했습니까? (True/False): " error_occurred
    if [ "$error_occurred" == "True" ]; then
        echo -e "${YELLOW}오류가 발생했습니다. 다시 선택하세요:${NC}"
    fi
}

# 노드 삭제 함수
delete_node() {
    echo "credentials.json을 nillion-backup.json으로 백업하는 중..."
    if [[ -f nillion/verifier/credentials.json ]]; then
        cp nillion/verifier/credentials.json nillion-backup.json
        echo "백업이 성공적으로 생성되었습니다."
    else
        echo "백업할 credentials.json 파일이 없습니다."
    fi

    echo "Nillion Docker 컨테이너를 중지하고 제거하는 중..."
    sudo docker ps -a | grep nillion/verifier | awk '{print $1}' | xargs -r docker stop 2>/dev/null
    sudo docker ps -a | grep nillion/verifier | awk '{print $1}' | xargs -r docker rm 2>/dev/null

    echo "검증자 노드를 삭제하는 중..."
    rm -rf nillion/verifier
    echo "검증자 노드가 성공적으로 삭제되었습니다."
}

while true; do

    echo -e "${YELLOW}이곳에서 트랜잭션기록들을 볼 수 있습니다: https://testnet.nillion.explorers.guru/${NC}"
    echo -e "${GREEN}스크립트 작성자: https://t.me/kjkresearch${NC}"
    echo
    echo "1. 노드 설치"
    echo "2. Verify 다시 진행"
    echo "3. 노드 삭제"
    echo "4. 종료"  # 종료 옵션 추가
    echo
    read -p "옵션을 선택하세요: " option
    case $option in
        1) 
            dockerSetup  # dockerSetup 함수 호출
            install_node  # install_node 함수 호출
            ;;
        2) verify ;;
        3) delete_node ;;
        4) 
            echo "스크립트를 종료합니다."
            exit 0  # 스크립트 종료
            ;;
        *) echo "잘못된 선택입니다. 다시 시도하세요." ;;
    esac
done

