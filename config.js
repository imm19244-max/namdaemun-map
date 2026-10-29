// 공개용 설정만 넣는 파일 (브라우저에 그대로 노출됨)
// ✅ 넣어도 되는 것: 카카오 JavaScript 키(등록 도메인에서만 동작), Supabase URL, Supabase publishable(anon) 키(RLS로 보호)
// ❌ 절대 넣지 말 것: 카카오 REST API/어드민 키, Supabase secret/service_role 키, DB 비밀번호
window.APP_CONFIG = {
  KAKAO_JS_KEY: "a87ec20fbf6c9bd925717b8160f221f9",
  SUPABASE_URL: "https://yuddmgjbvpmkevmtakzb.supabase.co",
  SUPABASE_KEY: "sb_publishable_eBnG__LUNwRPkTHvtBxgyA_XN1lbUUe"
};
