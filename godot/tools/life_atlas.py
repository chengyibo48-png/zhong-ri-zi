from PIL import Image
import numpy as np

def components(alpha):
 mask=np.asarray(alpha)>=64
 parents=[0];runs=[];prior=[]
 def root(i):
  while parents[i]!=i:
   parents[i]=parents[parents[i]];i=parents[i]
  return i
 for y,row in enumerate(mask):
  cuts=np.flatnonzero(np.diff(np.r_[False,row,False].astype(np.int8)))
  current=[];cursor=0
  for start,end in zip(cuts[::2],cuts[1::2]):
   start=int(start);end=int(end)
   while cursor<len(prior) and prior[cursor][1]<start:cursor+=1
   match=[];k=cursor
   while k<len(prior) and prior[k][0]<=end:
    if prior[k][1]>=start:match.append(root(prior[k][2]))
    k+=1
   if match:
    tag=match[0]
    for other in match[1:]:
     other=root(other);tag=root(tag)
     if tag!=other:parents[other]=tag
   else:tag=len(parents);parents.append(tag)
   current.append((start,end,tag));runs.append((y,start,end,tag))
  prior=current
 labels=np.zeros(mask.shape,dtype=np.int32);boxes={}
 for y,start,end,tag in runs:
  tag=root(tag);labels[y,start:end]=tag
  b=boxes.get(tag)
  if b is None:boxes[tag]=[start,y,end,y+1]
  else:b[0]=min(b[0],start);b[1]=min(b[1],y);b[2]=max(b[2],end);b[3]=max(b[3],y+1)
 return labels,boxes,len(parents)

def normalize(src,cols,rows,cell,row_order=None):
 image=Image.open(src).convert('RGBA')
 if image.getchannel('A').getextrema()[0]!=0:raise ValueError('Atlas has no transparency')
 labels,component_boxes,n=components(image.getchannel('A'))
 selected=[];cells=[]
 for y in range(rows):
  for x in range(cols):
   bounds=(round(x*image.width/cols),round(y*image.height/rows),round((x+1)*image.width/cols),round((y+1)*image.height/rows))
   count=np.bincount(labels[bounds[1]:bounds[3],bounds[0]:bounds[2]].ravel(),minlength=n);count[0]=0
   tag=int(np.argmax(count))
   if count[tag]==0:raise ValueError(f'Empty source cell {src}, {x},{y}')
   selected.append(tag);cells.append(bounds)
 if len(set(selected))!=cols*rows:raise ValueError(f'Ambiguous overlapping source poses: {src}')
 primary=set(selected);frames=[];records=[]
 for y in (row_order or list(range(rows))):
  for x in range(cols):
   i=y*cols+x;tag=selected[i];left,top,right,bottom=component_boxes[tag]
   bounds=(max(0,left-3),max(0,top-3),min(image.width,right+3),min(image.height,bottom+3))
   part=image.crop(bounds);pixels=np.array(part)
   cropped=labels[bounds[1]:bounds[3],bounds[0]:bounds[2]]
   foreign=np.isin(cropped,list(primary-{tag}));pixels[foreign,3]=0
   part=Image.fromarray(pixels);frames.append(part)
   records.append({'cell':[x,y],'gridBounds':list(cells[i]),'sourceBounds':list(bounds),'extraction':'whole alpha-connected silhouette, excluding other primary poses'})
 factor=min((cell[0]-12)/max(p.width for p in frames),(cell[1]-16)/max(p.height for p in frames))
 sheet=Image.new('RGBA',(cell[0]*cols,cell[1]*rows));anchor=(cell[0]//2,cell[1]-6)
 for i,p in enumerate(frames):
  p=p.resize((max(1,round(p.width*factor)),max(1,round(p.height*factor))),Image.Resampling.LANCZOS)
  sheet.alpha_composite(p,((i%cols)*cell[0]+anchor[0]-p.width//2,(i//cols)*cell[1]+anchor[1]-p.height))
 return sheet,records
