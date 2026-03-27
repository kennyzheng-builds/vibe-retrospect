# AgentsLink — Project Knowledge

> 让 AI Agent 之间直接传递完整上下文，消除人类传话造成的信息丢失。

## Quick Facts

| Metric | Value |
|---|---|
| What | Agent 间协作链接服务：打包问题上下文生成链接，对方 Agent 读取并分析 |
| Built by | Kenny with Claude Code (on HappyCapy) |
| Timeline | 2026-03-07 → 2026-03-17 (11 天) |
| Commits | 80 |
| Tech stack | Cloudflare Workers + KV + 原生 HTML/CSS/JS |
| Monthly cost | $0（域名 ~$10/年） |
| Repo | https://github.com/kennyzheng-builds/agentslink (公开镜像) |

## The Problem

Kenny 在用 AI 写代码的时候，经常遇到自己解决不了的问题，需要找朋友帮忙。但他发现了一个痛点：

**人在 Agent 之间传话时，信息会大量丢失。** 比如一个飞书权限配置问题，涉及到具体的错误信息、环境变量、API 版本——这些技术细节在人口头转述的过程中会丢掉一半，对方再转给自己的 Agent 又丢一半。来回好几轮还没搞清楚问题是什么。

> "用这个 skill 之后，我希望它生成一个链接，然后主人只要把链接丢给另外一个人，那个人把链接丢给他自己的 agent，那个 agent 就能够基于这些信息提供对应的解决方案，然后再回传一个链接。" — from session on 2026-03-09

核心洞察：**问题不在于 AI 不够聪明，而在于人类传话过程中的信息损耗。** 让 Agent 自己打包完整上下文，人只负责转发一条链接。

## Key Decisions

### Decision: 异步链接而非实时通信
- **Context**: 最初考虑过让两个 Agent 实时对话
- **Options considered**: 实时通信协议 vs 异步链接分享
- **Chosen**: 异步链接（生成链接 → 人转发 → 对方读取 → 回复链接）
- **Why**: 零基础设施成本，不需要 WebSocket 服务器，人保持控制权
- **Quote**: "不需要两个 agent 实时聊天——只要让 agent（而不是人）来打包和解读上下文。人类只负责传递（发个微信），但打包和解读由 Agent 完成。"

### Decision: Cloudflare Workers + KV
- **Context**: 需要一个零成本的后端来存储和分发链接内容
- **Options considered**: Vercel Serverless, AWS Lambda, Cloudflare Workers
- **Chosen**: Cloudflare Workers + KV
- **Why**: 免费额度足够，全球边缘部署，KV 支持 TTL 自动过期
- **Quote**: "我是个人开发者，不赚钱" — from session on 2026-03-09

### Decision: 访问码保护
- **Context**: 链接内容可能包含技术细节，不能让任何人都能看到
- **Options considered**: 无保护 vs 访问码 vs 登录认证
- **Chosen**: 6 位访问码（生成链接时自动产生，访问时需要输入）
- **Why**: 轻量、无需注册、足够安全
- **Quote**: "你说要不要生成 url 的同时，后面再附上一个号码，另一个 agent 拿到号码后，才能阅读这个 url 的内容。这样可以避免其他人获取到 url 后，来阅读内容" — from session on 2026-03-09

### Decision: 24 小时自动过期
- **Context**: 内容存储在 KV 中，需要决定保留多久
- **Options considered**: 永久保存 vs 7 天 vs 24 小时
- **Chosen**: 24 小时自动删除
- **Why**: 保护隐私，减少存储成本，协作问题通常当天就解决
- **Quote**: "为了保护用户隐私，是不是设置更短时间" — from session on 2026-03-09

### Decision: 只读协作（Read-only Consultation）
- **Context**: Agent 之间协作的权限边界应该在哪
- **Options considered**: 允许执行操作 vs 只读分析建议
- **Chosen**: 只读——只给建议，不执行操作
- **Why**: 安全边界清晰，信任门槛低，核心价值是信息传递而非远程操控

### Decision: 公私仓库分离
- **Context**: 项目有公开的 Skill 代码和私有的后台分析功能
- **Options considered**: 单公开仓库 vs 单私有仓库 vs 私有主仓库 + 公开镜像
- **Chosen**: 私有主仓库 + GitHub Actions 自动同步到公开镜像
- **Why**: 后台管理面板、统计代码不应该公开，但 Skill 和核心 API 需要开源
- **Quote**: "我想做这个官网这部分，以及我想看到用户的上报。这个东西是不是要在 GitHub 上面单独建一个私有的仓库" — from session on 2026-03-13

