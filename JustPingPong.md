# JustPingPong

LÖVE2D로 만든 단일 파일 Pong 게임. 모든 로직은 [main.lua](main.lua)에 있습니다.

## 실행
- LÖVE2D 11.x 설치 후 `run.bat` 실행 (또는 프로젝트 루트에서 `love .`).
- `hit.wav`가 프로젝트 루트에 있으면 효과음이 재생되고, 없으면 무음으로 진행합니다.
- `intro.png`가 프로젝트 루트에 있으면 인트로 화면이 표시되고, 없으면 곧바로 시작 화면으로 진입합니다.

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
- 프로그램 시작 시 `introState`(`"hold"` → `"split"` → `nil`)가 시작 화면 위에 오버레이로 진행. 인트로가 끝나면(또는 스킵되면) `gameState = "start"`가 그대로 노출됨.

## 인트로 화면
참조 위치: [main.lua:25-26](main.lua:25) 상수, [main.lua:66-70](main.lua:66) 상태 변수, [main.lua:99-108](main.lua:99) 로드, [main.lua:263-273](main.lua:263) 단계 진행, [main.lua:473-487](main.lua:473) 렌더, [main.lua:499-502](main.lua:499) 스킵.

### 동작 흐름
프로그램 시작 → `"hold"`(1초 정지) → `"split"`(0.5초 좌우 분할) → 시작 화면(`gameState == "start"`).
어느 단계에서든 `Esc`를 제외한 키 입력으로 즉시 시작 화면으로 점프 가능.

```
love.load
  ├─ gameState   := "start"   (백그라운드로 미리 준비)
  └─ introState  := "hold"    (오버레이 활성)
                ↓ 1.0s
              "split"
                ↓ 0.5s        (또는 키 입력 시 즉시)
                nil           (오버레이 종료, 시작 화면이 그대로 드러남)
```

### 상수 / 상태 변수
- 상수 [main.lua:25-26](main.lua:25)
  - `INTRO_HOLD = 1.0` — 인트로 이미지가 정지해 있는 시간(초).
  - `INTRO_SPLIT = 0.5` — 좌우 분할 애니메이션 길이(초).
- 상태 변수 [main.lua:66-70](main.lua:66)
  - `introImage` — 로드된 `Image` 객체. 로드 실패 시 `nil`이며 인트로는 통째로 비활성.
  - `introQuadLeft` / `introQuadRight` — 이미지 좌/우 절반을 가리키는 `Quad`. `love.graphics.draw`에 함께 넘기면 해당 Quad가 정의한 픽셀 영역만 잘라서 렌더.
  - `introState` — `nil` | `"hold"` | `"split"`. `nil`이 정상(인트로 비활성) 상태이고, 그 외 값일 때만 오버레이가 그려지고 게임 업데이트가 정지.
  - `introTimer` — 현재 단계로 진입한 뒤 누적된 시간(초). 단계 전환 시 0으로 리셋.

### 로드 ([main.lua:99-108](main.lua:99))
```lua
local okImg, img = pcall(love.graphics.newImage, "intro.png")
if okImg then
    introImage = img
    local iw, ih = img:getDimensions()
    introQuadLeft  = love.graphics.newQuad(0,      0, iw / 2, ih, iw, ih)
    introQuadRight = love.graphics.newQuad(iw / 2, 0, iw / 2, ih, iw, ih)
    introState = "hold"
    introTimer = 0
end
```
- `pcall`로 감싸서 파일 부재/디코딩 실패에도 게임이 죽지 않도록 함 (`hit.wav`와 동일한 방어 패턴).
- `Quad`는 원본 이미지의 픽셀 좌표·크기를 받음 (`x, y, w, h, sw, sh`). 좌측 절반은 `(0, 0, iw/2, ih)`, 우측 절반은 `(iw/2, 0, iw/2, ih)`. Quad 자체엔 화면 좌표 개념이 없고, 그릴 때 받는 `x, y` 위치와 `sx, sy` 스케일에 따라 화면에 매핑됨.
- 이미지 로드 실패 시 `introState`는 `nil`로 남아 [main.lua:264](main.lua:264)/[main.lua:474](main.lua:474) 분기를 모두 건너뛰므로 별도의 게임 분기가 필요 없음.

