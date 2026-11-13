from pathlib import Path
import re, subprocess, tempfile, configparser, json
root = Path(__file__).resolve().parents[2]
source = (root/'Source/Core/InputCommon/ControllerInterface/DualShockUDPClient/MRConnections.mm').read_text()
assignments = '\n'.join(re.findall(r'  section->Set\([^\n]+', source))
profile = configparser.ConfigParser(interpolation=None)
profile.optionxform = str
profile.read(root/'BuildSupport/Tests/Fixtures/MotionRemote.ini')
checks = '\n'.join('if(values.at('+json.dumps(k)+') != '+json.dumps(v)+') { std::cerr << '+json.dumps(k)+ ' << " became " << values.at('+json.dumps(k)+') << "\\n"; return 1; }' for k,v in profile['Profile'].items())
code = '''#include "Common/IniFile.h"
#include <map>
#include <iostream>
std::map<std::string,std::string> values;
std::string ValueToString(bool value) { return value ? "True" : "False"; }
namespace Common {
bool CaseInsensitiveLess::operator()(std::string_view a, std::string_view b) const { return a < b; }
IniFile::Section::Section() = default;
void IniFile::Section::Set(const std::string& key, std::string value) { ::values[key] = value; }
}
int main() {
for(int slot=0;slot<4;++slot) for(int pad:{slot,0}) {
const int player=slot+1;
const std::string name=slot==0?"MotionRemote":"MotionRemote P"+std::to_string(player);
Common::IniFile::Section object;
auto* section=&object;
''' + assignments + '''
// A phone left on player 1 (pad 0) still gets its own named device for any player.
if (values.at("Device") != "DSUClient/"+std::to_string(pad)+"/"+name) return 2;
if (slot==0) {
''' + checks + '''
}
}
}
'''
with tempfile.TemporaryDirectory() as d:
    cpp=Path(d)/'profile.cpp'; cpp.write_text(code)
    exe=Path(d)/'profile'
    subprocess.run(['/usr/bin/clang++','-std=c++20','-I'+str(root/'Source/Core'),'-I'+str(root/'Externals/fmt/fmt/include'),str(cpp),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True)
print('PASS: new Connections menu profile assignments use Dolphin INI overloads correctly; all mappings match the working desktop profile; players 1–4 have distinct device identifiers, also when every phone serves slot 0')
