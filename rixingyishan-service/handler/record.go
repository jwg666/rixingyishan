package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"rixingyishan-service/middleware"
	"rixingyishan-service/service"
)

// RecordHandler 记录 handler
type RecordHandler struct {
	Svc *service.RecordService
}

// NewRecordHandler 创建 RecordHandler
func NewRecordHandler(db *gorm.DB) *RecordHandler {
	return &RecordHandler{Svc: service.NewRecordService(db)}
}

// CreateRecord 创建记录
func (h *RecordHandler) CreateRecord(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		c.JSON(http.StatusUnauthorized, middleware.Response{
			Code:    40001,
			Message: "未认证",
			Data:    nil,
		})
		return
	}

	var req service.CreateRecordReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, middleware.Response{
			Code:    40001,
			Message: "参数错误: " + err.Error(),
			Data:    nil,
		})
		return
	}

	record, err := h.Svc.CreateRecord(userID, &req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, middleware.Response{
			Code:    40001,
			Message: "创建记录失败: " + err.Error(),
			Data:    nil,
		})
		return
	}

	c.JSON(http.StatusOK, middleware.Response{
		Code:    0,
		Message: "success",
		Data: gin.H{
			"serverRecordId": record.ID,
			"syncVersion":    record.SyncVersion,
			"record":         record,
		},
	})
}

// ListRecords 按天分页查询
func (h *RecordHandler) ListRecords(c *gin.Context) {
	userID := middleware.GetUserID(c)
	dayKey := c.Query("dayKey")
	if dayKey == "" {
		c.JSON(http.StatusBadRequest, middleware.Response{
			Code:    40001,
			Message: "dayKey 不能为空",
			Data:    nil,
		})
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	if page < 1 {
		page = 1
	}
	pageSize, _ := strconv.Atoi(c.DefaultQuery("pageSize", "20"))
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}

	records, total, err := h.Svc.ListRecordsByDay(userID, dayKey, page, pageSize)
	if err != nil {
		c.JSON(http.StatusInternalServerError, middleware.Response{
			Code:    40001,
			Message: "查询失败: " + err.Error(),
			Data:    nil,
		})
		return
	}

	c.JSON(http.StatusOK, middleware.Response{
		Code:    0,
		Message: "success",
		Data: service.ListRecordsResp{
			Records:  records,
			Total:    total,
			Page:     page,
			PageSize: pageSize,
		},
	})
}

// GetRecord 获取记录详情
func (h *RecordHandler) GetRecord(c *gin.Context) {
	userID := middleware.GetUserID(c)
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, middleware.Response{
			Code:    40001,
			Message: "id 错误",
			Data:    nil,
		})
		return
	}

	record, err := h.Svc.GetRecordByID(uint(id), userID)
	if err != nil {
		c.JSON(http.StatusNotFound, middleware.Response{
			Code:    40001,
			Message: "记录不存在",
			Data:    nil,
		})
		return
	}

	c.JSON(http.StatusOK, middleware.Response{
		Code:    0,
		Message: "success",
		Data:    record,
	})
}

// DeleteRecord 软删除记录
func (h *RecordHandler) DeleteRecord(c *gin.Context) {
	userID := middleware.GetUserID(c)
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, middleware.Response{
			Code:    40001,
			Message: "id 错误",
			Data:    nil,
		})
		return
	}

	if err := h.Svc.DeleteRecord(uint(id), userID); err != nil {
		c.JSON(http.StatusNotFound, middleware.Response{
			Code:    40001,
			Message: "记录不存在或删除失败",
			Data:    nil,
		})
		return
	}

	c.JSON(http.StatusOK, middleware.Response{
		Code:    0,
		Message: "success",
		Data:    nil,
	})
}

// GetDays 获取当月有记录的日期列表
func (h *RecordHandler) GetDays(c *gin.Context) {
	userID := middleware.GetUserID(c)
	month := c.Query("month")
	if month == "" {
		c.JSON(http.StatusBadRequest, middleware.Response{
			Code:    40001,
			Message: "month 不能为空",
			Data:    nil,
		})
		return
	}

	days, err := h.Svc.GetDaysByMonth(userID, month)
	if err != nil {
		c.JSON(http.StatusInternalServerError, middleware.Response{
			Code:    40001,
			Message: "查询失败",
			Data:    nil,
		})
		return
	}

	if days == nil {
		days = []string{}
	}

	c.JSON(http.StatusOK, middleware.Response{
		Code:    0,
		Message: "success",
		Data: service.DaysResp{
			Days: days,
		},
	})
}
