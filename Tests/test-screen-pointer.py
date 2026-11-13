from pathlib import Path
import tempfile,subprocess
root=Path(__file__).resolve().parents[1]/'DolphinBuild/dolphin-2609b/Source/Core'
s=(root/'Core/HW/WiimoteEmu/Dynamics.cpp').read_text();start=s.index('float GetYaw(');end=s.index('\n}',start)+2
h=(root/'Core/HW/WiimoteEmu/Dynamics.h').read_text();a=h.index('struct IMUCursorState');b=h.index('\n};',a)+3
helper=(root/'Core/HW/WiimoteEmu/CameraPointer.h').read_text().replace('#include \"Core/HW/WiimoteEmu/Dynamics.h\"','')
code='#include <cassert>\n#include \"Common/Matrix.h\"\nnamespace WiimoteEmu {'+h[a:b]+s[start:end]+'}\n'+helper+'''
int main(){
using namespace WiimoteEmu;
// The screen frame is the room frame turned so the screen faces +z; take any turn and any phone motion.
const auto room=Common::Quaternion::RotateY(1.1f);
const auto forward=Common::Quaternion::RotateX(-1.5707963f); // top edge at the screen, display up
const Common::Quaternion constant(0.70710678f,-0.70710678f,0,0);  // the value WiimoteEmu uses
assert(std::abs(constant.data.Dot(forward.data))>.99999f);
auto feed=[](IMUCursorState& state,Common::Quaternion q,unsigned epoch,bool centre){ApplyCameraPointer(&state,{q.data.x,q.data.y,q.data.z,q.data.w},epoch,true,centre,.6f,.01f);};
for(auto motion:{Common::Quaternion::RotateZ(.3f),Common::Quaternion::RotateX(.4f)*Common::Quaternion::RotateY(-.2f),Common::Quaternion::RotateZ(-.5f)*Common::Quaternion::RotateX(-.3f)}) {
 // Old mode: the player points at the screen centre, presses recenter, then moves.
 IMUCursorState relative;
 feed(relative,room*forward,7,true);
 for(int i=0;i<200;++i)feed(relative,room*forward*motion,7,false);
 // New mode: the same physical pose arrives in screen coordinates; the reference is fixed.
 IMUCursorState screen;
 for(int i=0;i<200;++i) {
  screen.camera_reference=constant;screen.camera_centered=true;screen.camera_epoch=0xFFFFFFFFu;
  feed(screen,forward*motion,0xFFFFFFFFu,false);
 }
 assert(screen.camera_valid);
 assert(std::abs(screen.tracked_rotation.data.Dot(relative.tracked_rotation.data))>.9999f);
}
// Leaving screen mode drops back to the relative camera mode, which then needs its own recenter.
IMUCursorState state;state.camera_reference=constant;state.camera_centered=true;state.camera_epoch=0xFFFFFFFFu;
feed(state,forward,0xFFFFFFFFu,false);assert(state.camera_valid);
feed(state,forward,7,false);assert(!state.camera_valid && !state.camera_centered);
}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.cpp';p.write_text(code);exe=Path(d)/'test'
 subprocess.run(['clang++','-std=c++20','-I'+str(root),str(p),str(root/'Common/Matrix.cpp'),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True)
print('Screen pointer: same Wii pointer as a perfect recenter for every room orientation; leaving screen mode needs a new recenter')
