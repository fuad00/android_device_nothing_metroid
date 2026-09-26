import struct,sys
# split concatenated FDT blobs and print model / compatible / msm-id / board-id of each
def fdts(d):
    i=0
    while True:
        i=d.find(b'\xd0\x0d\xfe\xed',i)
        if i<0: return
        size=struct.unpack('>I',d[i+4:i+8])[0]
        if 0<size<len(d): yield i,d[i:i+size]
        i+=4
def props(b):
    off_struct,off_str=struct.unpack('>II',b[8:16])
    p=off_struct; depth=0; out={}
    while p<len(b):
        tok=struct.unpack('>I',b[p:p+4])[0]; p+=4
        if tok==1:
            e=b.index(b'\0',p); p=(e+4)&~3; depth+=1
        elif tok==2: depth-=1
        elif tok==3:
            ln,no=struct.unpack('>II',b[p:p+8]); p+=8
            name=b[off_str+no:b.index(b'\0',off_str+no)].decode()
            val=b[p:p+ln]; p=(p+ln+3)&~3
            if depth==1 and name in('model','compatible','qcom,msm-id','qcom,board-id','nt,project-id'): out[name]=val
        elif tok==9: break
    return out
for f in sys.argv[1:]:
    d=open(f,'rb').read(); n=0
    for i,b in fdts(d):
        pr=props(b); n+=1
        def s(k):
            v=pr.get(k,b'')
            return v.replace(b'\0',b' ').decode(errors='replace').strip() if k in('model','compatible') else ' '.join(hex(x) for x in struct.unpack('>%dI'%(len(v)//4),v))
        print(f"{f.split('/')[-1]}#{n}: model='{s('model')}' compat='{s('compatible')[:60]}' msm-id={s('qcom,msm-id')} board-id={s('qcom,board-id')}")
