package handler

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"rixingyishan-service/config"
	"rixingyishan-service/middleware"
)

// UploadHandler 上传 handler
type UploadHandler struct{}

// NewUploadHandler 创建 UploadHandler
func NewUploadHandler() *UploadHandler {
	return &UploadHandler{}
}

// 上传白名单与大小上限（对齐客户端 MediaValidationService：图片 10MB、视频 50MB）
var allowedMimeExts = map[string][]string{
	"image/jpeg": {".jpg", ".jpeg"},
	"image/png":  {".png"},
	"image/webp": {".webp"},
	"video/mp4":  {".mp4"},
}

const (
	maxImageSize = 10 * 1024 * 1024
	maxVideoSize = 50 * 1024 * 1024
)

// validateUploadMeta 校验 mime/扩展名/大小，返回错误信息；空串表示通过
func validateUploadMeta(mimeType, filename string, size int64) string {
	exts, ok := allowedMimeExts[strings.ToLower(mimeType)]
	if !ok {
		return "不支持的文件类型"
	}
	ext := strings.ToLower(filepath.Ext(filename))
	matched := false
	for _, e := range exts {
		if ext == e {
			matched = true
			break
		}
	}
	if !matched {
		return "文件扩展名与类型不符"
	}
	if size <= 0 {
		return "文件大小无效"
	}
	limit := int64(maxImageSize)
	if strings.HasPrefix(strings.ToLower(mimeType), "video/") {
		limit = maxVideoSize
	}
	if size > limit {
		return "文件超过大小限制"
	}
	return ""
}

// GetUploadPolicy 获取上传凭证
func (h *UploadHandler) GetUploadPolicy(c *gin.Context) {
	var req struct {
		Filename string `json:"filename" binding:"required"`
		MimeType string `json:"mimeType" binding:"required"`
		Size     int64  `json:"size" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, middleware.Response{
			Code:    40001,
			Message: "参数不完整",
			Data:    nil,
		})
		return
	}

	if msg := validateUploadMeta(req.MimeType, req.Filename, req.Size); msg != "" {
		c.JSON(http.StatusBadRequest, middleware.Response{
			Code:    40001,
			Message: msg,
			Data:    nil,
		})
		return
	}

	objectKey := buildObjectKey(req.Filename)
	remoteURL := config.BaseURL + "/" + objectKey

	c.JSON(http.StatusOK, middleware.Response{
		Code:    0,
		Message: "success",
		Data: gin.H{
			"uploadUrl":  config.BaseURL + "/api/upload/file",
			"objectKey": objectKey,
			"remoteUrl": remoteURL,
		},
	})
}

// UploadFile 上传文件
func (h *UploadHandler) UploadFile(c *gin.Context) {
	file, header, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, middleware.Response{
			Code:    40001,
			Message: "请上传文件",
			Data:    nil,
		})
		return
	}
	defer file.Close()

	// 内容类型取 multipart part 声明值，校验白名单/扩展名/大小
	mimeType := header.Header.Get("Content-Type")
	if msg := validateUploadMeta(mimeType, header.Filename, header.Size); msg != "" {
		c.JSON(http.StatusBadRequest, middleware.Response{
			Code:    40001,
			Message: msg,
			Data:    nil,
		})
		return
	}

	objectKey := buildObjectKey(header.Filename)
	fullPath := filepath.Join(config.UploadDir, objectKey)

	// 确保目录存在
	dir := filepath.Dir(fullPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		c.JSON(http.StatusInternalServerError, middleware.Response{
			Code:    40001,
			Message: "创建目录失败",
			Data:    nil,
		})
		return
	}

	dst, err := os.Create(fullPath)
	if err != nil {
		c.JSON(http.StatusInternalServerError, middleware.Response{
			Code:    40001,
			Message: "创建文件失败",
			Data:    nil,
		})
		return
	}
	defer dst.Close()

	if _, err := io.Copy(dst, file); err != nil {
		c.JSON(http.StatusInternalServerError, middleware.Response{
			Code:    40001,
			Message: "保存文件失败",
			Data:    nil,
		})
		return
	}

	remoteURL := config.BaseURL + "/" + objectKey

	c.JSON(http.StatusOK, middleware.Response{
		Code:    0,
		Message: "success",
		Data: gin.H{
			"objectKey": objectKey,
			"remoteUrl": remoteURL,
		},
	})
}

// buildObjectKey 构建对象存储路径
func buildObjectKey(filename string) string {
	now := time.Now()
	ext := filepath.Ext(filename)
	if ext == "" {
		ext = ".bin"
	}
	uid := uuid.New().String()
	objectKey := fmt.Sprintf("uploads/%s/%s/%s/%s",
		now.Format("2006"),
		now.Format("01"),
		now.Format("02"),
		uid+ext,
	)
	return objectKey
}
