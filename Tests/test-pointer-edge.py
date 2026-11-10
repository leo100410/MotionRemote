from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]/'DolphinBuild/dolphin-2609b/Source/Core'
s=(root/'Core/HW/WiimoteEmu/Dynamics.cpp').read_text()
def function(marker):
 start=s.index(marker);brace=s.index('{',start);level=1;end=brace+1
 while level:
  if s[end]=='{':level+=1
  if s[end]=='}':level-=1
  end+=1
 return s[start:end]
h=(root/'Core/HW/WiimoteEmu/Dynamics.h').read_text();a=h.index('struct IMUCursorState');b=h.index('\n};',a)+3
state=h[a:b]
source='''#include <cassert>
#include <optional>
#include <cstdio>
#include <vector>
#include "Common/Matrix.h"
namespace ControllerEmu {
struct Flag {bool value=true; bool GetValue()const{return value;}};
struct Control {bool down=false;template<class T>T GetState()const{return T(down);}};
struct IMUCursor {Flag enabled;bool preserve=true;Control control;std::vector<Control*>controls{&control};
 bool GetPreserveAngle()const{return preserve;} double GetTotalYaw()const{return 25.0*3.141592653589793/180;}
 double GetAccelWeight()const{return 0;}};
struct IMUGyroscope {std::optional<Common::Vec3>value=Common::Vec3{};auto GetState()const{return value;}};
struct IMUAccelerometer {std::optional<Common::Vec3>value=Common::Vec3{};auto GetState()const{return value;}};
}
namespace WiimoteEmu {
'''+state+'\n'
for marker in ['Common::Quaternion ComplementaryFilter(', 'Common::Quaternion GetRotationFromGyroscope(', 'float GetPitch(', 'float GetYaw(', 'void EmulateIMUCursor(']:
 code=function(marker)
 if marker.startswith('Common::Quaternion ComplementaryFilter('):code=code.replace('const Common::Vec3& accelerometer_normal)','const Common::Vec3& accelerometer_normal = {0,0,1})')
 source+=code+'\n'
source+='''}
int main(){
 using namespace WiimoteEmu;ControllerEmu::IMUCursor cursor;ControllerEmu::IMUGyroscope gyro;ControllerEmu::IMUAccelerometer accel;IMUCursorState state;
 constexpr float rad=3.141592653589793f/180;
 auto step=[&](float degrees){gyro.value=Common::Vec3(0,0,-degrees*rad/0.01f);EmulateIMUCursor(&state,&cursor,&accel,&gyro,0.01f);};
 auto turn=[&](float degrees){for(int i=0;i<100;++i)step(degrees/100);};
 auto yaw=[&]{return GetYaw(state.rotation)/rad;};
 auto tracked=[&]{return GetYaw(state.tracked_rotation)/rad;};
 turn(30);assert(std::abs(yaw()-12.5)<0.01 && std::abs(tracked()-30)<0.01);
 turn(-10);assert(std::abs(yaw()-12.5)<0.01 && std::abs(tracked()-20)<0.01);
 turn(-10);assert(std::abs(yaw()-10)<0.01);
 turn(-40);assert(std::abs(yaw()+12.5)<0.01 && std::abs(tracked()+30)<0.01);
 turn(10);assert(std::abs(yaw()+12.5)<0.01);turn(10);assert(std::abs(yaw()+10)<0.01);
 cursor.control.down=true;step(0);cursor.control.down=false;
 assert(std::abs(yaw())<0.01 && std::abs(tracked())<0.01);turn(5);assert(std::abs(yaw()-5)<0.01);
 cursor.enabled.value=false;step(0);assert(std::abs(yaw())<0.01 && std::abs(tracked())<0.01);
 cursor.enabled.value=true;gyro.value=std::nullopt;EmulateIMUCursor(&state,&cursor,&accel,&gyro,0.01f);assert(std::abs(yaw())<0.01);
 cursor.preserve=false;turn(30);turn(-10);assert(std::abs(yaw()-2.5)<0.01);
 cursor.preserve=true;step(0);assert(std::abs(yaw()-2.5)<0.01);
 puts("Actual cursor function passed: right/left overshoot retained, return threshold, recenter, disable/no-gyro reset and legacy mode");
}
'''
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp)/'test.cpp';exe=Path(tmp)/'test';p.write_text(source)
 subprocess.run(['/usr/bin/clang++','-std=c++20','-I'+str(root),str(p),str(root/'Common/Matrix.cpp'),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True)
