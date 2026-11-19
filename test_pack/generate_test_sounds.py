import numpy as np, wave, math
SR=44100
def save(name, x):
    x=np.asarray(x,dtype=np.float64)
    x=x/max(1e-9,np.max(np.abs(x)))*0.7
    with wave.open(name,'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x*32767).astype('<i2').tobytes())
def t(sec): return np.arange(int(SR*sec))/SR
def pluck(f,sec=3.0):
    tt=t(sec); y=np.zeros_like(tt)
    for h,a in enumerate([1,.55,.35,.22,.14,.09,.05]):
        if f*(h+1)<SR/2: y+=a*np.sin(2*np.pi*f*(h+1)*tt)*np.exp(-(1.6+1.3*h)*tt)
    env=np.minimum(1,tt/0.004); return y*env
def sustained(f,sec=3.0):
    tt=t(sec); y=np.sin(2*np.pi*f*tt)+.3*np.sin(2*np.pi*2*f*tt)+.12*np.sin(2*np.pi*3*f*tt)
    return y*np.minimum(1,tt/0.02)*np.minimum(1,(sec-tt)/0.05)
def gap(s=0.6): return np.zeros(int(SR*s))
def hz12(semi): return 440*2**(semi/12)
def hz24(k): return 440*2**(k/24)
def hz53(k): return 440*2**(k/53)
def semi(note):
    import re
    m=re.match(r'^([A-G])(#|b)?(-?\d)$',note); b={'C':0,'D':2,'E':4,'F':5,'G':7,'A':9,'B':11}[m.group(1)]
    if m.group(2)=='#': b+=1
    if m.group(2)=='b': b-=1
    return (int(m.group(3))-4)*12+b-9
def seq(freqs,fn=sustained,sec=3.0,g=0.5): 
    out=[]
    for f in freqs: out+= [fn(f,sec),gap(g)]
    return np.concatenate(out)

save('01_A4_440Hz_5s.wav', sustained(440,5))
save('02_A4_cents_-20_-10_0_+10_+20.wav', seq([440*2**(c/1200) for c in (-20,-10,0,10,20)]))
save('03_24TET_A4_to_A5_every_quartertone.wav', seq([hz24(k) for k in range(0,25)],sec=1.6,g=0.3))
save('04_53TET_A4_plus_0_to_9_komas.wav', seq([hz53(k) for k in range(0,10)],sec=1.8,g=0.3))
c4=440*2**(-9/12)
rast=[0,4,7,10,14,18,21,24]
f=[c4*2**(q/24) for q in rast]; f=f+f[-2::-1]
save('05_Rast_on_C_24TET_up_and_down.wav', seq(f,pluck,sec=1.1,g=0.0))
save('06_oud_arabic_C2_F2_A2_D3_G3_C4.wav', seq([hz12(semi(n)) for n in ['C2','F2','A2','D3','G3','C4']],pluck,3.0,0.4))
save('07_oud_turkish_C#2_F#2_B2_E3_A3_D4.wav', seq([hz12(semi(n)) for n in ['C#2','F#2','B2','E3','A3','D4']],pluck,3.0,0.4))
save('08_bass_E1_A1_D2_G2.wav', seq([hz12(semi(n)) for n in ['E1','A1','D2','G2']],pluck,3.0,0.4))
save('09_oud_A2_detuned_-30c_then_0_then_+30c.wav', seq([hz12(semi('A2'))*2**(c/1200) for c in (-30,0,30)],pluck,3.0,0.5))
save('10_glide_100_to_400Hz_10s.wav', np.sin(2*np.pi*np.cumsum(100*4**(t(10)/10))/SR))
rng=np.random.default_rng(1)
noise=rng.standard_normal(SR*5)*0.3
save('11_noise_5s_then_silence_5s_EXPECT_NO_NOTE.wav', np.concatenate([noise/np.max(np.abs(noise))*0.7*0+noise, gap(5)]))
save('12_violin_G3_D4_A4_E5.wav', seq([hz12(semi(n)) for n in ['G3','D4','A4','E5']],pluck,3.0,0.4))
print('ok')
