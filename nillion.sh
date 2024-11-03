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
    docker pull nillion/verifier:v1.0.1
    if [ -d "nillion" ]; then
        echo -e "${GREEN}/root/nillion 디렉토리가 이미 존재합니다. 삭제 중...${NC}"
        rm -rf nillion  
        echo -e "${YELLOW}/root/nillion 디렉토리를 삭제했습니다.${NC}"
    fi

    # 노드 셋업
    mkdir -p nillion/verifier

    # 디렉토리 이동
    cd $HOME
    docker run -v ./nillion/verifier:/var/tmp nillion/verifier:v1.0.1 initialise
    echo -e "${YELLOW}아래에 표시되는 내용들을 모두 저장해두세요.${NC}"

    # 자격 증명 파일 출력
    if [ -f /root/nillion/verifier/credentials.json ]; then
        cat /root/nillion/verifier/credentials.json
    else
        echo "자격 증명 파일이 존재하지 않습니다."
    fi

    # 사용자 안내
    read -p "1.위에서 확인한 월렛을 케플러월렛에서 불러오세요 (엔터): "
    read -p "2.해당 사이트에서 faucet을 받아주세요:https://faucet.testnet.nillion.com (엔터): "
    read -p "3.해당 사이트에서 지갑을 연동하시고 Verifier를 선택하세요:https://verifier.nillion.com (엔터): "
    read -p "4.Set up for Linux를 선택하시고 Initialising the verifie 탭으로 이동해서 verifier 인증을 해주세요 (엔터): "
    read -p "5.어카운트 ID(지갑주소)와 퍼블릭키를 입력하고 베리파이어로 등록해주세요 (엔터): "
}

# 노드 구동 함수
run_node() {
    docker run -v ./nillion/verifier:/var/tmp nillion/verifier:v1.0.1 verify --rpc-endpoint "https://testnet-nillion-rpc.lavenderfive.com"
}

# 노드 설치
install_node

# 노드 구동
run_node

# 오류 확인
read -p "오류가 발생했습니까? (True/False): " error_occurred
if [ "$error_occurred" == "True" ]; then
    echo -e "${YELLOW}노드 설치를 다시 시작합니다...${NC}"
    install_node
    run_node
fi

# 현재 사용 중인 포트 확인
used_ports=$(ss -tuln | awk '{print $4}' | grep -o '[0-9]*$' | sort -u)

# 각 포트에 대해 ufw allow 실행
for port in $used_ports; do
    echo -e "${GREEN}포트 ${port}을(를) 허용합니다.${NC}"
    sudo ufw allow $port/tcp
done

echo -e "${GREEN}모든 사용 중인 포트가 허용되었습니다.${NC}"

echo -e "${YELLOW}이곳에서 트랜잭션기록들을 볼 수 있습니다: https://testnet.nillion.explorers.guru/${NC}"
echo -e "${YELLOW}모든 작업이 완료되었습니다. 컨트롤+A+D로 스크린을 종료해주세요.${NC}"
echo -e "${GREEN}스크립트 작성자: https://t.me/kjkresearch${NC}"
