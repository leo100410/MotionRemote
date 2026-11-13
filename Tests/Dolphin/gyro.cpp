#include "InputCommon/ControllerInterface/DualShockUDPClient/GyroAccumulator.h"
#include <cassert>
#include <cmath>
#include <iostream>
using MRGyro::Accumulator;
static double total(Accumulator& a,int polls) {double sum=0;for(int i=0;i<polls;++i)sum+=a.Discharge()[0]/Accumulator::PollRate;return sum;}
int main() {
  // A burst of delayed packets keeps the whole rotation: 20 samples of 90 deg/s over 10 ms each.
  Accumulator burst;
  for(std::uint32_t i=0;i<=20;++i)assert(burst.Accept(100+i,1'000'000+i*10'000,{90,0,0},5.0));
  assert(std::abs(total(burst,50)-18.0)<1e-6);
  assert(burst.Discharge()[0]==0);  // a gap reports no rotation instead of the stale rate

  // The second transport delivers the same packets again, and UDP may reorder them.
  Accumulator twice;
  assert(twice.Accept(1,1'000'000,{50,0,0},1.0));
  assert(twice.Accept(2,1'010'000,{50,0,0},1.01));
  assert(!twice.Accept(2,1'010'000,{50,0,0},1.012));
  assert(!twice.Accept(1,1'000'000,{50,0,0},1.013));
  assert(std::abs(total(twice,10)-0.5)<1e-6);

  // A lost packet is bridged with the newer rate; a long silence is capped, not extrapolated.
  Accumulator lost;
  lost.Accept(1,1'000'000,{100,0,0},1.0);lost.Accept(3,1'020'000,{100,0,0},1.02);
  assert(std::abs(total(lost,10)-2.0)<1e-6);
  lost.Accept(4,1'520'000,{100,0,0},1.52);
  assert(std::abs(total(lost,50)-10.0)<1e-6);

  // Large debts are spread over several polls and bounded overall.
  Accumulator fast;
  fast.Accept(1,1'000'000,{0,400,0},1.0);fast.Accept(2,1'100'000,{0,400,0},1.1);
  assert(std::abs(fast.Discharge()[1]-Accumulator::MaxStep*Accumulator::PollRate)<1e-3);
  for(std::uint32_t i=3;i<100;++i)fast.Accept(i,1'000'000+i*100'000ull,{0,4000,0},1.0+i*0.1);
  double sum=0;for(int i=0;i<100;++i)sum+=fast.Discharge()[1]/Accumulator::PollRate;
  assert(sum<=Accumulator::MaxDebt+1e-6);

  // The phone app restarts its counter at zero; the first packet after a silence is accepted.
  Accumulator restart;
  restart.Accept(50'000,9'000'000,{10,0,0},1.0);
  assert(!restart.Accept(5,9'010'000,{10,0,0},1.5));
  assert(restart.Accept(5,100'000,{10,0,0},2.6));
  assert(restart.Accept(6,110'000,{10,0,0},2.61));
  assert(std::abs(total(restart,10)-0.1)<1e-6);

  // Invalid rates never poison the debt; Clear drops it, Raw keeps the last sample.
  Accumulator bad;
  bad.Accept(1,1'000'000,{NAN,1,2},1.0);bad.Accept(2,1'010'000,{INFINITY,1,2},1.01);
  assert(bad.Raw()[0]==0 && bad.Raw()[2]==2);
  bad.Clear();auto none=bad.Discharge();assert(none[0]==0 && none[1]==0 && none[2]==0);
  std::cout<<"gyro accumulator ok\n";
}
