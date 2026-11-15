// Adapted from PixelFX small-explosion / claw-swipe / vine-whip recipes.
// Copyright 2026 Patch and Hugo Duprez, MIT: third_party/pixelfx/LICENSE.

// Hit Spark's shining cross/diamond only; no particle spray, chips or debris.
export function basicHitFlash(core) {
  const { fit, WHITE } = core;
  const C = fit(['#4a1712','#c9281f','#f2561d','#ff8a2a','#ffe26b','#fff3a6','#ffffff'],7);
  const ray = (p,angle,length,width,start=0) => {
    const ca=Math.cos(angle),sa=Math.sin(angle);
    for(let d=start*length;d<=length;d+=0.5) {
      const u=d/length,half=width*Math.pow(1-u,1.6);
      p.px(ca*d,sa*d,u<0.3?WHITE:u<0.62?C[5]:C[4]);
      for(let edge=0.5;edge<=half;edge+=0.5) for(const side of [-edge,edge])
        p.px(ca*d-sa*side,sa*d+ca*side,u<0.3?C[5]:C[4]);
    }
  };
  return (p,time) => {
    const rays=Array.from({length:8},(_,i)=>[0.1+i*Math.PI/4,14,2.2]);
    if(time<0.058) {
      for(const [a,length,width] of rays) ray(p,a,length*(time<0.025?1:1.2),width*(time<0.025?1:0.55),time<0.025?0:0.12);
      const radius=time<0.025?4:3;
      for(let y=-radius-1;y<=radius+1;y++) for(let x=-radius-1;x<=radius+1;x++) {
        const d=Math.abs(x)+Math.abs(y);
        if(d<=radius+1) p.px(x,y,d<=radius?WHITE:C[3]);
      }
    } else if(time<0.092) for(const [a,length] of rays) ray(p,a,length*1.3,0.6,0.4);
    const glow=Math.exp(-time/0.045);
    if(glow>0.02) { p.glow(0,0,22,C[4],0.3*glow);p.glow(0,0,7,WHITE,0.15*glow); }
  };
}

export function scratchHit(core) {
  const { WHITE, smooth } = core;
  return (p,time) => {
    const reach=smooth(0,0.045,time),fade=1-smooth(0.14,0.25,time);
    // All three parallel white diagonal strokes have identical timing.
    for(const start of [-15,-7,1]) {
      p.shade(-31,-30,31,30,(x,y,out) => {
      const dx=21,dy=48,length=Math.hypot(dx,dy),ux=dx/length,uy=dy/length;
      const along=((x-start+3.5)*ux+(y+24)*uy)/length;
      if(along<0 || along>reach) return;
      const cross=(x-start+3.5)*(-uy)+(y+24)*ux;
      if(Math.abs(cross)>0.5+1.2*Math.sin(Math.PI*along)) return;
      out.c=WHITE;out.a=fade;
      });
      // Small white chips peel away from each stroke together.
      for(let i=0;i<4;i++) {
        const age=time-0.025-i*0.006;
        if(age<0 || age>0.17) continue;
        const t=(i+0.5)/4, side=i%2?1:-1, spread=age*34;
        const x=start-3.5+21*t+side*spread, y=-24+48*t-age*18;
        p.line(x,y,x+side*(1.2+age*3),y-1,WHITE,1-age/0.17);
      }
    }
  };
}

