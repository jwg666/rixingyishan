package handler

import (
	"net/http"
	"regexp"
	"strings"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"rixingyishan-service/middleware"
	"rixingyishan-service/model"
)

// UserHandler 用户 handler
type UserHandler struct {
	DB *gorm.DB
}

// NewUserHandler 创建 UserHandler
func NewUserHandler(db *gorm.DB) *UserHandler {
	return &UserHandler{DB: db}
}

// 仅允许中英文/数字/常见空格
var nicknameRe = regexp.MustCompile(`^[\p{Han}A-Za-z0-9_\- ]{2,30}$`)

// GetProfile GET /api/users/profile
func (h *UserHandler) GetProfile(c *gin.Context) {
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

	c.JSON(http.StatusOK, middleware.Response{
		Code:    0,
		Message: "success",
		Data: gin.H{
			"id":            user.ID,
			"phone":         maskPhone(user.Phone),
			"nickname":      user.Nickname,
			"avatarSeed":    user.AvatarSeed,
			"totalMerit":    user.TotalMerit,
			"showInRanking": user.ShowInRanking,
		},
	})
}

// UpdateProfile PATCH /api/users/profile
func (h *UserHandler) UpdateProfile(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		c.JSON(http.StatusUnauthorized, middleware.Response{
			Code: 40001, Message: "未认证", Data: nil,
		})
		return
	}

	var req struct {
		Nickname      *string `json:"nickname"`
		ShowInRanking *bool   `json:"showInRanking"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, middleware.Response{
			Code: 40001, Message: "参数错误", Data: nil,
		})
		return
	}

	updates := map[string]interface{}{}
	if req.Nickname != nil {
		nickname := strings.TrimSpace(*req.Nickname)
		if !nicknameRe.MatchString(nickname) {
			c.JSON(http.StatusBadRequest, middleware.Response{
				Code: 40001, Message: "昵称需为2-30字符，不可包含特殊符号", Data: nil,
			})
			return
		}
		updates["nickname"] = nickname
	}
	if req.ShowInRanking != nil {
		updates["show_in_ranking"] = *req.ShowInRanking
	}

	if len(updates) == 0 {
		c.JSON(http.StatusBadRequest, middleware.Response{
			Code: 40001, Message: "无可更新字段", Data: nil,
		})
		return
	}

	if err := h.DB.Model(&model.User{}).Where("id = ?", userID).Updates(updates).Error; err != nil {
		c.JSON(http.StatusInternalServerError, middleware.Response{
			Code: 40001, Message: "更新失败", Data: nil,
		})
		return
	}

	var user model.User
	h.DB.First(&user, userID)

	c.JSON(http.StatusOK, middleware.Response{
		Code:    0,
		Message: "success",
		Data: gin.H{
			"id":            user.ID,
			"phone":         maskPhone(user.Phone),
			"nickname":      user.Nickname,
			"avatarSeed":    user.AvatarSeed,
			"totalMerit":    user.TotalMerit,
			"showInRanking": user.ShowInRanking,
		},
	})
}

// maskPhone 手机号脱敏: 138****8000
func maskPhone(phone string) string {
	if len(phone) < 11 {
		return phone
	}
	return phone[:3] + "****" + phone[len(phone)-4:]
}
