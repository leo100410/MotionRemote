#!/bin/zsh
# Publishes release 1.20 (iPhone 1.20 plus the Mac apps) and sets which older releases are stable or pre-releases
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
tag='v1.20'
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
expected=['MotionRemote-1.20.ipa','Dolphin-MotionRemote-1.13-macOS-arm64.zip','MotionSaber-1.3-macOS-arm64.zip','MotionRemote-Monitor-1.0-macOS-arm64.zip','Dolphin-MotionRemote-1.13-source.tar.gz','MotionRemote-1.20-project.tar.gz']
names=[]
for line in (r/'SHA256SUMS-1.20.txt').read_text().splitlines():
 digest,name=line.split('  ',1)
 assert Path(name).name==name
 assert hashlib.sha256((r/name).read_bytes()).hexdigest()==digest,name
 names.append(name)
assert names==expected,names
def no_secrets(z): assert not any(n.endswith(('.p12','.mobileprovision','.key','pairingFile.plist')) for n in z.namelist())
with zipfile.ZipFile(r/'MotionRemote-1.20.ipa') as z:
 assert z.testzip() is None; no_secrets(z)
 assert plistlib.loads(z.read('Payload/MotionRemote.app/Info.plist'))['CFBundleShortVersionString']=='1.20'
for name,app in [('Dolphin-MotionRemote-1.13-macOS-arm64.zip','Dolphin MotionRemote 1.13.app'),('MotionSaber-1.3-macOS-arm64.zip','MotionSaber.app'),('MotionRemote-Monitor-1.0-macOS-arm64.zip','MotionRemote Monitor.app')]:
 with zipfile.ZipFile(r/name) as z: assert z.testzip() is None and app+'/Contents/Info.plist' in z.namelist(),name; no_secrets(z)
with tarfile.open(r/'MotionRemote-1.20-project.tar.gz') as t: assert 'MotionRemote/Sources/RemoteView.swift' in t.getnames()
print('Release files and checksums verified.')
PY
$GH auth setup-git
git add -A README.md CHANGELOG.md RELEASE-NOTES-1.20.md publish-1.20.command project.yml Sources docs
if ! git diff --cached --quiet; then
  git commit -m 'Release MotionRemote 1.20: full-size buttons, with the Mac apps'
fi
git push origin main
if ! git rev-parse "$tag" >/dev/null 2>&1; then git tag "$tag"; fi
git push origin "$tag"
if ! $GH release view "$tag" --repo "$repo" >/dev/null 2>&1; then
  $GH release create "$tag" --repo "$repo" --verify-tag --draft \
    --title 'MotionRemote 1.20' \
    --notes-file RELEASE-NOTES-1.20.md
fi
$GH release upload "$tag" --repo "$repo" --clobber \
  downloads/MotionRemote-1.20.ipa \
  downloads/Dolphin-MotionRemote-1.13-macOS-arm64.zip \
  downloads/MotionSaber-1.3-macOS-arm64.zip \
  downloads/MotionRemote-Monitor-1.0-macOS-arm64.zip \
  downloads/Dolphin-MotionRemote-1.13-source.tar.gz \
  downloads/MotionRemote-1.20-project.tar.gz \
  downloads/SHA256SUMS-1.20.txt
$GH release edit "$tag" --repo "$repo" --draft=false --prerelease=false --latest
# Older releases: 1.08 and 1.09 and everything after 1.10 become pre-releases; 1.10 stays a stable release.
# Rename the tags v1.8 → v1.08 and v1.9 → v1.09: new tag on the same commit, move the release, delete the old tag.
for pair in 'v1.8 v1.08 MotionRemote 1.08' 'v1.9 v1.09 MotionRemote 1.09 — Volume Down as B'; do
  old_tag="${pair%% *}"; rest="${pair#* }"; new_tag="${rest%% *}"; title="${rest#* }"
  if git rev-parse "$old_tag" >/dev/null 2>&1; then
    git tag -f "$new_tag" "$old_tag^{}"
    git push origin "$new_tag"
    $GH release edit "$old_tag" --repo "$repo" --tag "$new_tag" --prerelease --title "$title"
    git push origin ":refs/tags/$old_tag"
    git tag -d "$old_tag"
  else
    $GH release edit "$new_tag" --repo "$repo" --prerelease --title "$title"
  fi
done
$GH release edit v1.10 --repo "$repo" --prerelease=false --latest=false
for beta in ipados-v1.2 v1.15 v1.17; do $GH release edit "$beta" --repo "$repo" --prerelease; done
$GH release list --repo "$repo" --limit 10
$GH release view "$tag" --repo "$repo" --json url,assets --jq '{url: .url, files: [.assets[].name]}'
