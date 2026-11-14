这里放正式的视频素材（Godot 原生 Ogg Theora，扩展名 .ogv）。

在 `resources/levels/behind_the_door.tres` 的 Inspector 中设置
`success_video` 和 `failure_video` 两个资源路径。留空即使用演示分镜。

两条视频从同一个时间零点开始，按关卡时间表剪辑；成功片长至少 9 秒，
失败片长至少 8.2 秒。声音由独立音频系统播放，视频内的声音会静音。
当前接口使用预先剪好的完整分支视频，不执行实时视频重剪辑。