### Decision: 内容协商（Content Negotiation）
- **Context**: 同一个 URL 需要服务三种客户端：浏览器、Agent、curl
- **Options considered**: 分 URL（/api/ vs /web/） vs 同 URL 不同 Accept Header
- **Chosen**: 同 URL，根据 Accept Header 返回不同格式
- **Why**: 简洁，一个链接多用途
- Browser (`text/html`) → 渲染 HTML 页面
- Agent (`application/json`) → 返回 JSON + `_instructions` 字段指导 Agent 行为
- curl → 纯文本 ASCII 格式

## Architecture

### Tech Stack
| Layer | Choice | Why |
|---|---|---|
| Runtime | Cloudflare Workers (ES Module) | 免费、全球边缘、无冷启动 |
| Storage | Cloudflare KV | 免费额度、原生 TTL 支持、全球复制 |
| Frontend | 原生 HTML/CSS/JS（零框架） | 极小体积、存入 KV 直接 serve |
| Domain | agentslink.link | 自定义域名解决 workers.dev 在中国被墙的问题 |
| CI/CD | GitHub Actions | 私有仓库自动同步到公开仓库 |
| Private code | `#region private` markers + build script | 自动剥离私有代码再同步 |

### System Design
```
用户 A 的 Agent                    用户 B 的 Agent
     │                                  │
     │ POST /create                     │
     │ (打包问题上下文)                  │
     ▼                                  │
┌─────────────────────┐                 │
│  Cloudflare Worker   │                 │
│  agentslink.link     │                 │
│                     │                 │
│  KV Storage:        │                 │
│  req:{id} → content │ GET /r/{id}     │
│  reply:{id} → reply │◄────────────────┤
│  rate:{ip} → count  │                 │
│  site:home → HTML   │  POST /reply/{id}
│  skill:latest → MD  │◄────────────────┤
└─────────────────────┘                 │
     │                                  │
     │ GET /r/{id}/reply                │
     │◄─────────────────────────────────┘
     ▼
  读取回复，执行建议
```

### Data Model
| KV Key | Value | TTL |
|---|---|---|
| `req:{id}` | `{content, from, created_at, access_code}` | 24h |
| `reply:{id}` | `{content, from, created_at}` | 24h |
| `rate:{ip}:{minute}` | 请求计数 | 60s |
| `site:home` | 首页 HTML | 永久 |
| `skill:latest` | SKILL.md 内容 | 永久 |

### API Routes
| Route | Method | Function |
|---|---|---|
| `/create` | POST | 创建协作请求，返回 `{url, id, access_code}` |
| `/r/:id` | GET | 读取请求（需访问码，支持内容协商） |
| `/reply/:id` | POST | 提交回复 |
| `/r/:id/reply` | GET | 读取回复 |
| `/install` | GET | 返回 SKILL.md（供 Agent 安装） |
| `/` | GET | 首页（浏览器 HTML / Agent JSON / curl 文本） |

### Security Model
1. **访问码**: 6 位随机码（不易混淆字符集 `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`）
2. **限流**: 每 IP 每分钟最多 5 次请求
3. **反爬虫**: robots.txt 禁止、noindex 标签、内容用 JS 渲染
4. **敏感信息过滤**: Skill 指导 Agent 打包时自动脱敏（API Key、密码、内部路径）
5. **自动过期**: 24h TTL，数据自动清除

## Development Timeline

| Date | What happened | Commits |
|---|---|---|
| 3/7 | 项目起步，添加网站 v2 | 1 |
| 3/8 | Initial commit，项目结构、文档、规则建立 | 4 |
| 3/9 | **爆发日**：从文本 Skill 升级为 API 链接服务，Cloudflare Workers 上线，域名切换，限流，Logo，首页 | 19 |
| 3/10 | 继续完善 | 1 |
| 3/11 | 迭代优化 | 3 |
| 3/13 | **最大峰值**：首页重设计、后台管理面板、统计分析系统、页面打磨 | 29 |
| 3/15 | Skill 触发优化、i18n、中文文案重写 | 6 |
| 3/16 | 内容协商、UI polish、动态过期倒计时、Logo 统一、API 验证、分发渠道 | 16 |
| 3/17 | UI 简化收尾 | 1 |

**关键转折点**：
- **3/9**: 从纯文本 Markdown Skill 升级为 API 链接服务——这是整个产品形态的根本转变
- **3/13**: 29 次 commit，一天内完成了首页设计和后台系统

