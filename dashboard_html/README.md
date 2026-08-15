# WFSAT 정적 학습 대시보드

`index.html`은 별도 서버나 설치 없이 사용할 수 있는 단일 HTML 파일입니다.

## 공유 방법

1. `index.html`을 다운로드합니다.
2. Chrome, Edge 또는 Safari에서 파일을 엽니다.
3. 파일 자체를 메일, 메신저 또는 클라우드 드라이브로 공유할 수 있습니다.

CSS, JavaScript와 네 가지 공격의 일반·심화 학습 데이터가 모두 HTML 안에 포함되어 있습니다. Google 웹 폰트를 불러오지 못하는 오프라인 환경에서는 운영체제 기본 산세리프 글꼴로 표시됩니다.

## 공유 가능한 화면 상태

HTML 주소 뒤에 다음 파라미터를 사용할 수 있습니다.

- `attack`: `evil_twin`, `deauth`, `beacon_flood`, `handshake`
- `step`: `0`부터 `4`
- `advanced=1`: 심화 학습 모드
- `theme=dark`: 다크 모드
- `tab`: `learn`, `detect`, `defense`, `simulation`

예시:

```text
index.html?attack=evil_twin&step=3&advanced=1&theme=dark
```

## 다시 생성하기

Streamlit 학습 데이터가 변경된 경우 저장소 루트에서 실행합니다.

```bash
python dashboard/export_static.py
```
