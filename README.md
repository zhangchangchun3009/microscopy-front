# 显微镜代理 — Flutter macOS 客户端

智能显微镜代理系统的桌面前端，运行在 Mac 上，通过 WebSocket 与树莓派上的 MicroClaw Agent 交互，同时显示显微镜实时视频流。

## 功能

- **实时视频流**：通过 MJPEG 协议显示显微镜摄像头画面
- **Agent 对话**：文本输入框发送自然语言指令，Agent 自主调用显微镜工具执行
- **工具调用可视化**：展示 Agent 的工具调用过程（调用参数、执行结果），可展开查看详情
- **连接管理**：支持自定义 WebSocket 和视频流地址，实时显示连接状态

## 架构

```
Flutter (Mac)  ──WebSocket──>  MicroClaw (Pi)  ──MCP──>  microscopy_server (Pi)
     │                                                          │
     ├──────────────── Socket.IO ───────────────────────────────┤
     │   (get_settings 初始化 + 后续进度/日志等，与 Web 前端一致)    │
     └──────────────── MJPEG 视频流 ────────────────────────────┘
```

- **Socket.IO**：连接 microscopy_server 后先 `emit('get_settings')`，后端应用相机/LED 等设置，MJPEG 才能正常显示；同一连接可复用，用于长任务进度（如 `global_scan_progress`、`stitch_progress`、`focus_stack_progress` 等），便于迁移原 Web 前端逻辑。

## 默认配置

| 参数 | 默认值 |
|------|--------|
| WebSocket 地址 | `ws://10.198.31.242:42617/ws/chat` |
| 视频流地址 | `http://10.198.31.242:5000/video_feed` |

可在应用内通过设置按钮修改。

## 运行

```bash
flutter pub get
flutter run -d macos
```

## 依赖

- `flutter_mjpeg` — MJPEG 视频流渲染
- `web_socket_channel` — Agent WebSocket 通信
- `socket_io_client` — microscopy_server Socket.IO（get_settings 初始化及后续进度等）

## WebSocket 消息协议

客户端发送：
```json
{"type": "message", "content": "自动对焦"}
```

服务端推送：
```json
{"type": "chunk", "content": "正在执行..."}
{"type": "tool_call", "name": "fast_focus", "args": {"steps": 200}}
{"type": "tool_result", "name": "fast_focus", "output": "..."}
{"type": "done", "full_response": "自动对焦已完成，Z轴位置 10.5mm"}
```

## 故障排查：WebSocket「was not upgraded」

若出现 `Connection ... was not upgraded to websocket`，说明 TCP 已连通但 HTTP 未完成 WebSocket 升级，常见原因：

1. **Gateway 未监听外网**：Pi 上 `config.toml` 需包含：
   ```toml
   [gateway]
   host = "0.0.0.0"   # 或 "[::]"
   allow_public_bind = true
   ```
   否则仅 `127.0.0.1` 可连，Mac 无法访问。

2. **Pairing 鉴权**：若已启用配对，需在 URL 加 `?token=<bearer_token>`，或临时关闭配对做测试。

3. **验证服务端**：在 Mac 上执行：
   ```bash
   curl -v -N -H "Connection: Upgrade" -H "Upgrade: websocket" \
     -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
     -H "Sec-WebSocket-Version: 13" \
     http://10.198.31.242:42617/ws/chat
   ```
   正常应返回 `101 Switching Protocols`；若为 `401` 则需 token，若为 `200` 且是 HTML 则路由或代理配置有误。