## How Builder & AI Collaborated

### Workflow Rules (from CLAUDE.md)
1. **先讨论再动手** — 任何新功能先讨论方案，用户确认后才写代码
2. **用户角色** — 非技术独立产品负责人，Claude 负责所有技术决策
3. **强制 Staging** — 绝对不能跳过测试环境直接部署正式环境
4. **页面截图** — 涉及页面改动，必须 before/after 全页面截图附在 commit 中
5. **上下文恢复** — 每次新对话先读 `docs/status.md` 恢复上下文
6. **中文沟通** — 全程中文

### Collaboration Patterns That Worked
- **多窗口并行开发**: 用 subagent 处理独立任务（调研、测试），主线程继续开发
- **截图验收**: 每次页面改动后截图对比，4 种组合验证（中文/英文 x 电脑/手机）
- **进度文件**: `docs/status.md` + `docs/tasks/` 确保对话切换不丢上下文
- **反馈即规则**: 用户的协作反馈立刻写入 CLAUDE.md 成为永久规则

### Feedback That Shaped the Process
- "后续如果涉及到页面逻辑的改动，你一定要把 before 和 after 截图，commit 时带上去" → 写入 CLAUDE.md
- "你看一下上面的对话，以及你的行为日志，分析为什么要测试这么多轮，你才把问题解决" → 推动更严格的测试流程
- "我是个人开发者，不赚钱" → 所有技术方案优先免费方案

## Pitfalls & Solutions

### Pitfall: workers.dev 域名在中国无法访问
- **Symptom**: 部署到 Cloudflare Workers 后，国内用户打不开
- **Root cause**: Cloudflare 的 `*.workers.dev` 域名在中国被 DNS 污染
- **Fix**: 购买自定义域名 `agentslink.link`，绑定到 Worker
- **Prevention**: 面向中国用户的项目，第一天就买自定义域名，不要用 workers.dev

### Pitfall: i18n 模板字符串的单引号转义
- **Symptom**: 英文页面中 `Kenny's Agent` 显示异常
- **Root cause**: JS 模板字符串中 `\'` 会被模板字面量消费，需要 `\\'`
- **Fix**: 所有 i18n 字符串中的单引号使用 `\\'` 双重转义
- **Prevention**: 写完 i18n 字符串后，用 4 种语言/设备组合测试

### Pitfall: 跳过 Staging 直接上线导致 bug
- **Symptom**: 正式环境出现功能异常
- **Root cause**: 没有在测试环境验证就部署了正式环境
- **Fix**: 回退并重新部署
- **Prevention**: 在 CLAUDE.md 写死铁律"先 staging 再 production"，Agent 会自动遵守

### Pitfall: Agent 生成回复不够主动
- **Symptom**: Agent 读取协作请求后，分析了问题但等用户确认才生成回复链接
- **Root cause**: Skill 文件中没有明确指示"分析后直接生成回复"
- **Fix**: 在 SKILL.md 中明确写"分析后自动上传回复并生成链接"
- **Prevention**: Skill 指令越明确越好，不要给 Agent 留歧义空间
- **Quote**: "在 agent 看了 request 后，提供了解决方案，但是没有自主生成 reply url，而是要用户确认才生成，这样不够主动，对用户来说很麻烦" — from session on 2026-03-16

### Pitfall: Git commit 历史丢失
- **Symptom**: GitHub 仓库只显示 1 条 commit，但本地已经提交了几十次
- **Root cause**: 推送方式不正确或环境重建后没有同步
- **Fix**: 从 HappyCapy 工作区重新推送完整历史
- **Prevention**: 定期确认远程仓库与本地 commit 数一致

### Pitfall: Logo 偏移和透明度问题
- **Symptom**: 导出的 Logo 在页面上显示偏移或有灰色背景
- **Root cause**: PNG 导出时包含了额外的透明区域或背景色
- **Fix**: 裁剪 PNG 到紧凑边界，移除背景色
- **Prevention**: 每次更换 Logo 后检查所有页面的实际显示效果

### Pitfall: 本地 Markdown 和在线 URL 的内容不一致
- **Symptom**: 服务器失败时 Agent 生成本地 Markdown，成功时上传 URL，两者内容格式不同
- **Root cause**: 两个输出路径没有共用同一个格式化函数
- **Fix**: 统一两种输出的格式逻辑
- **Prevention**: 所有输出路径复用同一个格式化模块

## Build Guide (For Someone Starting Fresh)

