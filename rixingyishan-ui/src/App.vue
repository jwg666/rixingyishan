<script setup lang="ts">
import { onLaunch, onShow, onHide } from "@dcloudio/uni-app";
import { UploadQueueService } from "@/services/UploadQueueService";
import { AuthService } from "@/services/AuthService";

onLaunch(() => {
  console.log("App Launch");

  // 检查 token 有效性（不强制登录）
  if (AuthService.isLoggedIn()) {
    console.log("用户已登录:", AuthService.getUserPhone());
  } else {
    console.log("用户未登录，可延迟登录");
  }

  UploadQueueService.recoverPendingTasks();
});

onShow(() => {
  console.log("App Show");
  UploadQueueService.recoverPendingTasks();
});

onHide(() => {
  console.log("App Hide");
});
</script>
<style>
/* 全局暖色调基础样式 */
page {
  background-color: #FFF8F0;
  color: #333333;
  font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", Helvetica, "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", Arial, sans-serif;
}
</style>
