#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h}"
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
GH=/opt/homebrew/bin/gh
finish() {
  result=$?
  if (( result != 0 )); then print '\nUpload stopped. Read the error above. No force-push was used.'; fi
  print '\nPress Enter to close.'
  read -r answer
}
trap finish EXIT
login="$($GH api user --jq .login)"
if [[ "$login" != leo100410 ]]; then
  print "Stopped: expected leo100410, authenticated as $login. Your other account was not changed."
  exit 1
fi
repo='leo100410/MotionRemote'
tag='ipados-v1.2'
if [[ "$(git remote get-url origin)" != "https://github.com/$repo.git" || "$(git branch --show-current)" != main ]]; then
  print 'Stopped: expected the MotionRemote repository on branch main.'
  exit 1
fi
if ! git diff --cached --quiet; then
  print 'Stopped: other changes are already staged. Commit or unstage them before running this uploader.'
  exit 1
fi
python3 - <<'PY'
from pathlib import Path
import hashlib,plistlib,zipfile,tarfile
r=Path('downloads')
for line in (r/'SHA256SUMS-ipados-1.2.txt').read_text().splitlines():
 digest,name=line.split('  ',1)
 assert Path(name).name==name
 assert hashlib.sha256((r/name).read_bytes()).hexdigest()==digest,name
with zipfile.ZipFile(r/'DolphiniOS-MotionRemote-1.2.ipa') as z:
 assert z.testzip() is None
 host=plistlib.loads(z.read('Payload/DolphiniOS.app/Info.plist'))
 helper=plistlib.loads(z.read('Payload/DolphiniOS.app/PlugIns/MotionRemoteJITHelper.appex/Info.plist'))
 assert host['CFBundleVersion']==helper['CFBundleVersion']=='3'
 assert helper['CFBundleIdentifier']==host['CFBundleIdentifier']+'.JITHelper'
 assert 2 in host['UIDeviceFamily']
 assert not any(n.endswith(('.p12','.mobileprovision','pairingFile.plist')) for n in z.namelist())
with tarfile.open(r/'DolphiniOS-MotionRemote-1.2-source.tar.gz') as t:
 names=set(t.getnames())
 for p in ['Source/iOS/App/DolphiniOS.xcodeproj/project.pbxproj','BuildSupport/JITHelper/JITHelper.swift','BuildSupport/StikJIT-2.0.1-source.tar.gz','COPYING']:
  assert 'DolphiniOS-MotionRemote-1.2/'+p in names,p
print('IPA, matching source and checksums verified.')
PY
$GH auth setup-git
$GH repo view "$repo" >/dev/null
$GH repo edit "$repo" --description 'Use an iPhone as a motion controller for Dolphin on Mac or iPad, with camera-assisted pointing and game rumble.' 
git add .gitignore README.md docs/IPADOS.md docs/THIRD-PARTY.md DolphiniOS RELEASE-NOTES-ipados-1.2.md publish-ipados-1.2.command
if ! git diff --cached --quiet; then
  git commit -m 'Add DolphiniOS MotionRemote for iPad with built-in JIT and controller setup'
fi
git push origin main
if ! git rev-parse "$tag" >/dev/null 2>&1; then git tag "$tag"; fi
git push origin "$tag"
if ! $GH release view "$tag" --repo "$repo" >/dev/null 2>&1; then
  $GH release create "$tag" --repo "$repo" --verify-tag --draft --latest=false \
    --title 'DolphiniOS MotionRemote 1.2 — iPad emulator with built-in JIT' \
    --notes-file RELEASE-NOTES-ipados-1.2.md
fi
$GH release upload "$tag" --repo "$repo" \
  downloads/DolphiniOS-MotionRemote-1.2.ipa \
  downloads/DolphiniOS-MotionRemote-1.2-source.tar.gz \
  downloads/SHA256SUMS-ipados-1.2.txt --clobber
$GH release edit "$tag" --repo "$repo" --draft=false --latest=false
$GH release view "$tag" --repo "$repo" --json url,assets --jq '{url: .url, files: [.assets[].name]}'
