package handler

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"rixingyishan-service/middleware"
	"rixingyishan-service/model"
	"rixingyishan-service/service"
)

// MeritHandler 功德 handler
type MeritHandler struct {
	DB  *gorm.DB
	Svc *service.MeritService
}

// NewMeritHandler 创建 MeritHandler
func NewMeritHandler(db *gorm.DB) *MeritHandler {
	return &MeritHandler{DB: db, Svc: service.NewMeritService(db)}
}

// ListTags GET /api/merit/tags
func (h *MeritHandler) ListTags(c *gin.Context) {
	tags, err := h.Svc.ListEnabledTags()
	if err != nil {
		c.JSON(http.StatusInternalServerError, middleware.Response{
			Code: 40001, Message: "查询失败: " + err.Error(), Data: nil,
		})
		return
	}
	c.JSON(http.StatusOK, middleware.Response{
		Code:    0,
		Message: "success",
		Data: gin.H{
			"tags": tags,
		},
	})
}

// MatchTag POST /api/merit/match
func (h *MeritHandler) MatchTag(c *gin.Context) {
	var req struct {
		Content string `json:"content"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, middleware.Response{
			Code: 40001, Message: "参数错误", Data: nil,
		})
		return
	}

	tag, err := h.Svc.MatchTag(req.Content)
	if err != nil {
		c.JSON(http.StatusInternalServerError, middleware.Response{
			Code: 40001, Message: "匹配失败: " + err.Error(), Data: nil,
		})
		return
	}
	if tag == nil {
		c.JSON(http.StatusOK, middleware.Response{
			Code: 0, Message: "success",
			Data: gin.H{"tag": nil},
		})
		return
	}

	c.JSON(http.StatusOK, middleware.Response{
		Code:    0,
		Message: "success",
		Data: gin.H{
			"tag": gin.H{
				"id":         tag.ID,
				"name":       tag.Name,
				"icon":       tag.Icon,
				"meritValue": tag.MeritValue,
			},
		},
	})
}

// MyMerit GET /api/merit/my
func (h *MeritHandler) MyMerit(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		c.JSON(http.StatusUnauthorized, middleware.Response{
			Code: 40001, Message: "未认证", Data: nil,
		})
		return
	}

	var user model.User
	if err := h.DB.First(&user, userID).Error; err != nil {
		c.JSON(http.StatusNotFound, middleware.Response{
			Code: 40001, Message: "用户不存在", Data: nil,
		})
		return
	}

	// 计算当日功德
	today := time.Now().Format("2006-01-02")
	var dailyMerit int64
	h.DB.Model(&model.Record{}).
		Where("user_id = ? AND record_date = ?", userID, today).
		Select("COALESCE(SUM(merit_value), 0)").
		Scan(&dailyMerit)

	c.JSON(http.StatusOK, middleware.Response{
		Code:    0,
		Message: "success",
		Data: gin.H{
			"totalMerit": user.TotalMerit,
			"dailyMerit": int(dailyMerit),
		},
	})
}
