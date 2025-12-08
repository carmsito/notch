#!/bin/bash
LC_ALL=C
read cpu u1 n1 s1 i1 w1 x1 y1 z1 a1 b1 < /proc/stat
sleep 0.1
read cpu u2 n2 s2 i2 w2 x2 y2 z2 a2 b2 < /proc/stat
idle1=$((i1+w1))
idle2=$((i2+w2))
non1=$((u1+n1+s1+x1+y1+z1))
non2=$((u2+n2+s2+x2+y2+z2))
total1=$((idle1+non1))
total2=$((idle2+non2))
dt=$((total2-total1))
di=$((idle2-idle1))
if [ $dt -gt 0 ]; then
    echo $(( (dt-di)*100/dt ))
else
    echo 0
fi