### 단계 진행 ([main.lua:263-273](main.lua:263))
```lua
function love.update(dt)
    if introState then
        introTimer = introTimer + dt
        if introState == "hold" and introTimer >= INTRO_HOLD then
            introState = "split"
            introTimer = 0
        elseif introState == "split" and introTimer >= INTRO_SPLIT then
            introState = nil
        end
        return  -- 인트로 동안 게임 로직 정지
    end
    ...
end
```
- 인트로가 활성인 동안 함수 최상단에서 `return`하므로 **파티클 업데이트, 공 이동, 파워업 타이머, 효과 타이머가 모두 정지**. 이렇게 해야 인트로가 끝났을 때 시작 화면이 처음 상태 그대로 드러남.
- 단계 전환 시 `introTimer`를 0으로 리셋해 다음 단계의 0~`duration` 진행도를 다시 측정.

### 렌더 ([main.lua:473-487](main.lua:473))
```lua
if introState and introImage then
    local iw, ih = introImage:getDimensions()
    local sx = WINDOW_WIDTH / iw
    local sy = WINDOW_HEIGHT / ih
    love.graphics.setColor(1, 1, 1, 1)
    if introState == "hold" then
        love.graphics.draw(introImage, 0, 0, 0, sx, sy)
    else
        local progress = math.min(introTimer / INTRO_SPLIT, 1)
        local offset = progress * (WINDOW_WIDTH / 2)
        love.graphics.draw(introImage, introQuadLeft,  -offset,                   0, 0, sx, sy)
        love.graphics.draw(introImage, introQuadRight, WINDOW_WIDTH / 2 + offset, 0, 0, sx, sy)
    end
end
```
- 렌더 순서가 결정적: `love.draw` 본문은 평소대로 `gameState == "start"` 분기를 그려 **시작 화면(타이틀 PONG, 모드 안내 텍스트, 가운데 점선)을 먼저 그림**. 그 위에 인트로 오버레이가 덮이고, 분할이 진행될수록 시작 화면이 갈라진 틈으로 드러남.
- 스케일링: 이미지 원본 비율과 무관하게 윈도우(800×600)에 꽉 차도록 `sx, sy`를 따로 계산해 stretch. 비율이 다른 이미지를 넣으면 가로/세로가 늘어날 수 있음 (의도된 단순화).
- 분할 수식:
  - `progress = introTimer / INTRO_SPLIT`(0→1, `math.min`으로 1 클램프).
  - `offset = progress * (WINDOW_WIDTH / 2)`.
  - 왼쪽 반: `(x = -offset, 0)` → progress=0일 때 (0, 0)~(400, 600), progress=1일 때 (-400, 0)~(0, 600). 화면 왼쪽 바깥으로 빠짐.
  - 오른쪽 반: `(x = WINDOW_WIDTH/2 + offset, 0)` → progress=0일 때 (400, 0)~(800, 600), progress=1일 때 (800, 0)~(1200, 600). 화면 오른쪽 바깥으로 빠짐.
  - 이미지가 화면 바깥으로 나가는 부분은 LÖVE가 자동으로 클리핑.
- `setColor(1, 1, 1, 1)`로 알파 1을 명시 — 직전에 다른 그리기에서 색이 변경되어 있어도 인트로 이미지가 의도한 색으로 그려지도록 보장.

### 스킵 ([main.lua:499-502](main.lua:499))
```lua
function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
        return
    end

    if introState then
        introState = nil
        return
    end
    ...
end
```
- `Esc`는 기존대로 종료(인트로보다 먼저 처리).
- 그 외 어떤 키든 인트로 진행 중이면 `introState`를 `nil`로 만들어 즉시 종료. 단계가 무엇이든(`"hold"`/`"split"`) 동일하게 작동.
- `introState`만 끄고 그 입력은 그대로 소비(`return`)하므로, 스킵에 사용한 키가 시작 화면 입력(예: `1`/`2`)으로 곧바로 흘러가 모드를 시작해 버리는 일은 없음.

### 결정 사항과 그 이유
- **시작 화면을 백그라운드로 미리 그리는 방식**을 택한 이유: 분할 애니메이션 끝 프레임에서 시작 화면으로 전환할 때 한 프레임의 검은 화면이 보이지 않게 하기 위함. 별도 트랜지션 상태를 두는 대신 `gameState == "start"`를 처음부터 활성화해 두고 위에 오버레이만 띄우는 단순한 구조.
- **Quad + scale 방식**: `setScissor`로 클립 영역을 만드는 방법도 있지만, Quad는 좌/우 두 번의 `draw` 호출만으로 동일한 효과를 내고 좌표 계산도 직관적이라 선택.
- **인트로 동안 게임 정지**: 인트로 도중에 파워업 타이머나 파티클이 흐르면 시작 화면이 드러나는 순간 부자연스러울 수 있어, 한 줄짜리 `return`으로 모든 게임 로직을 정지.
- **`pcall` 로드**: `intro.png`를 선택 자산으로 취급해 사용자가 파일 없이도 게임을 실행할 수 있게 함 (`hit.wav`와 동일한 정책).

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

