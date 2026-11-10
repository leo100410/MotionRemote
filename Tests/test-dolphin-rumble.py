from pathlib import Path
import subprocess, tempfile, struct, zlib
root=Path(__file__).resolve().parents[1]
s=(root/'DolphinBuild/dolphin-2609b/Source/Core/InputCommon/ControllerInterface/DualShockUDPClient/DualShockUDPClient.cpp').read_text()
command=s[s.index('struct MotionRemoteRumble'):s.index('class Device final')]
output=s[s.index('  class RumbleOutput final'):s.index('  class BatteryInput final')]
harness='''#include <array>
#include <atomic>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <string>
#include <cassert>
#include <cstdio>
using u8=uint8_t; using u16=uint16_t; using u32=uint32_t; using u64=uint64_t;
using ControlState=double;
namespace Proto { constexpr std::array<u8,4> SERVER{'D','S','U','S'}; constexpr std::array<u8,4> CLIENT{'D','S','U','C'}; struct MessageHeader { std::array<u8,4> source; u16 version; u16 length; u32 crc; u32 uid; }; }
class Output { public: virtual std::string GetName() const=0; virtual void SetState(ControlState)=0; virtual ~Output()=default; };
'''+command+output+'''
int main() {
 std::atomic<float> strength{0}; RumbleOutput output(strength);
 assert(output.GetName()=="Motor");
 output.SetState(2); assert(strength==1); output.SetState(-1); assert(strength==0);
 output.SetState(NAN); assert(strength==0); output.SetState(0.5); assert(strength==0.5);
 MotionRemoteRumble cmd{};
 cmd.header.source=Proto::CLIENT; cmd.header.version=1001; cmd.header.length=12; cmd.header.uid=123;
 cmd.message_type=0x100003; cmd.pad_id=2; cmd.strength=255; cmd.sequence=9;
 auto bytes=reinterpret_cast<const u8*>(&cmd); u32 crc=0xffffffff;
 for (unsigned i=0;i<sizeof(cmd);++i) { crc^=bytes[i]; for(int k=0;k<8;++k)crc=(crc>>1)^((crc&1)?0xedb88320:0); }
 cmd.header.crc=~crc; std::fwrite(&cmd,1,sizeof(cmd),stdout);
}
'''
with tempfile.TemporaryDirectory() as folder:
 source=Path(folder)/'test.cpp';exe=Path(folder)/'test';source.write_text(harness)
 subprocess.run(['/usr/bin/clang++','-std=c++20',str(source),'-o',str(exe)],check=True)
 b=subprocess.check_output([str(exe)])
 assert len(b)==28 and b[:4]==b'DSUC'
 c=bytearray(b);c[8:12]=bytes(4)
 assert zlib.crc32(c)==struct.unpack_from('<I',b,8)[0]
 assert struct.unpack_from('<I',b,16)[0]==0x100003
 assert b[20:24]==bytes([2,255,0,0]) and struct.unpack_from('<I',b,24)[0]==9
 (Path('/tmp')/'motionremote-native-rumble.bin').write_bytes(b)
print('Actual Dolphin Motor class: clamps invalid intensities; C++ packet layout and CRC match Python decoder')
