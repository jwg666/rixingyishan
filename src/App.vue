<script setup lang="ts">
import { onLaunch, onShow, onHide } from "@dcloudio/uni-app";
import { UploadQueueService } from "@/services/UploadQueueService";

onLaunch(() => {
  console.log("App Launch");
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
<style></style>
