#include "InputCommon/ControllerInterface/DualShockUDPClient/MotionRemoteLog.h"
#include "InputCommon/ControllerInterface/DualShockUDPClient/MotionRemoteState.h"
#include <cassert>
#include <fstream>
#include <iostream>
#include <sstream>
#include <cstdio>
int main(int argc,char** argv)
{
  const std::string path=std::string(argv[1])+"/MotionRemote.log";
  MRLog::Open(path);
  MRLog::Link link;link.player=2;
  // Wi-Fi burst every second: sent 10 ms apart, arrived 150 ms apart; then a real phone pause and a drop.
  double now=100;std::uint32_t counter=0;std::uint64_t stamp=0;
  auto packet=[&](double at,std::uint32_t number,std::uint64_t sent){now=at;counter=number;stamp=sent;link.Packet(now,counter,stamp);};
  for(int second=0;second<5;++second) {packet(100+second,second*100,second*1'000'000);packet(100.15+second,second*100+1,second*1'000'000+10'000);}
  packet(105.3,600,5'300'000);packet(105.5,601,5'500'000);  // phone paused 200 ms
  packet(105.7,700,5'700'000);                              // 98 lost although the phone kept sending
  link.Tick(105.75);link.Tick(106.2);                       // 500 ms silence
  packet(106.3,701,6'300'000);
  link.Tick(110.5);
  MRLog::Write(111,"TEST","a",std::string("k"));MRLog::Write(111.5,"TEST","a","k");MRLog::Write(112.2,"TEST","a","k");
  // Screen pose state: normalised, invalid input rejected, reasons readable.
  namespace MR=ciface::DualShockUDPClient::MotionRemote;
  assert(MR::Screen(1,2,0,true,{0,0,0,2}) && MR::Read()[1].screen_orientation[3]==1 && MR::Read()[1].screen_calibrated);
  assert(!MR::Screen(1,2,0,true,{0,0,0,0}) && !MR::Screen(4,2,0,true,{0,0,0,1}) && !MR::Screen(1,3,0,true,{0,0,0,1}));
  assert(MR::Screen(1,1,3,false,{0,0,0,0}) && MR::Read()[1].screen_reason==3);
  assert(std::string(MR::ReasonText(3)).find("too little detail")!=std::string::npos && std::string(MR::ReasonText(99))=="Unknown tracking state");
  assert(MR::SetPointerSource(1,2)==-1 && MR::SetPointerSource(1,0)==2);
  std::stringstream text;text<<std::ifstream(path).rdbuf();const std::string log=text.str();
  for(const char* expected:{"Player 2: packet gap 150 ms, 0 lost: phone sent them 10 ms apart, so Wi-Fi held them back",
                            "Player 2: packet gap 200 ms, 0 lost: the phone itself paused sending for 200 ms",
                            "Player 2: packet gap 200 ms, 98 lost: the phone kept sending, the packets were lost on the way",
                            "Player 2: no controller data for 400 ms","Player 2: controller data resumed after 600 ms",
                            "held by Wi-Fi","regular, every 1.00 s","[TEST] a\n","[TEST] a (+1 similar since the last line)"})
    if(log.find(expected)==std::string::npos) {std::cerr<<"missing: "<<expected<<"\n"<<log;return 1;}
  std::cout<<"dolphin link diagnostics ok\n";
}
