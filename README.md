# 남대문 같이지도

남대문시장 먹거리·쇼핑 정보를 같이 모으는 참여형 지도. 정적 사이트(빌드 도구 없음).

## 구조
- `index.html` — 화면 전체(디자인·감성 지도·실제 지도 탭·장소 카드)
- `config.js` — 공개용 설정(카카오맵 JavaScript 키). **REST API 키·어드민 키·Supabase service_role 키는 절대 넣지 않음**
- `data/places.json` — 장소 데이터(5단계에서 Supabase로 이전 예정). 좌표는 `coord_status: "verified"`인 것만 실제 지도에 표시
- `tools/geocode.html` — 관리자용 좌표 확인 도구(자동 저장 없음, 눈으로 확인 후 반영)
- `backup/` — 클로드 아티팩트에 있던 원본 장소 데이터 백업(2026-10-29)

## 환경 / 키
| 항목 | 공개 여부 | 위치 |
|---|---|---|
| 카카오 JavaScript 키 | 공개용(등록 도메인에서만 동작) | `config.js` |
| Supabase URL·anon 키 | 공개용(RLS로 보호) | 5단계에서 `config.js` |
| Supabase service_role 키 | **비공개** | 코드에 넣지 않음 |

## 진행 상황
- [x] 1~3단계: 구조 분석·백업·비용 정리
- [~] 4단계: 실제 지도 탭 코드 완료, 배포 후 실제 지도 동작 확인 필요 / 좌표 확인 필요
- [ ] 5~10단계: Supabase 인증·DB, 장소 추천·꿀팁, 관리자, 다국어, 모바일 검증, 배포
