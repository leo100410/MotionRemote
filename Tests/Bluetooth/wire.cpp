#include "InputCommon/ControllerInterface/DualShockUDPClient/BluetoothWire.h"
#include <cassert>
#include "InputCommon/ControllerInterface/DualShockUDPClient/LinkQuality.h"
#include <fstream>
#include <sstream>
#include <string>
#include <iostream>
using namespace MRWire;
Bytes unhex(std::string s) {Bytes b;for(size_t i=0;i<s.size();i+=2)b.push_back(std::stoi(s.substr(i,2),nullptr,16));return b;}
std::string hex(const Bytes& b) {static const char* chars="0123456789abcdef";std::string s;for(auto v:b){s+=chars[v>>4];s+=chars[v&15];}return s;}
int main(int argc,char** argv) {
  std::ifstream input(argv[1]);std::ofstream output(argv[2]);std::string line;int count=0;
  while(std::getline(input,line)) {
    auto first=line.find(':'),second=line.find(':',first+1);auto route=std::stoi(line.substr(0,first));auto packet=unhex(line.substr(first+1,second-first-1));
    std::stringstream frames(line.substr(second+1));std::string part;Decoder decoder;std::optional<std::pair<std::uint8_t,Bytes>> result;
    while(std::getline(frames,part,','))result=decoder.Accept(unhex(part),1);
    assert(result && result->first==route && result->second==packet);++count;
    auto outgoing=Frames(packet,route,0,20);output<<route<<":"<<hex(packet)<<":";
    for(size_t i=0;i<outgoing.size();++i)output<<(i?",":"")<<hex(outgoing[i]);output<<"\n";
  }
  assert(count==40);
  Decoder decoder;auto frames=Frames(Bytes(100,4),0,255,20);
  assert(!decoder.Accept(frames[0],0));assert(!decoder.Accept(frames[1],0.3));
  assert(Frames(Bytes(1),16,0,20).empty());assert(Frames(Bytes(1025),0,0,20).empty());assert(Frames(Bytes(1),0,0,4).empty());
  // Fragment loss, reordering and stale partial packets must never produce a corrupted packet.
  Decoder broken;assert(!broken.Accept(frames[0],0));assert(!broken.Accept(frames[2],0));assert(!broken.Accept(frames[1],0));
  auto good=MRLink::Measure(std::vector<double>(40,10),40);
  auto lost=MRLink::Measure(std::vector<double>(20,10),40);
  auto slow=MRLink::Measure(std::vector<double>(40,120),40);
  auto none=MRLink::Measure({},40);
  auto invalid=MRLink::Measure({-1},40);
  assert(good.Useful() && !good.Poor() && good.average==10 && good.loss==0 && good.jitter==0);
  assert(lost.loss==50 && lost.Poor() && good.Score()<lost.Score());
  assert(slow.Poor() && good.Score()<slow.Score());
  assert(!none.Useful() && !invalid.Useful());
  auto jitter=MRLink::Measure({10,20,10,20},4);assert(jitter.jitter==10 && jitter.average==15);
  std::cout<<"PASS: link-quality calculation covers loss, jitter, invalid data and transport ranking\n";
  std::cout<<"PASS: Swift iPhone → C++ host framing, rejection of stale/reordered fragments and invalid bounds\n";
}
