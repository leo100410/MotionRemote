#!/usr/bin/env python3
"""Plays an iPhone for MotionSaber on UDP 26760: a calibrated screen pose swinging down and up on the beat.
Every 8 s the camera reports 'insufficient features' for 1.5 s, so the game must fall back to motion only.
Usage: fake-sword.py [seconds]"""
import math,socket,struct,sys,time,zlib
BPM=96.0
def packet(kind,size):
    b=bytearray(size);b[0:4]=b'DSUS';struct.pack_into('<HH',b,4,1001,size-16);struct.pack_into('<II',b,12,0x5a5a1234,kind);return b
def finish(b):
    struct.pack_into('<I',b,8,0);struct.pack_into('<I',b,8,zlib.crc32(bytes(b)));return bytes(b)
def qmul(a,b):
    ax,ay,az,aw=a;bx,by,bz,bw=b
    return (aw*bx+ax*bw+ay*bz-az*by,aw*by-ax*bz+ay*bw+az*bx,aw*bz+ax*by-ay*bx+az*bw,aw*bw-ax*bx-ay*by-az*bz)
def axis(angle,x,y,z): s=math.sin(angle/2);return (x*s,y*s,z*s,math.cos(angle/2))
def rotate(q,v):
    x,y,z,w=q;p=qmul(qmul(q,(v[0],v[1],v[2],0)),(-x,-y,-z,w));return p[:3]
s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);s.bind(('127.0.0.1',26760));s.setblocking(False)
clients={};start=time.time();counter=0;end=start+(float(sys.argv[1]) if len(sys.argv)>1 else 1e9)
while time.time()<end:
    try:
        while True:
            data,peer=s.recvfrom(1024)
            if data[:4]==b'DSUC' and struct.unpack_from('<I',data,16)[0]==0x100002:clients[peer]=time.time()
    except BlockingIOError:pass
    t=time.time()-start;counter+=1
    beat=t*BPM/60
    # Blade up at even beats, down at odd beats, so every block gets a fast vertical cut.
    swing=math.cos(math.pi*beat)
    q=qmul(axis(0.25*math.sin(t*0.7),0,1,0),axis(-math.pi/2+0.55*swing,1,0,0))
    # The hand wanders across all four columns so some swings meet blocks.
    position=(0.3*math.sin(t*2.3),0.08*swing,0.4)
    lost=(t%8)>6.5
    screen=packet(0x100007,68);screen[20]=0;screen[21]=1 if lost else 2;screen[22]=3 if lost else 0;screen[23]=1|4
    struct.pack_into('<IQf',screen,24,counter,int(t*1e6),0.304)
    struct.pack_into('<3f4f',screen,40,*(position if not lost else (0,0,0)),*q)
    attitude_q=qmul(axis(math.pi/2,1,0,0),q)  # Core Motion reference: z up
    gravity=rotate((-attitude_q[0],-attitude_q[1],-attitude_q[2],attitude_q[3]),(0,0,-1))
    state=packet(0x100002,100);state[20]=0;state[21]=2;state[22]=2;state[23]=2;state[31]=1
    struct.pack_into('<I',state,32,counter);struct.pack_into('<Q',state,68,int(t*1e6))
    struct.pack_into('<6f',state,76,-gravity[0],gravity[2],-gravity[1],0,0,0)
    attitude=packet(0x100006,48);attitude[20]=0;struct.pack_into('<Q4f',attitude,24,int(t*1e6),*attitude_q)
    for peer,seen in list(clients.items()):
        if time.time()-seen>5:del clients[peer];continue
        for b in (state,attitude,screen):s.sendto(finish(b),peer)
    time.sleep(0.01)
