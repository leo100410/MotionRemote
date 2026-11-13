#!/bin/zsh
# Publishes the MotionRemote 1.17 iPhone app
# as commit, tag v1.15 and GitHub release. Run it yourself; it never force-pushes.
set -euo pipefail
cd -- "${0:A:h}"
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
GH=/opt/homebrew/bin/gh
finish() {
  result=$?
  if (( result != 0 )); then print '\nUpload stopped. Read the error above. Nothing was force-pushed.'; fi
  print '\nPress Enter to close.'
  read -r answer
}
trap finish EXIT
repo='leo100410/MotionRemote'
tag='v1.17'
login="$($GH api user --jq .login)"
if [[ "$login" != leo100410 ]]; then
  print "Stopped: expected leo100410, authenticated as $login. Your other account was not changed."
  exit 1
fi
if [[ "$(git remote get-url origin)" != "https://github.com/$repo.git" || "$(git branch --show-current)" != main ]]; then
  print 'Stopped: expected the MotionRemote repository on branch main.'
  exit 1
fi
if ! git diff --cached --quiet; then
  print 'Stopped: other changes are already staged. Commit or unstage them before running this uploader.'
  exit 1
fi
git fetch origin main
if [[ "$(git rev-list --count HEAD..origin/main)" != 0 ]]; then
  print 'Stopped: GitHub has commits that are not on this Mac. Pull them first.'
  exit 1
fi
python3 - <<'PY'
from pathlib import Path
import hashlib,plistlib,zipfile,tarfile
r=Path('downloads')
names=[]
for line in (r/'SHA256SUMS-1.17.txt').read_text().splitlines():
 digest,name=line.split('  ',1)
 assert Path(name).name==name
 assert hashlib.sha256((r/name).read_bytes()).hexdigest()==digest,name
 names.append(name)
assert names==['MotionRemote-1.17.ipa','MotionRemote-1.17-project.tar.gz'],names
with zipfile.ZipFile(r/'MotionRemote-1.17.ipa') as z:
 assert z.testzip() is None
 assert not any(n.endswith(('.p12','.mobileprovision','.key','pairingFile.plist')) for n in z.namelist())
 assert plistlib.loads(z.read('Payload/MotionRemote.app/Info.plist'))['CFBundleShortVersionString']=='1.17'
with tarfile.open(r/'MotionRemote-1.17-project.tar.gz') as t: assert 'MotionRemote/Sources/SpatialTracker.swift' in t.getnames()
print('Release files and checksums verified.')
PY
$GH auth setup-git
git add -A README.md CHANGELOG.md RELEASE-NOTES-1.17.md publish-1.17.command project.yml Sources docs
if ! git diff --cached --quiet; then
  git commit -m 'Release MotionRemote 1.17: redesigned controller screen and Forget Saved Room fix'
fi
git push origin main
if ! git rev-parse "$tag" >/dev/null 2>&1; then git tag "$tag"; fi
git push origin "$tag"
if ! $GH release view "$tag" --repo "$repo" >/dev/null 2>&1; then
  $GH release create "$tag" --repo "$repo" --verify-tag --draft \
    --title 'MotionRemote 1.17 — redesigned iPhone app' \
    --notes-file RELEASE-NOTES-1.17.md
fi
$GH release upload "$tag" --repo "$repo" --clobber \
  downloads/MotionRemote-1.17.ipa \
  downloads/MotionRemote-1.17-project.tar.gz \
  downloads/SHA256SUMS-1.17.txt
$GH release edit "$tag" --repo "$repo" --draft=false --latest
$GH release view "$tag" --repo "$repo" --json url,assets --jq '{url: .url, files: [.assets[].name]}'
