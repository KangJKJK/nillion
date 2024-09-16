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

# /root/ubuntu-node 폴더가 존재하면 삭제합니다.
if [ -d "/root/ubuntu-node" ]; then
  echo -e "${RED}/root/ubuntu-node 폴더가 존재하므로 삭제합니다.${NC}"
  sudo rm -rf /root/ubuntu-node
fi

# 홈 디렉토리로 이동합니다.
cd $HOME

# 지정된 URL에서 ubuntu-node-v2.1.0.tar 파일을 다운로드합니다.
wget https://network3.io/ubuntu-node-v2.1.0.tar && \
tar -xf ubuntu-node-v2.1.0.tar && \
rm -rf ubuntu-node-v2.1.0.tar && \

# 압축 해제된 ubuntu-node 디렉토리로 이동합니다.
cd ubuntu-node

# 노드를 실행합니다.
sudo bash manager.sh up

# 노드의 개인키 및 본인의 IP를 표시합니다.
req "노드의 개인키를 확인하시고 적어두세요." sudo bash /root/ubuntu-node/manager.sh key
IP_ADDRESS=$(curl -s ifconfig.me)
req "사용자의 IP주소를 확인합니다." echo "사용자의 IP는 ${IP_ADDRESS}입니다."

# 웹계정과의 연동을 진행합니다.
URL="https://account.network3.ai/main?o=${IP_ADDRESS}:8080"
echo -e "${YELLOW}웹계정과 연동을 진행합니다.${NC}"
echo -e "${YELLOW}다음 URL로 접속하세요: ${URL}${NC}"
echo -e "${YELLOW}대시보드에서 현재 노드의 패널 우측 상단에 있는 +버튼을 클릭하여 노드의 개인키를 적어주세요.${NC}"
echo -e "${YELLOW}계속 진행하려면 엔터를 눌러 주세요.${NC}"
read -r

echo -e "${GREEN}모든 작업이 완료되었습니다. 컨트롤+A+D로 스크린을 종료해주세요.${NC}"
echo -e "${GREEN}스크립트 작성자: https://t.me/kjkresearch${NC}"
