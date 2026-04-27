# JustPingPong

LÖVE2D로 만든 단일 파일 Pong 게임. 모든 로직은 [main.lua](main.lua)에 있습니다.

## 실행
- LÖVE2D 11.x 설치 후 `run.bat` 실행 (또는 프로젝트 루트에서 `love .`).
- `hit.wav`가 프로젝트 루트에 있으면 효과음이 재생되고, 없으면 무음으로 진행합니다.

## 조작
| 상황 | 키 | 동작 |
|------|----|------|
| 시작 화면 | `1` | 1P vs AI 시작 |
| 시작 화면 | `2` | 2P 시작 |
| 플레이 중 | `W` / `S` | P1 패들 이동 |
| 플레이 중 | `↑` / `↓` | P2 패들 이동 (2P 모드) |
| 플레이 중 | `M` | 메뉴로 |
| 종료 화면 | `Space` | 같은 모드로 재시작 |
| 종료 화면 | `M` | 메뉴로 |
| 어디서나 | `Esc` | 종료 |

승점은 `WIN_SCORE = 5`. 패들에 맞을 때마다 공 속도가 `SPEED_UP = 1.05`배씩 증가.

## 게임 상태
- `gameState`: `"start"` | `"play"` | `"done"`
- `gameMode`: `"1p"` | `"2p"`
- 시작 화면에서 모드를 골라야 플레이로 진입.

## AI (1P 모드 P2 조작)
[main.lua:111](main.lua:111) `updateAI`.
- 공이 자기 쪽으로 올 때(`ball.dx > 0`)만 추적, `AI_REACT_DIST` 안에 들어오면 적극적으로 추적.
- 멀어질 땐 화면 중앙으로 복귀.
- 떨림 방지용 `AI_DEADZONE = 10px`.
- 난이도 튜닝은 `AI_SPEED` 상수 변경: `0.6=쉬움 / 0.75=보통 / 0.95=어려움`.

## 시각/청각 효과
- **효과음** ([main.lua:46](main.lua:46), [main.lua:64](main.lua:64))
  - `hit.wav`를 `love.audio.newSource(..., "static")`으로 로드 (실패해도 무음으로 계속 진행).
  - 패들 충돌 및 위/아래 벽 반사 시 `playHit()` 호출 — 단일 소스를 `:stop():play()`로 재시작.
- **충돌 파티클** ([main.lua:49](main.lua:49), [main.lua:194](main.lua:194))
  - 2x2 흰색 텍스처 기반 `ParticleSystem`, 패들 충돌 시 충돌 지점에서 `PARTICLE_BURST = 20`개 분사.
  - 수명 0.15~0.45초, 속도 80~260, 사방으로 퍼지며 알파 페이드 아웃.
- **공 궤적(트레일)** ([main.lua:161](main.lua:161), [main.lua:229](main.lua:229))
  - 매 프레임 공의 위치를 `ballTrail[1]`에 push, 길이 `TRAIL_LENGTH = 15`로 유지.
  - 인덱스가 클수록 더 투명하게(최댓값 0.45) 그려 잔상 표현. 공 본체보다 먼저 그려 본체가 위에 보이게 함.
  - `resetBall()`에서 초기화하여 라운드마다 새로 시작.
- **공 모양**: `BALL_SIZE`(=15) 정사각형 영역의 내접원으로 렌더(반지름 7.5). 충돌은 여전히 AABB 기준이라 모서리에서 약간 관대하게 잡힘 — Pong에서는 자연스러운 거동.

## 튜닝 상수 한눈에
[main.lua:5-22](main.lua:5)
- 창/패들/공 크기: `WINDOW_*`, `PADDLE_*`, `BALL_SIZE`
- 속도: `PADDLE_SPEED`, `BALL_BASE_SPD`, `SPEED_UP`
- AI: `AI_SPEED`, `AI_DEADZONE`, `AI_REACT_DIST`
- 이펙트: `TRAIL_LENGTH`, `PARTICLE_BURST`

## 파일
- [main.lua](main.lua) — 전체 게임 로직 (단일 파일)
- [run.bat](run.bat) — Windows 실행 스크립트
- `hit.wav` — 효과음 (사용자가 직접 추가, 선택)
