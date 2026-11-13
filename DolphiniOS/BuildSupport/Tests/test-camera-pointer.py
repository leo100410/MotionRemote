from pathlib import Path
import tempfile,subprocess
root=Path(__file__).resolve().parents[2]/'Source/Core'
s=(root/'Core/HW/WiimoteEmu/Dynamics.cpp').read_text();start=s.index('float GetYaw(');end=s.index('\n}',start)+2
h=(root/'Core/HW/WiimoteEmu/Dynamics.h').read_text();a=h.index('struct IMUCursorState');b=h.index('\n};',a)+3
helper=(root/'Core/HW/WiimoteEmu/CameraPointer.h').read_text().replace('#include \"Core/HW/WiimoteEmu/Dynamics.h\"','')
code='#include <cassert>\n#include \"Common/Matrix.h\"\nnamespace WiimoteEmu {'+h[a:b]+s[start:end]+'}\n'+helper+'''
int main(){
using namespace WiimoteEmu;
IMUCursorState state;
auto feed=[&](Common::Quaternion q,unsigned epoch=1,bool valid=true,bool centre=false){ApplyCameraPointer(&state,{q.data.x,q.data.y,q.data.z,q.data.w},epoch,valid,centre,.22f,.01f);};
auto identity=Common::Quaternion::Identity();
feed(identity);assert(!state.camera_centered);
feed(identity,1,true,true);assert(state.camera_centered);
// Match the existing DSU gyro chain, including its signs, for all physical axes.
for(int axis=0;axis<3;++axis) {
 state={};feed(identity,1,true,true);
 Common::Vec3 device{};device.data[axis]=.4f;
 auto physical=Common::Quaternion::RotateXYZ(device);
 for(int i=0;i<150;++i)feed(physical);
 // DSU: pitch=x, roll=y, yaw=-z. Dolphin negates all three in
 // IMUGyroscope::GetRawState, then negates again in EmulateIMUCursor.
 auto expected=Common::Quaternion::RotateXYZ({device.x,device.y,-device.z});
 assert(std::abs(state.tracked_rotation.data.Dot(expected.data))>.99999f);
}
state={};feed(identity,1,true,true);
// A full mixed-axis excursion must converge back to the calibrated orientation.
for(int i=0;i<100;++i)feed(Common::Quaternion::RotateX(.8f)*Common::Quaternion::RotateY(.9f)*Common::Quaternion::RotateZ(.4f));
for(int i=0;i<100;++i)feed(identity);
assert(std::abs(state.tracked_rotation.data.w)>0.9999f);
// Known portrait yaw maps to Wii yaw; retain the physical angle beyond the edge.
for(int i=0;i<100;++i)feed(Common::Quaternion::RotateZ(.8f));
assert(std::abs(GetYaw(state.tracked_rotation))>.7f);
assert(std::abs(GetYaw(state.rotation))<=.221f);
auto before=state.tracked_rotation.data;
feed(identity,1,false);assert(state.tracked_rotation.data.Dot(before)>.999f);
// Equivalent quaternion signs cannot cause a spin.
auto q=Common::Quaternion::RotateZ(.8f);q.data=q.data*-1;
feed(q);assert(std::abs(state.tracked_rotation.data.Dot(before))>.999f);
feed(identity,2);assert(!state.camera_centered);
feed(identity,2,true,true);assert(state.camera_centered);
}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.cpp';p.write_text(code);exe=Path(d)/'test'
 subprocess.run(['clang++','-std=c++20','-I'+str(root),str(p),str(root/'Common/Matrix.cpp'),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True)
print('Camera pointer: mixed-axis return, yaw basis, edge overflow, stale tracking, quaternion signs and session reset passed')