export function emberBurst(core, o) {
  const { fit, Particles, Lights, Rng, P, TAU, WHITE, rgb } = core;
  const F = fit(o.palette, 8), R = new Rng(o.seed), radius = 18;
  const ps = new Particles({ rng: R, ground: () => 100, sparks: [F[6], F[5], F[3], F[2]] });
  const lights = new Lights();
  let time = 0;
  // Keep the original blast radius, but substantially reduce particle counts,
  // smoke size/lifetime and secondary debris. No ground crater or rock spray.
  for (let i = 0; i < 3; i++) ps.spawn(P.FIRE, R.range(-2,2), 0, R.range(-20,20), R.range(-35,-10), R.range(0.16,0.28), 0, R.range(radius*0.35,radius*0.5));
  for (let i = 0; i < 8; i++) {
    const a = R.range(0,TAU), speed = R.range(40,130);
    ps.spawn(P.FIRE, Math.cos(a)*4, Math.sin(a)*4, Math.cos(a)*speed, Math.sin(a)*speed-20,
      R.range(0.25,0.45), 0, R.range(radius*0.18,radius*0.3));
  }
  for (let i = 0; i < 2; i++) ps.spawn(P.SMOKE, R.range(-6,6), -3, R.range(-12,12), R.range(-22,-10), R.range(0.3,0.5), rgb(44,36,46), R.range(2.5,4));
  for (let i = 0; i < 12; i++) {
    const a = R.range(0,TAU), speed = R.range(70,180);
    ps.spawn(P.SPARK, 0, 0, Math.cos(a)*speed, Math.sin(a)*speed-20, R.range(0.12,0.3));
  }
  for (let i = 0; i < 5; i++) ps.spawn(P.EMBER, R.range(-5,5), 0, R.range(-35,35), R.range(-60,-15), R.range(0.3,0.6), F[3]);
  lights.add(0,0,radius*2.5,rgb(255,176,96),0.3,0.3);
  return {
    update(dt) { time += dt; ps.update(dt); lights.update(dt); },
    drawBack(p) { ps.draw(p,'back'); },
    draw(p) {
      ps.draw(p,'front');
      if (time < 0.06) {
        const r = radius * (0.8 + 0.2 * (1-time/0.06));
        p.circle(0,0,r+1.2,F[2]); p.circle(0,0,r,F[5]); p.circle(0,0,r*0.55,F[6]);
      }
      if (time < 0.3) {
        const life = 1-time/0.3;
        p.ring(0,0,radius*(0.45+2*(1-life**3)),Math.max(0.8,2*life),F[5],life);
      }
      lights.draw(p);
    },
  };
}

export function leafImpact(core, drawLeaf, vinePalette) {
  const { fit, smooth, TAU, WHITE, sparkle } = core;
  const C = fit(vinePalette,8);
  // Screen-space endpoints follow the supplied reference and numbered order.
  const marks = [[-26,-12,27,-5,0.0],[-16,-22,11,22,0.055],[-28,17,23,-4,0.105]];
  return (p,time) => {
    marks.forEach(([ax,ay,bx,by,start]) => {
      const age = time-start;
      if (age < 0) return;
      const reach = smooth(0,0.065,age), fade = 1-smooth(0.13,0.25-start,age);
      const dx=bx-ax, dy=by-ay, length=Math.hypot(dx,dy), ux=dx/length, uy=dy/length;
      p.shade(-31,-24,31,24,(x,y,out) => {
        const along=((x-ax)*ux+(y-ay)*uy)/length;
        if (along<0 || along>reach) return;
        const distance=(x-ax)*(-uy)+(y-ay)*ux;
        const width=0.45+1.5*Math.sin(Math.PI*along);
        if (Math.abs(distance)>width) return;
        out.c = Math.abs(distance)<width*0.32 ? C[7] : distance<0 ? C[5] : C[3];
        out.a = fade;
      });
      // Vine Whip's impact-only seven-ray crack, ring and glint. No vine.
      const e=age-0.065;
      if (e>=0 && e<0.09) {
        const k=1-e/0.09, radius=2+4*(1-k), x=ax+dx*0.65, y=ay+dy*0.65;
        for (let j=0;j<7;j++) {
          const a=j/7*TAU+0.3;
          p.line(x+Math.cos(a)*radius,y+Math.sin(a)*radius,x+Math.cos(a)*(radius+3*k),y+Math.sin(a)*(radius+3*k),k>0.5?WHITE:C[6],k);
        }
        p.ring(x,y,2+5*(1-k),0.7,C[7],k);
        sparkle(p,x,y,3*k,C[7],C[5],0.25);
      }
    });
    const age=time-0.09;
    if (age>0 && age<0.15) for (let i=0;i<5;i++) {
      const a=i*TAU/5, distance=age*65;
      drawLeaf(p,Math.cos(a)*distance,Math.sin(a)*distance,4.5,1.3,a+age*12,age*15+i,[C[1],C[3],C[5],C[6]],1-age/0.15);
    }
  };
}
