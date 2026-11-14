#!/bin/zsh
# Publishes release 1.27 (iPhone 1.27, Dolphin 1.18, MotionSaber 1.4, Monitor 1.1) as commit, tag v1.27 and
# GitHub release, makes it the latest release and marks every older release as a pre-release. Run it yourself; it never force-pushes.
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
tag='v1.27'
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
expected=['MotionRemote-1.27.ipa','Dolphin-MotionRemote-1.18-macOS-arm64.zip','MotionSaber-1.4-macOS-arm64.zip','MotionRemote-Monitor-1.1-macOS-arm64.zip','Dolphin-MotionRemote-1.18-source.tar.gz','MotionRemote-1.27-project.tar.gz']
names=[]
for line in (r/'SHA256SUMS-1.27.txt').read_text().splitlines():
 digest,name=line.split('  ',1)
 assert Path(name).name==name
 assert hashlib.sha256((r/name).read_bytes()).hexdigest()==digest,name
 names.append(name)
assert names==expected,names
def no_secrets(z): assert not any(n.endswith(('.p12','.mobileprovision','.key','pairingFile.plist')) for n in z.namelist())
with zipfile.ZipFile(r/'MotionRemote-1.27.ipa') as z:
 assert z.testzip() is None; no_secrets(z)
 assert plistlib.loads(z.read('Payload/MotionRemote.app/Info.plist'))['CFBundleShortVersionString']=='1.27'
for name,app in [('Dolphin-MotionRemote-1.18-macOS-arm64.zip','Dolphin MotionRemote 1.18.app'),('MotionSaber-1.4-macOS-arm64.zip','MotionSaber.app'),('MotionRemote-Monitor-1.1-macOS-arm64.zip','MotionRemote Monitor.app')]:
 with zipfile.ZipFile(r/name) as z: assert z.testzip() is None and app+'/Contents/Info.plist' in z.namelist(),name; no_secrets(z)
with tarfile.open(r/'MotionRemote-1.27-project.tar.gz') as t: assert 'MotionRemote/Sources/Grip.swift' in t.getnames()
with tarfile.open(r/'Dolphin-MotionRemote-1.18-source.tar.gz') as t:
 d='dolphin-2609b/Source/Core/InputCommon/ControllerInterface/DualShockUDPClient/'
 assert d+'MotionRemoteTrace.h' in t.getnames()
print('Release files and checksums verified.')
PY
$GH auth setup-git
git add -A README.md CHANGELOG.md RELEASE-NOTES-1.27.md publish-1.27.command project.yml Sources Tests Monitor Saber DolphinBuild docs
if ! git diff --cached --quiet; then
  git commit -m 'Release MotionRemote 1.27: tennis axis fix and grip detection'
fi
git push origin main
if ! git rev-parse "$tag" >/dev/null 2>&1; then git tag "$tag"; fi
git push origin "$tag"
if ! $GH release view "$tag" --repo "$repo" >/dev/null 2>&1; then
  $GH release create "$tag" --repo "$repo" --verify-tag --draft \
    --title 'MotionRemote 1.27' \
    --notes-file RELEASE-NOTES-1.27.md
fi
$GH release upload "$tag" --repo "$repo" --clobber \
  downloads/MotionRemote-1.27.ipa \
  downloads/Dolphin-MotionRemote-1.18-macOS-arm64.zip \
  downloads/MotionSaber-1.4-macOS-arm64.zip \
  downloads/MotionRemote-Monitor-1.1-macOS-arm64.zip \
  downloads/Dolphin-MotionRemote-1.18-source.tar.gz \
  downloads/MotionRemote-1.27-project.tar.gz \
  downloads/SHA256SUMS-1.27.txt
# Every older release, including the former stable 1.10 and 1.20, becomes a pre-release.
for old in $($GH release list --repo "$repo" --limit 100 --json tagName --jq '.[].tagName'); do
  if [[ "$old" != "$tag" ]]; then $GH release edit "$old" --repo "$repo" --prerelease; fi
done
$GH release edit "$tag" --repo "$repo" --draft=false --prerelease=false --latest
$GH release list --repo "$repo" --limit 10
$GH release view "$tag" --repo "$repo" --json url,assets --jq '{url: .url, files: [.assets[].name]}'
