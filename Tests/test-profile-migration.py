from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]/'DolphinBuild/dolphin-2609b/Source/Core'
s=(root/'InputCommon/ControllerEmu/ControllerEmu.cpp').read_text()
a=s.index('  // Migrate existing MotionRemote mappings');b=s.index('  LoadGroupsConfig(sec, "");',a)
code=s[a:b]
harness='''#include <algorithm>
#include <string>
#include <map>
#include <vector>
#include <memory>
#include <cassert>
#include <cstdio>
struct Device {std::string source,name;};
struct Group {std::string name;};
struct Section {std::map<std::string,bool>values;bool Exists(const std::string& k)const{return values.contains(k);}void Set(const std::string& k,bool v){values[k]=v;}};
void migrate(Device selectedDevice,Section* sec,bool isWiimote=true,bool hasDevice=true){
 std::string defdev=hasDevice?"configured":"";
 auto GetDefaultDevice=[&]() -> const Device& {return selectedDevice;};
 std::vector<std::unique_ptr<Group>>groups;
 if(isWiimote)groups.push_back(std::make_unique<Group>(Group{"IMUIR"}));
'''+code+'''}
int main(){
 Section sec;migrate({"DSUClient","MotionRemote"},&sec);assert(sec.values.at("IMUIR/Preserve Angle"));
 sec.values.clear();migrate({"DSUClient","MotionRemote P2"},&sec);assert(sec.values.at("IMUIR/Preserve Angle"));
 sec.values["IMUIR/Preserve Angle"]=false;migrate({"DSUClient","MotionRemote"},&sec);assert(!sec.values.at("IMUIR/Preserve Angle"));
 sec.values.clear();migrate({"SDL","MotionRemote"},&sec);assert(sec.values.empty());
 migrate({"DSUClient","Other controller"},&sec);assert(sec.values.empty());
 migrate({"DSUClient","MotionRemote"},&sec,false);assert(sec.values.empty());
 migrate({"DSUClient","MotionRemote"},&sec,true,false);assert(sec.values.empty());
 puts("Actual configuration migration passed: missing value enabled for MotionRemote P1/P2, explicit false preserved, unrelated devices and non-Wii controllers untouched");
}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.cpp';exe=Path(d)/'test';p.write_text(harness)
 subprocess.run(['/usr/bin/clang++','-std=c++20',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True)
