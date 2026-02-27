# orchestration-cli

철이님 요청 기준으로 만든 **Ollama 제외 멀티 오케스트레이션 CLI**입니다.  
macOS에서 바로 실행 가능하도록 구성했습니다.

## 포함 파일
- `roles.yaml`: 역할 → 모델 매핑
- `scripts/dispatch.sh`: 역할 기반 디스패치
- `scripts/model_runner.sh`: 모델 실행기(CLI 우선, API 폴백)
- `scripts/doctor.sh`: macOS 환경 점검
- `scripts/route.sh`: `@봇 [ROLE=..]` 메시지 파싱 라우터

## 고정 모델 5종
- `op4` → `anthropic/claude-opus-4-6`
- `so` → `anthropic/claude-sonnet-4-6`
- `co` → `openai-codex/gpt-5.3-codex`
- `gp` → `google-gemini-cli/gemini-3-pro-preview`
- `GLM` → `zai/glm-5`

## 역할 매핑
- planner → so
- coder → co
- researcher → gp
- operator → GLM
- reviewer → op4

## 실행 순서(macOS)
```bash
cd ~/workspace/orchestration-cli
brew install yq jq
./scripts/doctor.sh
```

실행 예시:
```bash
./scripts/dispatch.sh planner "요구사항을 5개 작업으로 분해"
./scripts/dispatch.sh coder "Node.js API 에러 처리 코드 예시"
./scripts/dispatch.sh reviewer "최종 품질 리뷰 체크리스트"
./scripts/route.sh '@chulclebot [ROLE=planner] 배포 순서 정리해줘'
```

## macOS 앱 형태로 실행
CLI가 익숙하지 않으면 앱으로 빌드해서 더블클릭 실행할 수 있습니다.

```bash
cd ~/workspace/orchestration-cli
./scripts/build_macos_app.sh
```

생성물:
- `dist/OrchestrationCLI.app`

사용법:
1. Finder에서 `dist/OrchestrationCLI.app` 더블클릭
2. 역할(role)과 작업(task) 입력
3. Terminal이 열리며 doctor + dispatch 실행
4. 결과는 `runs/` 폴더에 저장

## 동작 방식
1. 역할에 맞는 모델을 `roles.yaml`에서 선택
2. `model_runner.sh`로 실행
   - 기본: 각 벤더 CLI 우선 시도 (`codex`, `claude`, `gemini`)
   - **기본 정책:** 비-GLM 모델은 유료 API 폴백 비활성(로컬 CLI/GUI 경로 우선)
   - GLM만 API 키 기반 실행
   - 필요 시에만 `ORCH_ALLOW_BILLED_API=1`로 비-GLM API 폴백 임시 활성화
3. 실패 시(비-co 모델) `co`로 1회 자동 폴백

## 출력
- 결과 파일: `runs/YYYYMMDD-HHMMSS-<role>.md`

## 환경변수
기본 정책(권장):
- 비-GLM 모델(`co`, `so`, `op4`, `gp`)은 로컬 CLI 기반 사용 (유료 API 폴백 꺼짐)
- GLM만 API 키 사용
  - `ZHIPUAI_API_KEY` 또는 `GLM_API_KEY`

선택(필요 시만):
- `ORCH_ALLOW_BILLED_API=1` 설정 시 비-GLM API 폴백 허용
  - `OPENAI_API_KEY`
  - `ANTHROPIC_API_KEY`
  - `GEMINI_API_KEY` 또는 `GOOGLE_API_KEY`

민감정보는 `.env`/Keychain만 사용하고, Git에 커밋하지 마세요.

## 그룹 호출 규칙(운영)
- `@봇이름 [ROLE=planner] ...`
- `@봇이름 [TASK_ID=abc-123] ...`
- 결과 포맷: 요약 / 링크 / 체크리스트 명시
