#include "InputCommon/ControllerInterface/DualShockUDPClient/MotionRemoteTrace.h"
#include <cassert>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>
std::string read(const std::string& path) {std::stringstream s;s<<std::ifstream(path).rdbuf();return s.str();}
// A Dolphin restart starts a new session; here the per-process state is reset instead.
void session(int n,const float* accel,const float* gyro)
{
  MRTrace::files[0].out.close();MRTrace::files[0]=MRTrace::File{};
  MRTrace::Event(0,1.0,"rumble on");                                  // no phone data yet: ignored
  MRTrace::State(0,1.0,accel,gyro,0x0800,n,123456,0.995);
  MRTrace::Event(0,1.0105,"mark",std::to_string(n));
}
int main(int,char** argv)
{
  const std::string dir=std::string(argv[1])+"/";
  MRTrace::directory=dir;
  const float accel[3]={0.5f,-1.25f,1},gyro[3]={10,-20,300};
  MRTrace::Event(1,1.0,"rumble on");
  assert(!std::filesystem::exists(dir+"MotionRemote-trace-P2.csv"));  // an idle player leaves no file
  std::ofstream(dir+"MotionRemote-trace-P1-previous.csv")<<"old naming";
  for(int n=1;n<=12;++n)session(n,accel,gyro);
  MRTrace::files[0].out.close();
  const std::string current=read(dir+"MotionRemote-trace-P1.csv");
  assert(current.find("0.0,state,0.500,-1.250,1.000,10,-20,300,0800,12,123.5,5.0,\n")!=std::string::npos);
  assert(current.find("10.5,mark,,,,,,,,,,,12\n")!=std::string::npos && current.find("rumble on")==std::string::npos);
  assert(read(dir+"MotionRemote-trace-P1-1.csv").find("mark,,,,,,,,,,,11")!=std::string::npos);
  assert(read(dir+"MotionRemote-trace-P1-9.csv").find("mark,,,,,,,,,,,3")!=std::string::npos);
  int files=0;for(auto& e:std::filesystem::directory_iterator(dir))files+=e.path().filename().string().starts_with("MotionRemote-trace-P1");
  assert(files==MRTrace::Sessions);                                   // sessions 1-2 and the old naming are gone
  std::cout<<"trace ok\n";
}
