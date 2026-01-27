# ROS2 Hunter Lab 환경

Windows 11/10을 위한 **CTO급 ROS2 Humble 전문 개발 환경**입니다.
이 프로젝트는 **WSL2 (Ubuntu 22.04)** 설치부터 ROS2 개발 환경 구축까지 모든 과정을 자동화합니다.

## 🚀 주요 기능

- **원클릭 설치**: `01_setup_windows.ps1` 스크립트 하나로 WSL 활성화, 커널 업데이트, Ubuntu 설치를 한 번에 완료
- **스마트 드라이브 감지**: 용량이 부족한 `C:\` 대신 여유 있는 `D:\` 드라이브를 자동으로 감지
- **GPU 가속**: WSLg를 통한 D3D12 GPU 패스스루 자동 설정
- **성능 최적화**: systemd 지원, mirrored 네트워킹 모드, 메모리 최적화 기본 적용
- **모듈화된 설계**: SSO 원칙으로 설정 중앙 관리, 재사용 가능한 라이브러리

## 📋 필수 조건

- Windows 10/11 (최신 업데이트 권장)
- 관리자 권한 (Administrator Privileges)
- [VS Code](https://code.visualstudio.com/) (권장)

## 🛠️ 설치 가이드

### 1. Windows 설정

**PowerShell을 관리자 권한**으로 실행:

```powershell
.\scripts\01_setup_windows.ps1

# [옵션] 드라이 런 (실행하지 않고 로그만 확인)
.\scripts\01_setup_windows.ps1 -DryRun
```

**스크립트 수행 작업:**
1. WSL2 활성화 및 재부팅 안내
2. Ubuntu 22.04 다운로드 및 설치
3. 스마트 드라이브 감지 (D:\, E:\ 우선)
4. 프로젝트 파일 복사 → `~/env`

### 2. Ubuntu 설정 (WSL 내부)

```bash
# WSL 터미널에서
cd ~/env
sudo bash scripts/02_setup_ubuntu.sh
```

**스크립트 수행 작업:**
1. 기본 패키지 설치
2. **ROS2 Humble** 설치
3. **Mesa PPA** 업그레이드 (GPU 가속)
4. 개발 도구 설치 (terminator, htop 등)
5. 환경 설정 (bashrc, aliases)

### 3. 설치 확인

```bash
# 새 터미널 열기 또는
source ~/.bashrc

# ROS2 확인
ros2 --version

# GPU 상태 확인
hw_check
```

## 🖥️ GPU/하드웨어 관리

| 명령어 | 설명 |
|--------|------|
| `hw_check` | 종합 하드웨어 진단 |
| `gpu_check` | OpenGL 렌더러 확인 |
| `gpu_auto` | GPU 자동 설정 |
| `use_cpu` | 소프트웨어 렌더링 (안정) |

## 📂 디렉토리 구조

```
.
├── config/                  # [SSO] 설정 중앙 관리
│   ├── install_config.sh    # 버전, 패키지 목록
│   ├── .wslconfig           # WSL 전역 설정
│   ├── wsl.conf             # 배포판 설정
│   └── aliases.sh           # Bash aliases
├── scripts/
│   ├── lib/
│   │   ├── common.sh        # 공용 함수
│   │   └── installers.sh    # 설치 함수
│   ├── 01_setup_windows.ps1 # Windows 진입점
│   ├── 02_setup_ubuntu.sh   # Ubuntu 진입점
│   ├── hardware_check.sh    # 하드웨어 진단
│   └── gpu_setup.sh         # GPU 설정
└── README.md
```

## ⚡ 빠른 시작 명령어

| 명령어 | 설명 |
|--------|------|
| `cw` | `cd ~/ros_ws` |
| `cb` | `colcon build` |
| `s` | `source install/setup.bash` |
| `rt` | `ros2 topic list` |
| `rn` | `ros2 node list` |
| `gzs` | Gazebo 실행 |

## 🛑 트러블슈팅

| 문제 | 해결 방법 |
|------|----------|
| WSL error | BIOS에서 가상화(VT-x) 활성화 확인 |
| Gazebo 검은 화면 | `gpu_auto` 실행, 안되면 `use_cpu` |
| GPU 인식 안됨 | `hw_check`로 상태 확인, Windows GPU 드라이버 업데이트 |
| 터미널 크래시 | `wsl --shutdown` 후 재시도 |
