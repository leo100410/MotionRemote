#!/usr/bin/env python3
"""Stands in for the iPhone on UDP 26760 so the Mac monitor can be checked without hardware.
Streams a slowly turning phone and drops a few packets on purpose. Usage: fake-phone.py [seconds]"""
import math,socket,struct,sys,time,zlib
def packet(kind,size):
    b=bytearray(size);b[0:4]=b'DSUS';struct.pack_into('<HH',b,4,1001,size-16);struct.pack_into('<II',b,12,0x1234abcd,kind);return b
def finish(b):
    struct.pack_into('<I',b,8,0);struct.pack_into('<I',b,8,zlib.crc32(bytes(b)));return bytes(b)
s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);s.bind(('127.0.0.1',26760));s.setblocking(False)
clients={};start=time.time();counter=0;end=start+float(sys.argv[1]) if len(sys.argv)>1 else float('inf')
while time.time()<end:
    try:
        while True:
            data,peer=s.recvfrom(1024)
            if data[:4]==b'DSUC' and struct.unpack_from('<I',data,16)[0]==0x100002:clients[peer]=time.time()
    except BlockingIOError:pass
    t=time.time()-start;counter+=1
    yaw=t*0.8;pitch=0.5*math.sin(t*2)
    state=packet(0x100002,100);state[20]=0;state[21]=2;state[22]=2;state[23]=2;state[31]=1
    struct.pack_into('<I',state,32,counter)
    if int(t)%4==0:state[49]=255
    struct.pack_into('<Q',state,68,int(t*1e6))
    struct.pack_into('<6f',state,76,0.2*math.sin(t*3),-math.cos(pitch),math.sin(pitch),math.degrees(math.cos(t*2)),-math.degrees(0.8),0)
    cy,sy,cp,sp=math.cos(yaw/2),math.sin(yaw/2),math.cos(pitch/2),math.sin(pitch/2)
    attitude=packet(0x100006,48);attitude[20]=0;struct.pack_into('<Q',attitude,24,int(t*1e6))
    struct.pack_into('<4f',attitude,32,cy*sp,sy*sp,sy*cp,cy*cp)  # yaw about Z, then pitch about X
    lost=counter%300 in (0,1,2)  # three packets in a row every three seconds
    for peer,seen in list(clients.items()):
        if time.time()-seen>5:del clients[peer];continue
        if not lost:s.sendto(finish(state),peer)
        if counter%2==0:s.sendto(finish(attitude),peer)
    time.sleep(0.01)
