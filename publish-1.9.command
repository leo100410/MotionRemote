#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h}"
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
GH=/opt/homebrew/bin/gh
finish() {
  result=$?
  if (( result != 0 )); then print '\nUpload stopped. See the error above; no force-push was used.'; fi
  print '\nPress Enter to close.'
  read -r answer
}
trap finish EXIT
login="$($GH api user --jq .login)"
if [[ "$login" != leo100410 ]]; then
  print "Stopped: expected leo100410, authenticated as $login."
  exit 1
fi
repo="$login/MotionRemote"
expected="https://github.com/$repo.git"
if [[ "$(git remote get-url origin)" != "$expected" ]]; then
  print 'Stopped: repository origin does not match the expected account.'
  exit 1
fi
python3 - <<'PY'
from pathlib import Path
import hashlib,plistlib,zipfile
r=Path('downloads')
for line in (r/'SHA256SUMS-1.9.txt').read_text().splitlines():
 digest,name=line.split('  ',1)
 assert hashlib.sha256((r/name).read_bytes()).hexdigest()==digest,name
with zipfile.ZipFile(r/'MotionRemote-1.9.ipa') as z:
 assert z.testzip() is None
 assert plistlib.loads(z.read('Payload/MotionRemote.app/Info.plist'))['CFBundleShortVersionString']=='1.9'
print('Release files verified.')
PY
$GH auth setup-git
$GH repo view "$repo" >/dev/null
git add Sources Tests/Volume project.yml README.md CHANGELOG.md docs RELEASE-NOTES-1.9.md publish-1.9.command
if ! git diff --cached --quiet; then
  git commit -m 'Map Volume Down to B with independent button hold states'
fi
git push origin main
if ! git rev-parse v1.9 >/dev/null 2>&1; then git tag v1.9; fi
git push origin v1.9
if ! $GH release view v1.9 --repo "$repo" >/dev/null 2>&1; then
  $GH release create v1.9 --repo "$repo" --verify-tag --title 'MotionRemote 1.9 — Volume Down as B' --notes-file RELEASE-NOTES-1.9.md
fi
$GH release upload v1.9 --repo "$repo" downloads/MotionRemote-1.9.ipa downloads/MotionRemote-1.9-project.tar.gz downloads/SHA256SUMS-1.9.txt --clobber
$GH release view v1.9 --repo "$repo" --json url,assets --jq '{url: .url, files: [.assets[].name]}'
