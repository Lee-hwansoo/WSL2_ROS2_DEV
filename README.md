# ROS2 Hunter Lab 환경

Windows 11/10을 위한 **CTO급 ROS2 Humble 전문 개발 환경**입니다.
이 프로젝트는 **WSL2 (Ubuntu 22.04)** 의 설치부터 **Docker Dev Container** (Gazebo, Terminator, 성능 최적화 포함) 구성까지의 모든 과정을 자동화합니다.

## 🚀 주요 기능

- **원클릭 설치 (One-Click Setup)**: `setup_windows.ps1` 스크립트 하나로 WSL 활성화, 커널 업데이트, Ubuntu 설치, 드라이버 설정을 한 번에 완료합니다.
- **스마트 드라이브 감지**: 용량이 부족한 `C:\` 대신 여유 있는 `D:\` 드라이브를 자동으로 감지하여 리눅스를 설치합니다.
- **성능 최적화 (Performance Optimized)**:
  - **WSL2**: `systemd` 지원, `mirrored` 네트워킹 모드, 메모리 최적화(8GB 제한)가 기본 적용되어 있습니다.
  - **Docker**: `ccache` 볼륨을 영구적으로 마운트하여 재빌드 속도가 획기적으로 빠릅니다.
  - **도구**: `uv` (초고속 Python 패키지 관리자), `terminator` (GUI 터미널), `can-utils` 등이 사전 설치됩니다.
- **안정성 및 확장성 (Robust & Modular)**:
  - **설정 분리**: `scripts/install_config.ps1`을 통해 배포판 버전이나 설정을 쉽게 변경할 수 있습니다.
  - **안전한 설치**: 윈도우/리눅스 간의 경계를 명확히 하여, 시스템 파일 손상 위험을 원천 차단했습니다.
  - **모듈화**: 설치 로직이 라이브러리(`lib/`)로 분리되어 유지보수가 쉽습니다.
- **통합 설정 관리 (Unified Configuration)**:
  - `aliases.sh`와 `terminator_config`를 `config/` 디렉토리에서 중앙 관리합니다.
  - Windows에서 설정을 수정하면, 심볼릭 링크를 통해 구동 중인 컨테이너에 즉시 적용됩니다.

## 📋 필수 조건

- Windows 10/11 (최신 업데이트 권장)
- 관리자 권한 (Administrator Privileges)
- [VS Code](https://code.visualstudio.com/) 및 **Dev Containers** 확장 프로그램 설치

## 🛠️ 설치 가이드

### 1. 설치 스크립트 실행

**PowerShell을 관리자 권한**으로 실행한 뒤 프로젝트 경로에서 다음 명령어를 입력하세요:

```powershell
# PowerShell (관리자 권한)
.\scripts\setup_windows.ps1

# [옵션] 드라이 런 (실행하지 않고 로그만 확인)
.\scripts\setup_windows.ps1 -DryRun

# [옵션] 다른 배포판 이름으로 설치
.\scripts\setup_windows.ps1 -DistroName "My-ROS-Bot"
```

**스크립트 수행 작업:**

1. **WSL2 활성화**:필요한 Windows 기능을 자동으로 켜고 재부팅을 안내합니다.
2. **의존성 설치**: `usbipd` 등 필수 도구를 확인하고 설치합니다.
3. **RootFS 다운로드**: 검증된 Ubuntu 이미지를 다운로드하여 캐시합니다.
4. **배포판 등록**: 스마트 드라이브 감지 로직으로 최적의 위치(D:\ 등)에 설치합니다.
5. **리눅스 부트스트랩**: 사용자 생성, 그룹 설정, Docker 설치 및 권한 부여를 자동으로 수행합니다.
6. **이 프로젝트를 WSL 내부(`~/env`)로 자동 복사**

### 2. 개발 시작 (WSL에서 실행)

설치가 완료되면 다음 순서로 실행하세요:

1. **WSL 터미널 열기**: `wsl` 입력
2. **프로젝트로 이동**: (자동으로 복사된 경로)
   ```bash
   cd ~/env
   ```
3. **VS Code 실행**:
   ```bash
   code .
   ```
4. **"Reopen in Container"** 클릭.

> **Why WSL?**: WSL 안에서 Dev Container를 실행하면 WSL 파일 탐색기에서 모든 파일을 볼 수 있고, Docker와의 연결도 가장 안정적입니다. (권장: WSL Native 방식)

### 3. 리눅스 설치 (Native Ubuntu)

WSL이 아닌 일반 Ubuntu 컴퓨터에서도 동일한 환경을 구축할 수 있습니다.

1.  **스크립트 실행**:
    ```bash
    sudo bash scripts/setup_ubuntu.sh
    ```
2.  **VS Code 실행**:
    ```bash
    code .
    ```
3.  **"Reopen in Container"** 클릭.
    *   완전히 동일하게 Docker 컨테이너가 실행되고, `../ros_ws`에 똑같이 작업 공간이 생성됩니다.

### 2. 개발 환경 접속 (Dev Container)

**Dev Container**는 프로젝트에 필요한 모든 도구와 설정을 Docker 안에 미리 격리해 두는 기술입니다. 내 컴퓨터를 더럽히지 않고 완벽한 개발 환경을 구축할 수 있습니다.

#### 단계별 접속 방법

1. **VS Code 실행**: 이 프로젝트 폴더를 VS Code로 엽니다.
2. **확장 프로그램 설치**: 왼쪽 사이드바의 확장(Extensions) 탭에서 **`Dev Containers`** (Microsoft)를 검색하여 설치합니다.
3. **컨테이너 열기**:
    - 화면 왼쪽 아래의 **파란색 버튼** (`><`)을 클릭합니다.
    - 또는 `F1` 키를 누르고 **`Dev Containers: Reopen in Container`** 를 검색하여 선택합니다.
4. **빌드 대기**:
    - 처음 실행 시 Docker 이미지를 다운로드하고 빌드하느라 **약 5~10분** 정도 소요될 수 있습니다. (네트워크 속도에 따라 다름)
    - 하단의 상태 표시줄에서 진행 상황을 볼 수 있습니다.

#### 접속 성공 확인

터미널이 열리면 프롬프트가 `ros@...` 로 바뀌어 있어야 합니다. 이제 다음 명령어들을 사용해 보세요:

- **`terminator`**: GUI 터미널이 새 창으로 뜨는지 확인합니다. (X11 포워딩/WSLg 작동 확인)
- **`cb`**: `colcon build` 명령어가 실행되는지 확인합니다. (Alias 작동 확인)
- **`gcc --version`**: 컴파일러가 정상적으로 설치되었는지 확인합니다.

> **Tip**: 컨테이너 안에서 생성한 파일은 윈도우 탐색기에서도 그대로 보입니다. (실시간 동기화)

### 3. USB/CAN 장치 연결 방법

WSL 및 도커에서 USB 장치를 사용하려면 윈도우에서 장치를 연결(Attach)해주어야 합니다.

1. **관리자 권한**으로 PowerShell 또는 CMD를 엽니다.
2. 연결된 USB 장치 목록과 BUSID를 확인합니다:

    ```powershell
    usbipd wsl list
    ```

3. 원하는 장치의 `BUSID` (예: `1-1`)를 찾아 연결합니다:

    ```powershell
    usbipd wsl attach --busid <BUSID>
    ```

    *(최초 1회에는 드라이버 설치 창이 뜰 수 있습니다)*

4. 이제 도커 컨테이너 안에서 장치가 보입니다:

    ```bash
    lsusb
    ifconfig can0
    ```

### 4. GPU 가속 활성화 (선택 사항)

NVIDIA 그래픽 카드가 있는 경우, 시뮬레이션 성능을 위해 GPU 가속을 켤 수 있습니다.

1. `.devcontainer/devcontainer.json` 파일을 엽니다.
2. `// "--gpus=all"` 부분의 주석(`//`)을 제거합니다.
3. **Rebuild Container**를 실행합니다.

