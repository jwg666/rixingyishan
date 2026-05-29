package main

import (
	"log"
	"os"

	"github.com/gin-gonic/gin"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"rixingyishan-service/config"
	"rixingyishan-service/handler"
	"rixingyishan-service/middleware"
	"rixingyishan-service/model"
)

func main() {
	// 确保目录存在
	os.MkdirAll("data", 0755)
	os.MkdirAll(config.UploadDir, 0755)

	// 初始化数据库
	db, err := gorm.Open(sqlite.Open(config.DBPath), &gorm.Config{})
	if err != nil {
		log.Fatalf("Failed to connect database: %v", err)
	}

	// 自动迁移
	if err := db.AutoMigrate(&model.User{}, &model.Record{}, &model.Media{}); err != nil {
		log.Fatalf("Failed to migrate: %v", err)
	}

	// 初始化 Gin
	r := gin.Default()

	// CORS 中间件
	r.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin,Content-Type,Authorization,Accept")
		c.Header("Access-Control-Max-Age", "86400")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})

	// 静态文件服务
	r.Static(config.UploadURLPrefix, config.UploadDir)

	// 初始化 handlers
	authHandler := handler.NewAuthHandler(db)
	uploadHandler := handler.NewUploadHandler()
	recordHandler := handler.NewRecordHandler(db)

	// API 路由组
	api := r.Group("/api")
	{
		// Auth 路由（无需认证）
		auth := api.Group("/auth")
		{
			sms := auth.Group("/sms")
			{
				sms.POST("/send", authHandler.SendSMS)
				sms.POST("/verify", authHandler.VerifySMS)
			}
			auth.POST("/refresh", authHandler.RefreshToken)
		}

		// Upload 路由（无需认证，MVP 阶段）
		upload := api.Group("/upload")
		{
			upload.POST("/policy", uploadHandler.GetUploadPolicy)
			upload.POST("/file", uploadHandler.UploadFile)
		}

		// Records 路由（需要认证）
		records := api.Group("/records")
		records.Use(middleware.AuthRequired())
		{
			records.POST("", recordHandler.CreateRecord)
			records.GET("", recordHandler.ListRecords)
			records.GET("/days", recordHandler.GetDays)
			records.GET("/:id", recordHandler.GetRecord)
			records.DELETE("/:id", recordHandler.DeleteRecord)
		}
	}

	// 启动服务
	log.Printf("Server starting on %s", config.ServerPort)
	if err := r.Run(config.ServerPort); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
