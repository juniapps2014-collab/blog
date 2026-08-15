# Blog (매일 한 가지)

Hugo(PaperMod 테마) 기반 개인 블로그. `hugo-site/`가 사이트 루트이며, GitHub Pages(https://juniapps2014-collab.github.io/blog/)로 배포된다.

- 배포: `scripts/auto-deploy.sh`가 `hugo-site/` 변경분을 커밋/푸시하면 GitHub Actions가 빌드·배포
- 콘텐츠 섹션: english, camera, claude, ai-engineer, coupang(쿠팡파트너스 제휴글)
- 검색 제외가 필요한 글은 front matter에 `robotsNoIndex: true` 사용 (PaperMod 내장 기능)

진행 중인 운영 작업 메모는 `NOTES.local.md`(git 미추적)에 있으니 함께 확인할 것.
