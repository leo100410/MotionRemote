#include <cassert>
#include <cstdlib>
#include "Common/MsgHandler.h"
namespace Common { bool MsgAlertFmtImpl(bool,MsgType,Common::Log::LogType,const char* file,int line,fmt::string_view,const fmt::format_args&) { std::fprintf(stderr,"ImGui assertion at %s:%d\n",file,line); std::abort(); } }
#include <fstream>
#include <limits>
#include <vector>
#include "InputCommon/ControllerInterface/DualShockUDPClient/MotionRemoteState.h"
#include "VideoCommon/MotionRemoteOverlay.h"
using u8=uint8_t;using u16=uint16_t;using u32=uint32_t;using u64=uint64_t;
namespace Proto { constexpr std::array<u8,4> SERVER{'D','S','U','S'};
#pragma pack(push,1)
struct MessageHeader {std::array<u8,4>source;u16 protocol_version;u16 message_length;u32 crc;u32 source_uid;};
#pragma pack(pop)
}
#include "/tmp/motionremote-pose-struct.h"
int main()
{
  namespace MR=ciface::DualShockUDPClient::MotionRemote;
  MotionRemotePose p{};
  std::ifstream file("/tmp/motionremote-spatial.bin",std::ios::binary);file.read(reinterpret_cast<char*>(&p),sizeof(p));
  assert(file.gcount()==68 && p.header.message_length==52 && p.message_type==0x100004);
  assert(p.pad_id==2 && p.position[0]==0.25f && p.position[1]==-0.5f && p.position[2]==1);
  assert(p.orientation[3]==1 && p.timestamp_us==123500000 && p.sequence==4);
  MR::Reset(2);
  auto publish=[&]{return MR::Pose(p.pad_id,p.tracking,p.epoch,p.sequence,p.timestamp_us,p.position,p.orientation);};
  assert(publish());
  assert(!publish()); // Same timestamp/sequence is not drawn twice.
  p.timestamp_us+=100;p.sequence++;p.tracking=1;assert(publish());
  auto state=MR::Read()[2];assert(state.trail.size()==1 && state.tracking==1);
  p.timestamp_us+=100;p.sequence++;p.tracking=2;p.position[0]=0.5f;assert(publish());
  state=MR::Read()[2];assert(state.trail.size()==2 && state.trail[0].segment!=state.trail[1].segment);
  p.timestamp_us+=100;p.sequence++;p.position[0]=std::numeric_limits<float>::infinity();assert(!publish());
  p.position[0]=0.7f;p.epoch++;assert(publish());assert(MR::Read()[2].trail.size()==1);
  p.timestamp_us--;assert(!publish());
  assert(MR::Read()[0].trail.empty() && MR::Read()[1].trail.empty());
  auto rotated=MotionRemoteOverlay::Rotate({1,0,0},{0,0,0.70710678f,0.70710678f});
  assert(std::abs(rotated[0])<0.0001 && std::abs(rotated[1]-1)<0.0001);
  assert(MR::HistorySeconds==3);
  MR::Rumble(2,0.5f);
  {std::lock_guard lock(MR::mutex);MR::states[2].trail.front().time=MR::Now()-4;MR::states[2].rumble_history.front().time=MR::Now()-4;}
  p.timestamp_us+=2;p.sequence++;assert(publish());MR::Rumble(2,0.7f);
  assert(MR::Read()[2].trail.size()==1 && MR::Read()[2].rumble_history.size()==1);
  MR::Input(2);MR::enabled=true;MR::selected=2;
  ImGui::CreateContext();auto& io=ImGui::GetIO();io.DisplaySize={1280,720};io.DeltaTime=1.0f/60;
  unsigned char* pixels;int width,height;io.Fonts->GetTexDataAsRGBA32(&pixels,&width,&height);
  ImGui::NewFrame();MotionRemoteOverlay::Draw();ImGui::Render();
  ImGui::NewFrame();MotionRemoteOverlay::Draw();ImGui::Render();
  assert(ImGui::GetDrawData()->TotalVtxCount>0);
  ImGui::DestroyContext();
  puts("Spatial tests passed: actual Swift-to-C++ pose layout, isolated player state, stale/invalid rejection, tracking-gap segments, new-origin reset, 3D rotation three-second history expiration and actual ImGui draw generation");
}