### Prerequisites
1. **Cloudflare 账号**（免费）— https://dash.cloudflare.com/sign-up
2. **GitHub 账号**（免费）— https://github.com
3. **自定义域名**（约 $10/年）— 推荐在 Cloudflare 直接购买
4. **Claude Code** 或类似 AI 编程工具
5. **Node.js** — 用于 wrangler CLI

### Recommended Build Order
1. **产品方案** (2-3 天): 想清楚做什么、不做什么。写 `docs/product-spec.md` 和 `docs/decisions.md`。核心问题：你解决了谁的什么问题？MVP 只做一件事。
2. **项目规则** (半天): 创建 `CLAUDE.md`，定义协作规范。包括：先讨论再动手、强制 staging、进度追踪。
3. **后端 API** (1-2 天): Cloudflare Worker + KV。先实现最核心的两个接口：创建请求（POST /create）和读取请求（GET /r/:id）。
4. **安全加固** (1 天): 访问码保护、限流、敏感信息过滤、自动过期。
5. **首页** (1 天): 单页 HTML，存入 KV serve。支持内容协商。
6. **Agent Skill** (1-2 天): 写 SKILL.md 定义 Agent 行为。测试多轮对话确保流程通畅。
7. **体验打磨** (2-3 天): 多语言、响应式、Logo、文案。每次改动 4 种组合测试。
8. **分发** (1 天): GitHub 开源仓库、官网安装页面、skill 平台分发。

### CLAUDE.md Template

```markdown
# [项目名] 项目规则

## 用户角色
我是产品负责人，不写代码。所有技术方案和代码由你（Claude）来做。
- 我负责：产品方向、体验判断、文案、方案确认
- 你负责：技术选型、写代码、目录结构、Git 管理、部署

## 工作流
1. 任何新功能，先讨论方案，我确认后再写代码
2. 方案讨论用我能听懂的话，不要用技术术语
3. 每完成一个模块就 commit，不要等全部做完
4. 遇到需要我做的准备工作（注册账号、买域名等），提前告知

## 部署规范
1. 先部署到 staging 测试环境
2. 我在测试环境验证通过
3. 再部署到 production 正式环境
**绝对不能跳过 staging 直接部署 production。**

## 页面改动规范
- 涉及页面改动，必须 before/after 全页面截图
- 验证 4 种组合：中文+电脑、中文+手机、英文+电脑、英文+手机

## 进度追踪
- `docs/status.md` 记录整体进度
- `docs/tasks/` 记录每个任务细节
- 每次新对话先读取进度文件，恢复上下文

## 成本原则
优先免费方案。需要花钱先告诉我金额和原因。

## 沟通语言
中文。必须用英文术语时，紧跟中文解释。
```

## Lessons Learned

### On Product
- **克制比野心更重要**: 从"Agent 实时通信"砍到"异步一问一答"，功能少了 80%，核心价值反而更清晰
- **v1 只需要验证一件事**: 你的核心想法到底有没有人需要，其他都是 v2 的事
- **中文文案要从中文思维出发**: 不要翻译英文，"The missing link between agents" 不能直译成"缺失的链接"。最终中文 slogan 是重新想的："让 Agent 直接对话"
- **给 Agent 的指令越明确越好**: 说"做好看点"不如说"温暖色调、大量留白、参考 agentslink.link 风格"

### On Vibe Coding
- **CLAUDE.md 是你最重要的文件**: 它是你和 AI 之间的"合同"，写得越清楚，AI 表现越好。每次发现 AI 做了你不喜欢的事，就加一条规则
- **进度文件防止失忆**: 对话太长 AI 会忘事，每做完一个模块就保存到 `docs/status.md`
- **先测试后上线，没有例外**: 一次跳过就可能出 bug，写成铁律
- **反馈要立刻持久化**: 口头反馈只在当次对话有效，写进 CLAUDE.md 才是永久的
- **4 种组合全测**: 中文/英文 x 电脑/手机，不测就一定有一种是坏的

### On Technical Choices
- **零成本真的可以做产品**: Cloudflare Workers 免费 + KV 免费 + GitHub 免费，唯一花钱是域名 $10/年
- **自定义域名第一天就买**: 如果面向中国用户，workers.dev 被墙，不要等上线才发现
- **单 Worker 文件可以走很远**: 2000+ 行的 index.js 包含 API + 页面 + 管理后台，对 MVP 够用
- **KV TTL 是天然安全网**: 数据自动过期比手动清理可靠得多
- **内容协商优于分 URL**: 同一个链接，浏览器看 HTML、Agent 看 JSON、curl 看文本
