"""Reproducible lossless sprite isolation. Requires Pillow, numpy, scipy.
Strong alpha components seed frame ownership; faint connected fringes use nearest
seed ownership. No resampling, repainting, or source modification is performed.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image
from scipy.ndimage import label, find_objects, distance_transform_edt
ROOT = Path(__file__).resolve().parents[1]
COMMON = ['front', 'back', 'left', 'right', 'attack_front', 'attack_back', 'attack_left', 'attack_right']
SHEETS = {
 'swordsman': ('AISwordsmanPlaceholderPixelSheet.png', COMMON, [(227,424),(668,424),(1095,434),(1538,434),(230,824),(669,824),(1130,834),(1518,834)]),
 'skeleton': ('AISkeletonPlaceholderPixelSheet.png', COMMON, [(225,440),(668,430),(1144,440),(1504,437),(236,858),(684,856),(1141,856),(1520,857)]),
 'minotaur': ('AIMinotaurPlaceholderPixelSheet.png', ['front','back','left','right','charge'] + ['spin_%02d' % i for i in range(1,9)], [(152,340),(460,340),(770,340),(1110,342),(151,635),(504,630),(806,630),(1100,631),(169,920),(475,920),(806,920),(1090,919),(172,1206)])
}

def extract():
 manifest = {}
 for character, (filename,names,anchors) in SHEETS.items():
  source = ROOT/'assets/sprites/source'/filename
  im = np.array(Image.open(source).convert('RGBA'))
  components,n = label(im[:,:,3] > 32)
  seeds = np.zeros(components.shape,dtype=np.int32)
  # Explicit frame centers/regions, independent of nominal equal-cell borders.
  centers = np.array([(x,y-140) for x,y in anchors])
  regions = []
  for ident,sl in enumerate(find_objects(components),1):
   if sl is None: continue
   mask = components[sl] == ident
   if mask.sum() < 1000: continue
   center = np.array([(sl[1].start+sl[1].stop)/2,(sl[0].start+sl[0].stop)/2])
   frame = int(np.argmin(((centers-center)**2).sum(axis=1)))
   seeds[sl][mask] = frame+1
   regions.append({'frame':names[frame], 'bounds':[sl[1].start,sl[0].start,sl[1].stop,sl[0].stop]})
  assert set(np.unique(seeds)) == set(range(len(names)+1))
  _,nearest = distance_transform_edt(seeds == 0,return_indices=True)
  owners = seeds[tuple(nearest)]
  bounds=[]
  for i,(ax,ay) in enumerate(anchors,1):
   yy,xx=np.where((owners==i)&(im[:,:,3]>0))
   assert len(xx)>0
   bounds.append((int(xx.min()),int(yy.min()),int(xx.max())+1,int(yy.max())+1))
  half=max(max(ax-b[0],b[2]-ax) for (ax,ay),b in zip(anchors,bounds))+16
  above=max(ay-b[1] for (ax,ay),b in zip(anchors,bounds))+16
  below=max(max(0,b[3]-ay) for (ax,ay),b in zip(anchors,bounds))+16
  width,height=half*2,above+below
  out=ROOT/'assets/sprites'/character;out.mkdir(parents=True,exist_ok=True)
  for i,(name,(ax,ay),b) in enumerate(zip(names,anchors,bounds),1):
   x0,y0,x1,y1=b
   crop=im[y0:y1,x0:x1].copy()
   crop[owners[y0:y1,x0:x1]!=i]=0
   canvas=Image.new('RGBA',(width,height))
   canvas.paste(Image.fromarray(crop),(half+x0-ax,above+y0-ay))
   canvas.save(out/(name+'.png'))
  manifest[character]={'source':filename,'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'canvas':[width,height],'foot_anchor':[half,above],'anchors':anchors,'regions':regions,'frames':names,'alpha_pixels':int((im[:,:,3]>0).sum())}
 (ROOT/'assets/sprites/extraction_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print(json.dumps({k:{'canvas':v['canvas'],'foot_anchor':v['foot_anchor'],'frames':len(v['frames'])} for k,v in manifest.items()}))
if __name__=='__main__':extract()