## 랜덤 박스(파워업)
[main.lua:24](main.lua:24) 상수, [main.lua:147-209](main.lua:147) 헬퍼, [main.lua:262](main.lua:262) 업데이트 루프, [main.lua:391](main.lua:391) 렌더.

- **스폰**: 화면이 비어 있을 때 `POWERUP_SPAWN_MIN~MAX`(3~6초) 랜덤 대기 후, 화면 중앙(±60px) 좌표·세로 랜덤 위치에 1개 등장. 동시 1개만 존재.
- **발사**: 좌/우 50:50으로 `POWERUP_SPEED`(240px/s) 직선 이동. 화면 밖으로 나가면 효과 없이 사라지고 다음 타이머 예약.
- **종류 회전**: `POWERUP_SWITCH`(1초)마다 4종(`grow`/`shrink`/`fast`/`slow`) 중 하나로 랜덤 변경. 색상·라벨로 즉시 시각화 — 초록 `+`(grow), 빨강 `-`(shrink), 주황 `>>`(fast), 하늘 `<<`(slow).
- **충돌**: 박스가 패들에 닿는 순간의 종류로 효과 발현, 박스는 즉시 삭제. 공-박스는 통과(상호작용 없음).
- **효과** (모두 `EFFECT_DURATION`=5초 후 원복):
  - `grow`   — 부딪친 패들 높이 ×`PADDLE_GROW_MULT`(1.5)
  - `shrink` — 부딪친 패들 높이 ×`PADDLE_SHRINK_MULT`(0.6)
  - `fast`   — 공 속도 ×`BALL_FAST_MULT`(1.4)
  - `slow`   — 공 속도 ×`BALL_SLOW_MULT`(0.6)
- **중첩 규칙**: 같은 패들에 효과가 이미 있으면 우선 원복 후 재적용(타이머 리셋). 공 속도 효과는 단일 배율(`ballSpeedMult`)만 추적해 새 효과가 덮어씀.
- **라운드 전환**: 득점으로 `resetBall()` 호출 시 공 속도 효과는 리셋(공이 새로 생성되므로). 패들 효과는 유지.

## 튜닝 상수 한눈에
[main.lua:5-48](main.lua:5)
- 창/패들/공 크기: `WINDOW_*`, `PADDLE_*`, `BALL_SIZE`
- 속도: `PADDLE_SPEED`, `BALL_BASE_SPD`, `SPEED_UP`
- AI: `AI_SPEED`, `AI_DEADZONE`, `AI_REACT_DIST`
- 이펙트: `TRAIL_LENGTH`, `PARTICLE_BURST`
- 파워업: `POWERUP_SIZE`, `POWERUP_SPEED`, `POWERUP_SWITCH`, `POWERUP_SPAWN_MIN/MAX`, `EFFECT_DURATION`, `PADDLE_GROW_MULT`, `PADDLE_SHRINK_MULT`, `BALL_FAST_MULT`, `BALL_SLOW_MULT`
- 인트로: `INTRO_HOLD`, `INTRO_SPLIT`

## 파일
- [main.lua](main.lua) — 전체 게임 로직 (단일 파일)
- [run.bat](run.bat) — Windows 실행 스크립트
- [build.ps1](build.ps1) — `.exe` 배포 패키지 빌드 스크립트
- `hit.wav` — 효과음 (사용자가 직접 추가, 선택)
- `intro.png` — 인트로 화면 이미지 (사용자가 직접 추가, 선택)

## 빌드 (.exe 패키징)
[build.ps1](build.ps1) 실행으로 단독 실행형 Windows 배포본을 만든다.

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

### 출력물
- `dist/JustPingPong/JustPingPong.exe` — `love.exe`와 `.love`(zip)을 바이너리 결합한 실행 파일. 같은 폴더의 DLL이 필요.
- `dist/JustPingPong/*.dll`, `*.txt` — `C:\Program Files\LOVE`의 런타임 DLL과 라이선스. 위 exe와 같은 폴더에 있어야 실행됨.
- `dist/JustPingPong-win64.zip` — 위 폴더 전체를 압축한 배포용 zip.
- `dist/JustPingPong-single.exe` — 위의 모든 DLL/txt를 Enigma Virtual Box로 가상 패킹한 **단일 실행 파일**. 별도 파일 없이 단독 배포·실행 가능.

