# MVP 范围与数据模型

## MVP 目标
在 2-4 周内交付“可用闭环”：
- 创建记录（拍照 / 视频 / 文字）
- 本地保存草稿并展示在当天列表
- 联网后上传媒体并同步状态
- 查看历史记录与详情

## 非目标（MVP 不做）
- 社区广场、评论、点赞、关注
- 复杂搜索（全文检索、多维筛选）
- 多媒体高级编辑

## 信息架构
- `首页（日历+当天列表）`
- `新建记录（photo/video/text）`
- `记录详情`
- `设置`

## 记录实体定义
```ts
type RecordType = "photo" | "video" | "text";
type SyncStatus = "draft" | "queued" | "uploading" | "synced" | "failed";

interface MediaItem {
  localPath?: string;
  remoteUrl?: string;
  mimeType: string;
  width?: number;
  height?: number;
  durationMs?: number;
  sizeBytes?: number;
  checksum?: string;
}

interface GoodDeedRecord {
  id: string;
  userId?: string;
  type: RecordType;
  title?: string;
  content: string;
  media: MediaItem[];
  dayKey: string; // yyyy-mm-dd
  createdAt: string; // ISO8601
  updatedAt: string; // ISO8601
  status: SyncStatus;
  failReason?: string;
  tags?: string[];
  location?: {
    name?: string;
    lat?: number;
    lng?: number;
  };
}
```

## 状态流转
- 新建成功：`draft`
- 触发上传：`queued -> uploading`
- 上传成功：`synced`
- 上传失败：`failed`（保留失败原因，可重试回到 `queued`）

## 页面级最小交互
- 首页：按 `dayKey` 聚合，默认显示今天
- 新建页：一次只创建一条记录，媒体可删可重选
- 详情页：显示同步状态，`failed` 时提供“重试上传”
- 设置页：提供“仅 Wi-Fi 上传”开关（默认关闭）

## 数据存储策略
- 本地：记录元数据 + 媒体本地路径
- 云端（可选）：记录元数据 + 媒体远端 URL