> **주의**: GPU가 없는 컴퓨터에서 이 옵션을 켜면 컨테이너가 실행되지 않습니다. (기본값: 꺼짐)

## 📂 디렉토리 구조

```graphql
.
├── config/                 # 설정 중앙 관리소 (Single Source of Truth)
│   ├── .wslconfig          # 전역 WSL 최적화 설정 (메모리, 네트워킹)
│   ├── aliases.sh          # 컨테이너에 주입될 Bash 별칭(Alias) 모음
│   ├── terminator_config   # GUI 터미널 레이아웃 및 단축키 설정
│   └── wsl.conf            # 각 배포판 부팅 설정 (Systemd 등)
├── docker/                 # Dev Container 정의
│   ├── Dockerfile          # ROS2 Humble + Gazebo + Utils 이미지 설계도
│   └── devcontainer.json   # VS Code 연동 및 볼륨 마운트 설정
├── scripts/                # 자동화 스크립트 (모듈화됨)
│   ├── lib/                # [공용] 헬퍼 함수 및 인스톨러 라이브러리
│   │   ├── common.sh       # 로깅 및 공통 유틸리티
│   │   └── installers.sh   # 패키지 설치 로직 분리
│   ├── install_config.ps1  # [설정] Windows 설치 설정 (버전, 경로 등)
│   ├── install_config.sh   # [설정] Linux 설치 설정 (패키지 목록 등)
│   ├── setup_windows.ps1   # [Windows용] 설치 진입점 (Entry Point)
│   ├── setup_linux.sh      # [내부용] WSL 초기 세팅 및 패키지 설치
│   └── init_workspace.sh   # [내부용] 컨테이너 실행 시 환경 초기화
└── README.md
```

## 🔧 사용자 설정

- **단축키/Alias 수정**: `config/aliases.sh`를 수정하세요. 새 터미널을 열면 즉시 적용됩니다.
- **터미널 레이아웃**: `config/terminator_config`를 수정하여 Terminator 설정을 변경할 수 있습니다.
- **패키지 추가**: `docker/Dockerfile`의 `apt-get install` 목록에 패키지를 추가하고 컨테이너를 재빌드(`Rebuild Container`)하세요.

## ⚡ 성능 팁

- **빌드 캐시 (ccache)**: `ros2_ccache`라는 Docker Volume이 자동으로 생성되어 사용됩니다. 이 볼륨을 삭제하지 않으면 컨테이너를 지우고 다시 만들어도 빌드 속도가 유지됩니다.
- **네트워킹**: `mirrored` 모드를 사용하므로, 컨테이너의 포트가 Windows의 `localhost`에 자동으로 매핑됩니다.

## 🛑 트러블슈팅

- **"WSL error"**: BIOS 설정에서 가상화(Virtualization/VT-x)가 켜져 있는지 확인하세요.
- **"Terminator config not found"**: 터미널에서 `bash scripts/init_workspace.sh`를 수동으로 한 번 실행해주시면 설정 링크가 복구됩니다.