### 사전 요구
- LÖVE 11.x: `C:\Program Files\LOVE\love.exe` (필수)
- Enigma Virtual Box (단일 exe 생성용, 선택): `C:\Program Files (x86)\Enigma Virtual Box\enigmavbconsole.exe`. https://enigmaprotector.com/en/downloads.html 에서 무료 다운로드. 미설치 시 [6/6] 단계는 건너뛰고 폴더/zip만 생성.

### 동작 단계
1. `love.exe`와 `main.lua` 존재 확인. 없으면 즉시 실패.
2. 기존 `dist/` 정리 후 새로 생성.
3. `main.lua` + `hit.wav` + `intro.png`(있는 것만)을 zip 루트에 넣어 `JustPingPong.love` 생성. `Compress-Archive` 대신 `System.IO.Compression.ZipFile` API를 직접 호출 — `Compress-Archive`는 소스 디렉터리 구조를 보존하므로 LÖVE가 요구하는 "zip 루트에 `main.lua`" 구조를 만들 수 없음.
4. `love.exe` 바이트열 + `.love` 바이트열을 직접 이어 붙여(`copy /b`와 동일 결과) `JustPingPong.exe` 생성. 동일 폴더로 `*.dll`, `*.txt`(love.exe 제외) 복사.
5. `Compress-Archive`로 폴더를 `JustPingPong-win64.zip`으로 압축.
6. Enigma Virtual Box로 [4]의 exe와 [4]의 DLL/txt들을 결합하여 `dist/JustPingPong-single.exe` 단일 파일 생성. 일시적으로 `.evb` 프로젝트 파일을 동적 생성 → `enigmavbconsole.exe`로 처리 → `.evb` 삭제.

### Enigma Virtual Box 패킹 ([6/6])
- `.evb`는 Enigma 전용 XML 프로젝트 파일. 빌드 스크립트가 매번 새로 생성하므로 수동 편집 불필요.
- 핵심 옵션:
  - `<Type>3</Type>` — 폴더 노드. `%DEFAULT FOLDER%`(런타임에 exe와 동일 위치로 매핑되는 가상 폴더)에 모든 DLL/txt를 배치.
  - `<Type>2</Type>` — 개별 파일 노드. `<Name>`은 가상 경로 내 파일명, `<File>`은 호스트 측 절대 경로(빌드 시점).
  - `<CompressFiles>true</CompressFiles>` — 패킹 시 압축 (현재 결과: 약 7.26 MB).
  - `<DeleteExtractedOnExit>false</DeleteExtractedOnExit>` — 가상 파일 시스템만 사용하므로 임시 추출 없음 (메모리 접근만 사용).
  - `<ShareVirtualSystem>false</ShareVirtualSystem>` — 다른 프로세스에 가상 FS 공유 안 함.
  - `<MapExecutableWithTemporaryFile>false</MapExecutableWithTemporaryFile>` — exe 자체는 임시 파일로 풀지 않음.
- 실패해도 폴더/zip 결과물은 보존됨 (스크립트가 경고만 남기고 종료).

### 변경 포인트
- **LÖVE 설치 경로**: `$LoveDir = "C:\Program Files\LOVE"`. 다른 위치에 설치되어 있으면 이 줄만 수정.
- **Enigma Virtual Box 경로**: `$EnigmaDir = "C:\Program Files (x86)\Enigma Virtual Box"`. 다른 위치 설치 시 수정.
- **포함 파일**: `$SourceFiles = @("main.lua", "hit.wav", "intro.png")`. 새 자산을 추가하면 이 배열에 등록.
- DLL/txt 자동 수집: `$BuildDir`에서 `JustPingPong.exe`를 제외한 모든 파일이 자동으로 가상 패킹 대상이 되므로 새 런타임 DLL이 추가돼도 별도 등록 불필요.
- 32bit/아이콘 변경은 미지원 — 필요 시 별도 작업.

## 개선 사항
- [x] 랜덤 박스
	- 화면 중앙에 랜덤하게 생성
		- 4가지 기능 중 하나를 랜덤하게 가짐
		- 가지고 있는 기능에 따라 랜덤 박스의 색깔을 다르게 함
	- 좌우로 랜덤하게 발사
	- 랜덤 박스는 1초 단위로 랜덤하게 기능이 바뀜
	- 패들에 부딪치면 랜덤 박스가 가진 기능 발현
	    - 부딪친 패들 늘리기, 줄이기
	    - 공 속도 빠르게, 느리게
	- 부딪친 랜덤 박스는 삭제
	- 발현된 기능은 5초 후 초기화
- [x] 인트로 화면
	- 프로그램 로딩 시 인트로 화면(intro.png)이 보임
	- 1초 뒤 인트로 화면 좌우가 갈리면서 플레이 화면이 보임