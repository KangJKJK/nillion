#!/bin/bash

# 색깔 변수 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Network3 노드 설치를 시작합니다.${NC}"

# 사용자에게 명령어 결과를 강제로 보여주는 함수
req() {
  echo -e "${YELLOW}$1${NC}"
  shift
  "$@"
  echo -e "${YELLOW}결과를 확인한 후 엔터를 눌러 계속 진행하세요.${NC}"
  read -r
}

# Docker가 설치되어 있는지 확인
if ! command -v docker &> /dev/null; then
    echo ""
    echo "Docker가 설치되지 않았습니다. Docker를 설치 중..."
    
    # Docker 설치 명령어
    sudo apt update && sudo apt install -y curl && \
    curl -fsSL https://get.docker.com -o get-docker.sh && \
    sudo sh get-docker.sh

    # Docker 그룹에 사용자 추가
    sudo usermod -aG docker ${USER} && su - ${USER} -c "groups"
else
    echo ""
    echo "Docker가 이미 설치되어 있습니다."
fi

# 'nillion' 디렉터리가 있는지 확인
if [ -d "nillion" ]; then
    echo ""
    echo "'nillion' 디렉터리가 발견되었습니다. 제거 중..."
    sudo rm -r "nillion"
else
    echo ""
    echo "'nillion' 디렉터리가 없습니다."
fi

# 필요한 패키지 설치 (jq 및 bc)
sudo apt update && sudo apt install -y jq bc

# 현재 실행 중인 'nillion' 컨테이너 중지 및 제거
echo ""
echo "'nillion' 이름을 가진 실행 중인 컨테이너를 중지하고 제거 중..."
sudo docker ps | grep nillion | awk '{print $1}' | xargs -r docker stop
sudo docker ps -a | grep nillion | awk '{print $1}' | xargs -r docker rm

# nillion Docker 이미지를 최신 버전으로 Pull
echo ""
echo "NILLION Docker 이미지를 Pull 중..."
sudo docker pull nillion/retailtoken-accuser:latest

# Docker 컨테이너를 실행하여 초기화 작업 수행
echo ""
echo "디렉터리를 생성하고 초기화를 위해 Docker 컨테이너 실행 중..."
mkdir -p nillion/accuser && \
sudo docker run -v "$(pwd)/nillion/accuser:/var/tmp" nillion/retailtoken-accuser:v1.0.1 initialise

# credentials.json 파일 경로
SECRET_FILE=~/nillion/accuser/credentials.json

# credentials.json 파일이 존재하는지 확인
if [ -f "$SECRET_FILE" ]; then
    ADDRESS=$(jq -r '.address' "$SECRET_FILE")
    echo ""
    echo "이 주소로 Nillion 테스트넷 faucet을 요청하십시오: $ADDRESS"
    echo "(https://faucet.testnet.nillion.com)"
    echo ""

    # faucet 요청 여부 확인
    read -p "faucet을 요청하셨습니까? (계속하려면 y/Y 입력): " FAUCET_REQUESTED1
    if [[ "$FAUCET_REQUESTED1" =~ ^[yY]$ ]]; then
        echo ""
        echo "이제 https://verifier.nillion.com/verifier를 방문하세요."
        echo "새 Keplr 지갑을 연결하십시오."
        echo "Nillion 주소로 faucet을 요청하십시오: https://faucet.testnet.nillion.com"
        echo ""

        # Keplr 지갑에 faucet을 요청했는지 확인
        read -p "Keplr 지갑에 faucet을 요청하셨습니까? (계속하려면 y/Y 입력): " FAUCET_REQUESTED2
        if [[ "$FAUCET_REQUESTED2" =~ ^[yY]$ ]]; then
            # Keplr 지갑의 Nillion 주소 입력 요청
            read -p "Keplr 지갑의 Nillion 주소를 입력하십시오: " KEPLR
            echo ""
            echo "다음 정보를 https://verifier.nillion.com/verifier 사이트에 입력하십시오."
            echo "주소: $ADDRESS"
            echo "공개 키: $(jq -r '.pub_key' "$SECRET_FILE")"
            echo ""

            # 정보를 제출했는지 확인
            read -p "정보를 제출하셨습니까? (계속하려면 y/Y 입력): " address_submitted
            if [[ "$address_submitted" =~ ^[yY]$ ]]; then
                echo ""
                echo "이 개인 키를 안전한 곳에 저장하십시오: $(jq -r '.priv_key' "$SECRET_FILE")"
                echo ""

                # 개인 키를 안전한 곳에 저장했는지 확인
                read -p "개인 키를 안전한 곳에 저장하셨습니까? (계속하려면 y/Y 입력): " private_key_saved
                if [[ "$private_key_saved" =~ ^[yY]$ ]]; then
                    echo ""
                    echo "accuse 명령으로 Docker 컨테이너를 실행 중..."
                    sudo docker run -v "$(pwd)/nillion/accuser:/var/tmp" nillion/retailtoken-accuser:v1.0.1 accuse --rpc-endpoint "https://nillion-testnet.rpc.nodex.one" --block-start "$(curl -s "https://testnet-nillion-api.lavenderfive.com/cosmos/tx/v1beta1/txs?query=message.sender='$KEPLR'&pagination.limit=20&pagination.offset=0" | jq -r '[.tx_responses[] | select(.tx.body.memo == "AccusationRegistrationMessage")] | sort_by(.height | tonumber) | .[-1].height | tonumber - 5' | bc)"
                else
                    echo ""
                    echo "개인 키를 안전한 곳에 저장한 후 다시 시도하십시오."
                fi
            else
                echo ""
                echo "제출을 완료한 후 다시 시도하십시오."
            fi
        else
            echo ""
            echo "Keplr 지갑에 faucet을 요청한 후 다시 시도하십시오."
        fi
    else
        echo ""
        echo "faucet을 요청한 후 다시 시도하십시오."
    fi
else
    echo ""
    echo "credentials.json 파일이 없습니다. 초기화 과정이 성공적으로 완료되었는지 확인하십시오."
fi

echo -e "${GREEN}모든 작업이 완료되었습니다. 컨트롤+A+D로 스크린을 종료해주세요.${NC}"
echo -e "${GREEN}스크립트 작성자: https://t.me/kjkresearch${NC}"
