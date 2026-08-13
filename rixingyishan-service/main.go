package main

import (
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"rixingyishan-service/config"
	"rixingyishan-service/handler"
	"rixingyishan-service/middleware"
	"rixingyishan-service/model"
	"rixingyishan-service/service"
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
	if err := db.AutoMigrate(
		&model.User{},
		&model.Record{},
		&model.Media{},
		&model.MeritTag{},
		&model.RankingCache{},
	); err != nil {
		log.Fatalf("Failed to migrate: %v", err)
	}

	// 种子数据
	model.SeedMeritTags(db)

	// 初始化 Gin
	r := gin.Default()

	// CORS 中间件
	r.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS")
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
	meritHandler := handler.NewMeritHandler(db)
	rankingHandler := handler.NewRankingHandler(db)
	userHandler := handler.NewUserHandler(db)

	// API 路由组
	api := r.Group("/api")
	{
		// 健康检查（无需认证）
		api.GET("/health", func(c *gin.Context) {
			c.JSON(http.StatusOK, middleware.Response{
				Code:    0,
				Message: "success",
				Data: gin.H{
					"status":  "ok",
					"service": "rixingyishan-service",
					"time":    time.Now().Format(time.RFC3339),
				},
			})
		})

		// Auth 路由（无需认证）
		auth := api.Group("/auth")
		{
			sms := auth.Group("/sms")
			{
				sms.POST("/send", authHandler.SendSMS)
				sms.POST("/verify", authHandler.VerifySMS)
			}
			auth.POST("/refresh", authHandler.RefreshToken)
			auth.POST("/logout", authHandler.Logout)
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

		// Merit 功德路由
		merit := api.Group("/merit")
		{
			merit.GET("/tags", meritHandler.ListTags)
			merit.POST("/match", meritHandler.MatchTag)
			merit.GET("/my", middleware.AuthRequired(), meritHandler.MyMerit)
		}

		// Rankings 排行榜路由（可选认证：登录后能看到自己排名）
		rankings := api.Group("/rankings")
		rankings.Use(middleware.OptionalAuth())
		{
			rankings.GET("/total", rankingHandler.TotalRanking)
			rankings.GET("/daily", rankingHandler.DailyRanking)
		}

		// Users 用户路由（需要认证）
		users := api.Group("/users")
		users.Use(middleware.AuthRequired())
		{
			users.GET("/profile", userHandler.GetProfile)
			users.PATCH("/profile", userHandler.UpdateProfile)
		}
	}

	// 启动排行计算 goroutine
	rankingSvc := service.NewRankingService(db)
	go func() {
		// 启动时先算一次
		_ = rankingSvc.CalculateRankings("total")
		_ = rankingSvc.CalculateRankings("daily")
		log.Println("[Ranking] 初始排行计算完成")

		ticker := time.NewTicker(12 * time.Hour)
		defer ticker.Stop()
		for range ticker.C {
			_ = rankingSvc.CalculateRankings("total")
			_ = rankingSvc.CalculateRankings("daily")
			log.Println("[Ranking] 定时排行计算完成")
		}
	}()

	// 启动服务
	log.Printf("Server starting on %s", config.ServerPort)
	if err := r.Run(config.ServerPort); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
