"""Regenerate the editor-visible rig and authored AnimationPlayer tracks (stdlib only).
Does not edit image pixels. Atlas regions select the generated body-part artwork.
"""
from pathlib import Path
import math
ROOT=Path(__file__).resolve().parents[1]
# id, editor node, atlas rectangle, visible height, resting pivot, centered artwork
PARTS=[
 ('hips','Pelvis',(685,107,215,195),10,(0,-39),False),
 ('chest','Torso',(351,37,266,274),22,(0,-60),False),
 ('head','Head',(63,61,208,224),18,(2,-71),True),
 ('ring','AccretionRing',(958,84,262,194),16,(2,-71),True),
 ('arm_front','LeftUpperArm',(88,330,141,276),12,(-10,-57),False),
 ('forearm_front','LeftForearm',(416,357,114,252),12,(-11,-44),False),
 ('hand_front','LeftHand',(716,394,139,175),7,(-11,-30),False),
 ('arm_back','RightUpperArm',(1027,335,142,274),12,(10,-56),False),
 ('forearm_back','RightForearm',(107,656,113,266),12,(11,-43),False),
 ('hand_back','RightHand',(396,702,147,167),7,(11,-29),False),
 ('thigh_front','LeftLeg',(711,640,170,280),13,(-6,-30),False),
 ('shin_front','LeftShin',(1035,640,132,218),12,(-6,-17),False),
 ('foot_front','LeftFoot',(69,1033,203,145),5,(-6,-5),False),
 ('thigh_back','RightLeg',(395,941,171,281),13,(6,-30),False),
 ('shin_back','RightShin',(731,945,127,213),12,(6,-17),False),
 ('foot_back','RightFoot',(999,1027,206,151),5,(6,-5),False),
]
REST={i:(p[0],p[1],0.0) for i,n,r,h,p,c in PARTS}
NAMES={i:n for i,n,*_ in PARTS}
def pose(**changes):
 d=REST.copy();d.update(changes)
 if 'head' in changes and 'ring' not in changes:d['ring']=changes['head']
 return d
# Each tuple is a distinct authored pose, never a whole-body scale transform.
CLIPS={
 'singularity_jab':[(0,pose()),(.045,pose(chest=(-2,-60,-.18),arm_front=(-12,-58,.3),forearm_front=(-15,-43,-.65),hand_front=(-10,-34,-.6))),
 (.075,pose(chest=(-2,-60,-.18),arm_front=(-13,-58,.4),forearm_front=(-8,-47,-1),hand_front=(4,-46,-1))),
 (.105,pose(chest=(2,-60,.14),head=(0,-71,-.06),arm_front=(-6,-57,-.9),forearm_front=(20,-54,-1.4),hand_front=(47,-53,-1.5))),
 (.145,pose(chest=(2,-60,.12),arm_front=(-5,-57,-1),forearm_front=(30,-54,-1.4),hand_front=(44,-53,-1.5))),
 (.21,pose(chest=(-1,-60,-.08),forearm_front=(5,-42,-.7),hand_front=(16,-40,-1))),(.28,pose())],
 'event_horizon_sweep':[(0,pose()),(.07,pose(chest=(-2,-61,-.25),arm_back=(9,-57,.8),forearm_back=(-18,-72,-.3),hand_back=(-22,-85,-.8))),
 (.12,pose(chest=(0,-61,-.12),arm_back=(10,-57,-.5),forearm_back=(11,-82,-1),hand_back=(25,-77,-1.5))),
 (.18,pose(chest=(3,-60,.22),head=(0,-72,-.18),arm_back=(11,-56,-1),forearm_back=(45,-62,-2),hand_back=(59,-47,-2.2))),
 (.235,pose(chest=(3,-59,.3),arm_back=(12,-56,-.5),forearm_back=(46,-35,-2.9),hand_back=(32,-20,-3))),
 (.30,pose(chest=(-1,-60,-.08),forearm_back=(19,-38,-.7),hand_back=(10,-31,-.4))),(.36,pose())],
 'gravity_reversal':[(0,pose()),(.09,pose(chest=(-4,-59,-.25),head=(-4,-73,.12),ring=(-4,-73,1.4),arm_front=(-12,-58,.6),forearm_front=(-7,-57,-1.8),hand_front=(-1,-60,-1.4))),
 (.15,pose(chest=(-5,-59,-.28),head=(-5,-73,.12),ring=(-5,-73,2.5),forearm_front=(2,-58,-1.7),hand_front=(10,-57,-1.5))),
 (.19,pose(chest=(-5,-59,-.27),head=(-4,-73,.15),ring=(-4,-73,3.1),arm_front=(-12,-57,-.7),forearm_front=(22,-59,-1.5),hand_front=(58,-50,-1.7))),
 (.25,pose(chest=(0,-59,.1),head=(-2,-72,-.1),ring=(-2,-72,4.3),arm_front=(-8,-57,-1),forearm_front=(40,-54,-1.4),hand_front=(52,-50,-1.6))),
 (.34,pose(chest=(-2,-60,-.12),forearm_front=(-14,-42,.3),hand_front=(-17,-45,-.5))),(.42,pose())],
 'collapse_headbutt':[(0,pose()),(.10,pose(hips=(-4,-36,-.1),chest=(-6,-56,-.2),head=(-12,-67,.1),arm_front=(-15,-54,.45),forearm_front=(-20,-40,.2),hand_front=(-23,-23,.3),arm_back=(13,-54,-.4),hand_back=(18,-25,-.3))),
 (.17,pose(hips=(-3,-37,-.1),chest=(-4,-57,-.15),head=(0,-69,.2),ring=(0,-69,1.2),forearm_front=(-17,-40,.4),hand_front=(-21,-26,.5))),
 (.205,pose(hips=(0,-38,.1),chest=(2,-58,.18),head=(34,-64,.15),ring=(34,-64,2.0),arm_front=(-4,-55,.8),forearm_front=(-12,-40,.7),hand_front=(-18,-27,.6))),
 (.245,pose(hips=(5,-36,.1),chest=(15,-57,.35),head=(35,-61,.3),ring=(35,-61,2.7),arm_front=(2,-54,.8),forearm_front=(-7,-40,.5),hand_front=(-18,-28,.5),arm_back=(18,-54,.65),forearm_back=(10,-38,.5),hand_back=(3,-23,.6))),
 (.30,pose(hips=(3,-38,0),chest=(10,-56,.1),head=(18,-66,-.2),ring=(18,-66,3.3),forearm_front=(-12,-40,.5),hand_front=(-15,-27,.4))),
 (.40,pose(chest=(-2,-61,-.12),head=(-4,-72,.06))),(.55,pose())]
}
# Keep the ring rotating forward through recovery, ending at the same orientation.
for clip in ['gravity_reversal','collapse_headbutt']:
 for t, key in CLIPS[clip]:
  x,y,_ = key['ring']
  key['ring'] = (x,y,t/CLIPS[clip][-1][0]*math.tau)

