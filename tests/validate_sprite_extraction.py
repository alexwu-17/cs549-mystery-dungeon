from pathlib import Path
import hashlib,json
from PIL import Image
import numpy as np
root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'assets/sprites/extraction_manifest.json').read_text())
count=0
for character,meta in manifest.items():
 source=root/'assets/sprites/source'/meta['source']
 assert hashlib.sha256(source.read_bytes()).hexdigest()==meta['sha256']
 pixels=0
 for frame in meta['frames']:
  im=Image.open(root/'assets/sprites'/character/(frame+'.png'))
  a=np.array(im)
  assert im.mode=='RGBA' and list(im.size)==meta['canvas']
  assert a[:,:,3].max()==255 and a[:,:,3].min()==0
  assert (a[:,:,3]>32).sum()>1000
  # Padding ensures no extracted source pixel is clipped by its output canvas.
  assert not a[0,:,3].any() and not a[-1,:,3].any() and not a[:,0,3].any() and not a[:,-1,3].any()
  pixels+=int((a[:,:,3]>0).sum());count+=1
 assert pixels==meta['alpha_pixels'], 'Source alpha pixels must appear exactly once'
assert count==29
print('PASS: 29 nonblank RGBA frames, common canvases, unclipped padding, unchanged source hashes, exact source-alpha conservation')
