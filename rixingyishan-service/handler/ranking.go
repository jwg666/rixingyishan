package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"rixingyishan-service/middleware"
	"rixingyishan-service/service"
)

// RankingHandler 排行 handler
type RankingHandler struct {
	Svc *service.RankingService
}

// NewRankingHandler 创建 RankingHandler
func NewRankingHandler(db *gorm.DB) *RankingHandler {
	return &RankingHandler{Svc: service.NewRankingService(db)}
}

// TotalRanking GET /api/rankings/total
func (h *RankingHandler) TotalRanking(c *gin.Context) {
	h.handleRanking(c, "total")
}

// DailyRanking GET /api/rankings/daily
func (h *RankingHandler) DailyRanking(c *gin.Context) {
	h.handleRanking(c, "daily")
}

func (h *RankingHandler) handleRanking(c *gin.Context, rankType string) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	if page < 1 {
		page = 1
	}
	pageSize, _ := strconv.Atoi(c.DefaultQuery("pageSize", "50"))
	if pageSize < 1 || pageSize > 100 {
		pageSize = 50
	}

	// 当前用户ID（可能未登录）
	currentUserID := middleware.GetUserID(c)

	result, err := h.Svc.GetRankings(rankType, page, pageSize, currentUserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, middleware.Response{
			Code: 40001, Message: "查询失败: " + err.Error(), Data: nil,
		})
		return
	}

	c.JSON(http.StatusOK, middleware.Response{
		Code:    0,
		Message: "success",
		Data:    result,
	})
}