def vector(p):return 'Vector2(%g, %g)'%(p[0],p[1])
def build_scene():
 lines=['[gd_scene load_steps=19 format=3]', '', '[ext_resource type="Script" path="res://Scripts/void_visual.gd" id="1"]', '[ext_resource type="Texture2D" path="res://Assets/VoidConstruct/body_parts.png" id="2"]','']
 for i,n,r,h,p,c in PARTS:lines += [f'[sub_resource type="AtlasTexture" id="{n}"]','atlas = ExtResource("2")','region = Rect2(%g, %g, %g, %g)'%r,'filter_clip = true','']
 lines += ['[node name="VisualRoot" type="Node2D"]','texture_filter = 1','script = ExtResource("1")','','[node name="Rig" type="Node2D" parent="."]','']
 for i,n,r,h,p,c in PARTS:
  scale=h/r[3];depth=-2 if i.endswith('back') else 3 if i in ('head','ring') else 0
  lines += [f'[node name="{n}" type="Node2D" parent="Rig"]',f'position = {vector(p)}',f'z_index = {depth}','',f'[node name="Art" type="Sprite2D" parent="Rig/{n}"]',f'texture = SubResource("{n}")',f'scale = Vector2({scale}, {scale})',f'position = Vector2(0, {0 if c else h/2})','']
 lines += ['[node name="FloatingFragments" type="Node2D" parent="Rig"]','']
 (ROOT/'Scenes/void_visual.tscn').write_text('\n'.join(lines))
def build_library():
 lines=['[gd_resource type="AnimationLibrary" load_steps=6 format=3]','']
 clips={'RESET':[(0,pose())],**CLIPS}
 for name,keys in clips.items():
  lines += [f'[sub_resource type="Animation" id="{name}"]',f'resource_name = "{name}"',f'length = {keys[-1][0] if name!="RESET" else .001}']
  track=0
  for ident,node,*_ in PARTS:
   for prop in ['position','rotation']:
    values=[vector(p[ident]) if prop=='position' else str(p[ident][2]) for _,p in keys]
    times=', '.join(str(t) for t,_ in keys)
    # Fast extension is authored in the short gap between anticipation and impact.
    lines += [f'tracks/{track}/type = "value"',f'tracks/{track}/path = NodePath("VisualRoot/Rig/{node}:{prop}")',f'tracks/{track}/interp = 1',f'tracks/{track}/keys = {{',f'"times": PackedFloat32Array({times}),',f'"transitions": PackedFloat32Array({", ".join("1" for _ in keys)}),','"update": 0,','"values": ['+', '.join(values)+']','}']
    track+=1
  lines+=['']
 lines+=['_data = {'] if False else []
 lines+=['[resource]','_data = {']
 lines += [f'&"{name}": SubResource("{name}")'+(',' if k<len(clips)-1 else '') for k,name in enumerate(clips)]
 lines+=['}','']
 (ROOT/'Animations/gravity_melee.tres').write_text('\n'.join(lines))
if __name__=='__main__':
 build_scene();build_library()
