# 序章美术素材

来源为用户提供的两份 6000×4500 PSD。运行素材按比例缩至 1600×1200，各透明图层裁去外围空白，位置保存在 JSON 中。

- wide 为电话亭远景和人物背影。
- receiver 为接听姿势、听筒及远景。
- layers.json 记录各独立图层原始名字、可见性和坐标。
- scene_layers.json 用于预览，将剪贴和混合效果烘焙进 background.png，人物相关图层单独叠加。
- studio_logo.jpg 为用户提供的原始 Logo，保留白底。

在 Godot 打开 scenes/prologue_preview.tscn，按 F6 预览远景、接听姿势过渡、镜头上移与标题出现。空格或末尾的重播按钮重新播放。

《声之行》临时标题使用 Godot 字体绘制，颜色和位置在 scripts/presentation/prologue_preview.gd 中可编辑。本场景用于美术验收，接听使用淡入过渡，尚未接入投币教学、拨号特写和序章音频。
