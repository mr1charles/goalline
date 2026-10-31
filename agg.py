import sys,re
n=0; tot={}
for line in sys.stdin:
    if 'SUMMARY' not in line:
        if 'ERROR' in line or 'SCRIPT' in line: print(line.strip())
        continue
    n+=1
    for k,v in re.findall(r'(\w+)=([\d,]+)',line):
        vals=[int(x) for x in v.split(',')]
        tot[k]=[a+b for a,b in zip(tot.get(k,[0]*len(vals)),vals)]
print("matches",n,{k:[round(x/n,2) for x in v] for k,v in tot.items()})
