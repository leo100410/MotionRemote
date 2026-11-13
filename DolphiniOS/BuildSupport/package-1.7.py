from pathlib import Path
import shutil,plistlib,subprocess,zipfile,hashlib
root=Path(__file__).resolve().parents[1]
app=root/'BuildSupport/DerivedData/Build/Products/Release (Non-Jailbroken)-iphoneos/DolphiniOS.app'
stage=root/'BuildSupport/package-1.7'
destination=stage/'Payload/DolphiniOS.app'
assert not stage.exists(),'Existing package preserved'
info=plistlib.loads((app/'Info.plist').read_bytes())
assert info['CFBundleIdentifier']=='com.leolange.motionremote.DolphiniOS-njb'
assert 2 in info['UIDeviceFamily']
shutil.copytree(app,destination,symlinks=True)
# Retain upstream public JIT entitlements so a signing tool can inspect them.
entitlements=root/'Source/iOS/App/Project/Entitlements/Public.entitlements'
for framework in (destination/'Frameworks').iterdir():
 subprocess.run(['codesign','--force','--sign','-',str(framework)],check=True)
helper=destination/'PlugIns/MotionRemoteJITHelper.appex'
assert helper.is_dir(), 'JIT helper missing'
helper_info=plistlib.loads((helper/'Info.plist').read_bytes())
assert helper_info['CFBundleIdentifier']==info['CFBundleIdentifier']+'.JITHelper'
assert helper_info['CFBundleVersion']==info['CFBundleVersion']=='4'
assert helper_info['CFBundleShortVersionString']==info['CFBundleShortVersionString']
assert helper_info['NSExtension']['NSExtensionPointIdentifier']=='com.apple.ar.viewer'
assert '_remotepairing._tcp' in info['NSBonjourServices']
subprocess.run(['codesign','--force','--sign','-',str(helper)],check=True)
subprocess.run(['codesign','--force','--sign','-','--entitlements',str(entitlements),str(destination)],check=True)
subprocess.run(['codesign','--verify','--deep','--strict',str(destination)],check=True)
for executable in [destination/info['CFBundleExecutable'],destination/'Frameworks/libdolphin.dylib',destination/'Frameworks/MoltenVK.framework/MoltenVK', destination/'Frameworks/StikJIT.framework/StikJIT',helper/helper_info['CFBundleExecutable']]:
 output=subprocess.check_output(['otool','-L',str(executable)],text=True)
 assert all(not line.strip().startswith(('/Users/','/opt/')) for line in output.splitlines()[1:]),output
 build=subprocess.check_output(['otool','-l',str(executable)],text=True)
 assert 'platform 2' in build or 'LC_VERSION_MIN_IPHONEOS' in build,executable
main_dependencies=subprocess.check_output(['otool','-L',str(destination/info['CFBundleExecutable'])],text=True)
assert 'StikJIT.framework' not in main_dependencies, 'Only the helper may link StikJIT'
helper_dependencies=subprocess.check_output(['otool','-L',str(helper/helper_info['CFBundleExecutable'])],text=True)
assert '@rpath/StikJIT.framework/StikJIT' in helper_dependencies
helper_commands=subprocess.check_output(['otool','-l',str(helper/helper_info['CFBundleExecutable'])],text=True)
assert '@executable_path/../../Frameworks' in helper_commands
ipa=root/'DolphiniOS-MotionRemote-1.7.ipa'
with zipfile.ZipFile(ipa,'w',zipfile.ZIP_DEFLATED) as archive:
 for file in stage.rglob('*'):
  if file.is_file():archive.write(file,file.relative_to(stage))
with zipfile.ZipFile(ipa) as archive:
 assert archive.testzip() is None
 assert 'Payload/DolphiniOS.app/Frameworks/libdolphin.dylib' in archive.namelist()
 assert 'Payload/DolphiniOS.app/PlugIns/MotionRemoteJITHelper.appex/MotionRemoteJITHelper' in archive.namelist()
 assert 'Payload/DolphiniOS.app/Frameworks/StikJIT.framework/StikJIT' in archive.namelist()
 assert not any(name.endswith(('.p12','.mobileprovision','.key')) for name in archive.namelist())
checksums=[]
for item in sorted(root.glob('DolphiniOS-MotionRemote-*.ipa')):
 checksums.append(hashlib.sha256(item.read_bytes()).hexdigest()+'  '+item.name)
(root/'SHA256SUMS.txt').write_text('\n'.join(checksums)+'\n')
print('Verified iPad IPA:',ipa,round(ipa.stat().st_size/1024/1024,2),'MiB')
