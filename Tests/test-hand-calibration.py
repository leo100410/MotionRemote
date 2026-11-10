from pathlib import Path
import subprocess,tempfile
source=(Path(__file__).resolve().parents[1]/'Sources/Controller.swift').read_text()
a=source.index('                let mean = (0..<3).map');b=source.index('                DispatchQueue.main.async',a)
logic=source[a:b]
code='import Foundation\nfunc measure(_ calibration:[[Double]]) -> (Bool,[Double]) { var bias=[0.0,0.0,0.0]\n'+logic+'\nreturn (quiet,bias)\n}\n'+'''
let table = Array(repeating:[0.002,0.003,-0.001],count:100)
assert(measure(table).0 && zip(measure(table).1,table[0]).allSatisfy { abs($0-$1)<1e-9 })
let hand = (0..<100).map { i in [0.04*sin(Double(i)),0.035*cos(Double(i)),0.02*sin(Double(i)*2)] }
assert(measure(hand).0)
assert(measure(hand).1 == [0,0,0])
let swinging = (0..<100).map { i in [sin(Double(i)),cos(Double(i)),0.0] }
assert(!measure(swinging).0)
assert(!measure(Array(repeating:[0.4,0.0,0.0],count:100)).0)
print("Actual calibration logic: table, hand tremor, bias protection, swings and steady rotation passed")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'calibration.swift';p.write_text(code)
 subprocess.run(['xcrun','swift',str(p)],check=True)
