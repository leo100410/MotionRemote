#!/bin/zsh
# Publishes MotionRemote 1.15 (iPhone 1.15, Dolphin Mac 1.13, DolphiniOS 1.7, MotionSaber 1.3, Monitor 1.0)
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
tag='v1.15'
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
for line in (r/'SHA256SUMS-1.15.txt').read_text().splitlines():
 digest,name=line.split('  ',1)
 assert Path(name).name==name
 assert hashlib.sha256((r/name).read_bytes()).hexdigest()==digest,name
 names.append(name)
assert len(names)==8,names
def no_secrets(z): assert not any(n.endswith(('.p12','.mobileprovision','.key','pairingFile.plist')) for n in z.namelist())
with zipfile.ZipFile(r/'MotionRemote-1.15.ipa') as z:
 assert z.testzip() is None; no_secrets(z)
 assert plistlib.loads(z.read('Payload/MotionRemote.app/Info.plist'))['CFBundleShortVersionString']=='1.15'
with zipfile.ZipFile(r/'DolphiniOS-MotionRemote-1.7.ipa') as z:
 assert z.testzip() is None; no_secrets(z)
 host=plistlib.loads(z.read('Payload/DolphiniOS.app/Info.plist'))
 helper=plistlib.loads(z.read('Payload/DolphiniOS.app/PlugIns/MotionRemoteJITHelper.appex/Info.plist'))
 assert helper['CFBundleIdentifier']==host['CFBundleIdentifier']+'.JITHelper'
for name,app in [('Dolphin-MotionRemote-1.13-macOS-arm64.zip','Dolphin MotionRemote 1.13.app'),('MotionSaber-1.3-macOS-arm64.zip','MotionSaber.app'),('MotionRemote-Monitor-1.0-macOS-arm64.zip','MotionRemote Monitor.app')]:
 with zipfile.ZipFile(r/name) as z:
  assert z.testzip() is None and app+'/Contents/Info.plist' in z.namelist(),name; no_secrets(z)
for name,path in [('Dolphin-MotionRemote-1.13-source.tar.gz','dolphin-2609b/Source/Core/InputCommon/ControllerInterface/DualShockUDPClient/MRConnections.mm'),
                  ('DolphiniOS-MotionRemote-1.7-source.tar.gz','DolphiniOS-MotionRemote-1.7/BuildSupport/StikJIT-2.0.1-source.tar.gz'),
                  ('MotionRemote-1.15-project.tar.gz','MotionRemote/Saber/Sources/SaberGame.swift')]:
 with tarfile.open(r/name) as t: assert path in t.getnames(),(name,path)
print('Release files, matching sources and checksums verified.')
PY
$GH auth setup-git
$GH repo edit "$repo" --description 'Use an iPhone as a motion controller for Dolphin on Mac or iPad, with screen-calibrated pointing, game rumble and the MotionSaber game.'
git add -A .gitignore README.md CHANGELOG.md RELEASE-NOTES-1.15.md publish-1.15.command project.yml Sources Tests Monitor Saber docs DolphinBuild DolphiniOS
if ! git diff --cached --quiet; then
  git commit -m 'Release MotionRemote 1.15: screen calibration, Connections window, multiplayer fixes, MotionSaber and Monitor'
fi
git push origin main
if ! git rev-parse "$tag" >/dev/null 2>&1; then git tag "$tag"; fi
git push origin "$tag"
if ! $GH release view "$tag" --repo "$repo" >/dev/null 2>&1; then
  $GH release create "$tag" --repo "$repo" --verify-tag --draft \
    --title 'MotionRemote 1.15 — screen calibration, multiplayer, MotionSaber' \
    --notes-file RELEASE-NOTES-1.15.md
fi
$GH release upload "$tag" --repo "$repo" --clobber \
  downloads/MotionRemote-1.15.ipa \
  downloads/Dolphin-MotionRemote-1.13-macOS-arm64.zip \
  downloads/DolphiniOS-MotionRemote-1.7.ipa \
  downloads/MotionSaber-1.3-macOS-arm64.zip \
  downloads/MotionRemote-Monitor-1.0-macOS-arm64.zip \
  downloads/Dolphin-MotionRemote-1.13-source.tar.gz \
  downloads/DolphiniOS-MotionRemote-1.7-source.tar.gz \
  downloads/MotionRemote-1.15-project.tar.gz \
  downloads/SHA256SUMS-1.15.txt
$GH release edit "$tag" --repo "$repo" --draft=false --latest
$GH release view "$tag" --repo "$repo" --json url,assets --jq '{url: .url, files: [.assets[].name]}'
