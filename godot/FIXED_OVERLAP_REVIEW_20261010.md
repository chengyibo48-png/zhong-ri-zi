# 固定物件相交逐项复核（2026-10-10）

## 本批当前复核

原37对、61物件四季轮廓重新测量；当前注册外框25对，规划相交0，742节点保留。第0/11/24/25对四季核心相交0。证据为 continuation-fixed-silhouette-0..3-20261010.json；真实入口/导航87973检查通过。此前各批次证据为历史版本，不能替代本批证据。


原37对均已查看当前实际场景和独立渲染轮廓。9对已修复，19对无核心轮廓相交，9对为自然层叠，0对优先遗留。当前登记外框仍相交25对，不等于30处阻路。核心轮廓已检测四季，完整场景逐对截图为春季，世界像素分辨率1、透明度阈值0.5；半透明边缘仍需独立核对。

| 序号 | 原节点 | 结论 | 查看与处理 |
|---|---|---|---|
| 0 | village:8 / tiles:84 | fixed_by_painted_asset | 本批透明茶架/灯基图替换程序外形，原位置与碰撞保留；四季核心相交0/0/0/0，实际春季截图复查通过 |
| 1 | village:122 / village:189 | accepted_natural_depth | 树冠与后方长椅形成自然前后景；长椅主体可识别 |
| 2 | village:123 / tiles:22 | accepted_natural_depth | 树叶边缘与灯杆相邻，只有2个核心像素，主体保持可识别 |
| 3 | village:124 / village:181 | accepted_natural_depth | 树冠与长椅仅轻微遮挡，保留树下休息氛围 |
| 4 | village:125 / tiles:33 | accepted_natural_depth | 树冠与地面碎石为正常景观层叠 |
| 5 | village:127 / tiles:36 | fixed_visual_overlap | non-collidable tree relocated within its region; no core intersection with lamp in all four seasons |
| 6 | village:127 / tiles:41 | conservative_rectangle_without_opaque_core_intersection | 当前真实渲染的核心轮廓没有相交；保守矩形把空白、枝叶边缘或低矮道具高度包含在内 |
| 7 | village:175 / tiles:29 | conservative_rectangle_without_opaque_core_intersection | 当前真实渲染的核心轮廓没有相交；保守矩形把空白、枝叶边缘或低矮道具高度包含在内 |
| 8 | village:208 / tiles:49 | fixed_visual_overlap | 河边亭子缩为独立小歇脚亭，已与织机轮廓分开，脚点与碰撞未移动 |
| 9 | village:208 / tiles:55 | fixed_visual_overlap | 河边亭子等比缩小后与收拢渔网分开 |
| 10 | village:331 / tiles:75 | accepted_natural_depth | 树冠与林下石块正常层叠 |
| 11 | village:334 / tiles:70 | fixed_by_painted_asset | 本批透明茶架/灯基图替换程序外形，原位置与碰撞保留；四季核心相交0/0/0/0，实际春季截图复查通过 |
| 12 | village:413 / village:425 | conservative_rectangle_without_opaque_core_intersection | 当前真实渲染的核心轮廓没有相交；保守矩形把空白、枝叶边缘或低矮道具高度包含在内 |
| 13 | village:437 / tiles:19 | accepted_natural_depth | 树冠与地面碎石正常层叠 |
| 14 | village:447 / tiles:8 | fixed_visual_overlap | non-collidable tree relocated within its region; no core intersection with lamp in all four seasons |
| 15 | village:448 / tiles:13 | conservative_rectangle_without_opaque_core_intersection | 当前真实渲染的核心轮廓没有相交；保守矩形把空白、枝叶边缘或低矮道具高度包含在内 |
| 16 | village:449 / village:464 | conservative_rectangle_without_opaque_core_intersection | 当前真实渲染的核心轮廓没有相交；保守矩形把空白、枝叶边缘或低矮道具高度包含在内 |
| 17 | village:449 / village:465 | accepted_natural_depth | 柳枝与岸边石块正常层叠，树干位置可读 |
| 18 | village:449 / village:466 | conservative_rectangle_without_opaque_core_intersection | 当前真实渲染的核心轮廓没有相交；保守矩形把空白、枝叶边缘或低矮道具高度包含在内 |
| 19 | village:450 / village:471 | conservative_rectangle_without_opaque_core_intersection | 当前真实渲染的核心轮廓没有相交；保守矩形把空白、枝叶边缘或低矮道具高度包含在内 |
| 20 | village:547 / village:579 | accepted_natural_depth | 门前告示牌和建筑立面轻微层叠，告示牌主体和门口可读 |
| 21 | village:549 / village:566 | accepted_natural_depth | 侧面树冠与建筑檐边轻微重叠，入口可见 |
| 22 | village:567 / village:613 | fixed_visual_overlap | 无独立碰撞的树移至鸡鸭舍后方绿地（2760,2388），核心轮廓相交从1232像素降为0；清除道路、建筑、入口、操作点及陈设预留区检查通过 |
| 23 | tiles:1 / tiles:6 | conservative_rectangle_without_opaque_core_intersection | 当前真实渲染的核心轮廓没有相交；保守矩形把空白、枝叶边缘或低矮道具高度包含在内 |
| 24 | tiles:29 / tiles:34 | fixed_by_painted_asset | 本批透明茶架/灯基图替换程序外形，原位置与碰撞保留；四季核心相交0/0/0/0，实际春季截图复查通过 |
| 25 | tiles:36 / tiles:41 | fixed_by_painted_asset | 本批透明茶架/灯基图替换程序外形，原位置与碰撞保留；四季核心相交0/0/0/0，实际春季截图复查通过 |
| 26 | tiles:43 / tiles:48 | conservative_rectangle_without_opaque_core_intersection | 当前真实渲染的核心轮廓没有相交；保守矩形把空白、枝叶边缘或低矮道具高度包含在内 |
| 27 | tiles:49 / tiles:55 | conservative_rectangle_without_opaque_core_intersection | 当前真实渲染的核心轮廓没有相交；保守矩形把空白、枝叶边缘或低矮道具高度包含在内 |
| 28 | tiles:63 / tiles:69 | conservative_rectangle_without_opaque_core_intersection | 当前真实渲染的核心轮廓没有相交；保守矩形把空白、枝叶边缘或低矮道具高度包含在内 |
| 29 | tiles:70 / tiles:76 | conservative_rectangle_without_opaque_core_intersection | 当前真实渲染的核心轮廓没有相交；保守矩形把空白、枝叶边缘或低矮道具高度包含在内 |
| 30 | tiles:71 / tiles:76 | conservative_rectangle_without_opaque_core_intersection | 当前真实渲染的核心轮廓没有相交；保守矩形把空白、枝叶边缘或低矮道具高度包含在内 |
| 31 | tiles:78 / tiles:83 | conservative_rectangle_without_opaque_core_intersection | 当前真实渲染的核心轮廓没有相交；保守矩形把空白、枝叶边缘或低矮道具高度包含在内 |
| 32 | tiles:84 / tiles:90 | conservative_rectangle_without_opaque_core_intersection | 当前真实渲染的核心轮廓没有相交；保守矩形把空白、枝叶边缘或低矮道具高度包含在内 |
| 33 | tiles:85 / tiles:90 | conservative_rectangle_without_opaque_core_intersection | 当前真实渲染的核心轮廓没有相交；保守矩形把空白、枝叶边缘或低矮道具高度包含在内 |
| 34 | tiles:105 / tiles:111 | conservative_rectangle_without_opaque_core_intersection | 当前真实渲染的核心轮廓没有相交；保守矩形把空白、枝叶边缘或低矮道具高度包含在内 |
| 35 | tiles:113 / tiles:118 | conservative_rectangle_without_opaque_core_intersection | 当前真实渲染的核心轮廓没有相交；保守矩形把空白、枝叶边缘或低矮道具高度包含在内 |
| 36 | tiles:120 / tiles:125 | conservative_rectangle_without_opaque_core_intersection | 当前真实渲染的核心轮廓没有相交；保守矩形把空白、枝叶边缘或低矮道具高度包含在内 |

本批复测：artifacts/remaining-fixed-silhouette-review-20261010.json、remaining-fixed-overlap-review-20261010.json、remaining-forage-layout-audit-20261010.json；其他36对核心相交数量与前批一致。
本批四季复测：artifacts/seasonal-tree-silhouette-0..3-20261010.json、seasonal-tree-fixed-overlap-review-20261010.json、seasonal-tree-layout-audit-20261010.json。第5与14对四季均为0；第0对继续列入待优化，不计为修复。

本批最新：artifacts/polish-fixed-silhouette-0..3-20261010.json、polish-fixed-overlap-review-20261010.json、polish-layout-envelope-audit-20261010.json。此前第0对继续列入待优化的结论为历史结果。本批全图入口与导航另行检查87946项通过；已核对37对实际截图，但不宣称全地图所有像素绝对无相交。
