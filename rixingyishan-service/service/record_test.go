package service

import (
	"errors"
	"testing"

	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
	"rixingyishan-service/model"
)

func newTestDB(t *testing.T) *gorm.DB {
	t.Helper()
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	if err := db.AutoMigrate(&model.User{}, &model.Record{}, &model.Media{}, &model.MeritTag{}, &model.RankingCache{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	model.SeedMeritTags(db)
	return db
}

func newTestUser(t *testing.T, db *gorm.DB) *model.User {
	t.Helper()
	u := &model.User{Phone: "13800000000", Nickname: "tester"}
	if err := db.Create(u).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}
	return u
}

func totalMeritOf(t *testing.T, db *gorm.DB, userID uint) int {
	t.Helper()
	var u model.User
	if err := db.First(&u, userID).Error; err != nil {
		t.Fatalf("load user: %v", err)
	}
	return u.TotalMerit
}

// SVC-4：meritValue 由服务端按 tag 配置计分，未知 tag 归一化为「其他善行」
func TestCreateRecordMeritServerAuthoritative(t *testing.T) {
	db := newTestDB(t)
	svc := NewRecordService(db)
	u := newTestUser(t, db)

	rec, err := svc.CreateRecord(u.ID, &CreateRecordReq{
		Type: "text", Content: "喂了流浪猫", Tag: "关爱动物", RecordDate: "2026-09-11",
	})
	if err != nil {
		t.Fatalf("create record: %v", err)
	}
	if rec.MeritValue != 10 { // 种子配置：关爱动物 = 10
		t.Errorf("meritValue = %d, want 10", rec.MeritValue)
	}
	if got := totalMeritOf(t, db, u.ID); got != 10 {
		t.Errorf("user totalMerit = %d, want 10", got)
	}

	// 未知 tag：落「其他善行」= 5
	rec2, err := svc.CreateRecord(u.ID, &CreateRecordReq{
		Type: "text", Content: "随手做的善事", Tag: "随手编的", RecordDate: "2026-09-11",
	})
	if err != nil {
		t.Fatalf("create record2: %v", err)
	}
	if rec2.Tag != "其他善行" || rec2.MeritValue != 5 {
		t.Errorf("unknown tag → tag=%q merit=%d, want 其他善行/5", rec2.Tag, rec2.MeritValue)
	}
	if got := totalMeritOf(t, db, u.ID); got != 15 {
		t.Errorf("user totalMerit = %d, want 15", got)
	}
}

// SVC-1：LWW 更新，版本落后返回冲突并携带服务端当前记录
func TestUpdateRecordLWW(t *testing.T) {
	db := newTestDB(t)
	svc := NewRecordService(db)
	u := newTestUser(t, db)

	rec, err := svc.CreateRecord(u.ID, &CreateRecordReq{
		Type: "text", Content: "喂了流浪猫", Tag: "关爱动物", RecordDate: "2026-09-11",
		Media: []MediaInput{{ObjectKey: "uploads/2026/09/11/a.jpg", RemoteUrl: "http://x/a.jpg", MimeType: "image/jpeg", Size: 1}},
	})
	if err != nil {
		t.Fatalf("create record: %v", err)
	}

	// 携带当前版本（1）→ 成功，版本递增到 2，media 全量替换
	upd, err := svc.UpdateRecord(rec.ID, u.ID, &UpdateRecordReq{
		SyncVersion: 1, Content: "喂了两只流浪猫", Tag: "关爱动物",
		Media: []MediaInput{
			{ObjectKey: "uploads/2026/09/11/b.jpg", RemoteUrl: "http://x/b.jpg", MimeType: "image/jpeg", Size: 2},
			{ObjectKey: "uploads/2026/09/11/c.jpg", RemoteUrl: "http://x/c.jpg", MimeType: "image/jpeg", Size: 3},
		},
	})
	if err != nil {
		t.Fatalf("update record: %v", err)
	}
	if upd.SyncVersion != 2 || upd.Content != "喂了两只流浪猫" {
		t.Errorf("syncVersion=%d content=%q, want 2/喂了两只流浪猫", upd.SyncVersion, upd.Content)
	}
	if len(upd.Media) != 2 || upd.Media[0].ObjectKey != "uploads/2026/09/11/b.jpg" {
		t.Errorf("media not replaced: %+v", upd.Media)
	}

	// 旧版本（1 < 2）→ 冲突，携带服务端当前记录
	_, err = svc.UpdateRecord(rec.ID, u.ID, &UpdateRecordReq{
		SyncVersion: 1, Content: "stale", Tag: "关爱动物",
	})
	var conflict *ErrSyncConflict
	if !errors.As(err, &conflict) {
		t.Fatalf("want ErrSyncConflict, got %v", err)
	}
	if conflict.Current.SyncVersion != 2 || conflict.Current.Content != "喂了两只流浪猫" {
		t.Errorf("conflict current version=%d content=%q, want 2/喂了两只流浪猫",
			conflict.Current.SyncVersion, conflict.Current.Content)
	}

	// 未携带版本 → 视为强制更新
	forced, err := svc.UpdateRecord(rec.ID, u.ID, &UpdateRecordReq{Content: "force", Tag: "关爱动物"})
	if err != nil {
		t.Fatalf("force update: %v", err)
	}
	if forced.SyncVersion != 3 {
		t.Errorf("forced syncVersion = %d, want 3", forced.SyncVersion)
	}
}

// SVC-1/SVC-4：更新换 tag 时功德按差额落账
func TestUpdateRecordMeritDelta(t *testing.T) {
	db := newTestDB(t)
	svc := NewRecordService(db)
	u := newTestUser(t, db)

	rec, err := svc.CreateRecord(u.ID, &CreateRecordReq{
		Type: "text", Content: "捡垃圾", Tag: "环保行动", RecordDate: "2026-09-11",
	})
	if err != nil {
		t.Fatalf("create record: %v", err)
	}
	if got := totalMeritOf(t, db, u.ID); got != 8 {
		t.Fatalf("after create totalMerit = %d, want 8", got)
	}

	if _, err := svc.UpdateRecord(rec.ID, u.ID, &UpdateRecordReq{
		SyncVersion: 1, Content: "捡垃圾", Tag: "捐赠善举", // 20 分
	}); err != nil {
		t.Fatalf("update record: %v", err)
	}
	if got := totalMeritOf(t, db, u.ID); got != 20 {
		t.Errorf("after upgrade totalMerit = %d, want 20", got)
	}

	if _, err := svc.UpdateRecord(rec.ID, u.ID, &UpdateRecordReq{
		SyncVersion: 2, Content: "捡垃圾", Tag: "其他善行", // 5 分
	}); err != nil {
		t.Fatalf("downgrade record: %v", err)
	}
	if got := totalMeritOf(t, db, u.ID); got != 5 {
		t.Errorf("after downgrade totalMerit = %d, want 5", got)
	}
}

// SVC-3：软删除在同一事务内扣回功德；重复删除不重复扣
func TestDeleteRecordDecrementsMerit(t *testing.T) {
	db := newTestDB(t)
	svc := NewRecordService(db)
	u := newTestUser(t, db)

	rec, err := svc.CreateRecord(u.ID, &CreateRecordReq{
		Type: "text", Content: "让座", Tag: "帮助他人", RecordDate: "2026-09-11",
	})
	if err != nil {
		t.Fatalf("create record: %v", err)
	}
	if got := totalMeritOf(t, db, u.ID); got != 10 {
		t.Fatalf("after create totalMerit = %d, want 10", got)
	}

	if err := svc.DeleteRecord(rec.ID, u.ID); err != nil {
		t.Fatalf("delete record: %v", err)
	}
	if got := totalMeritOf(t, db, u.ID); got != 0 {
		t.Errorf("after delete totalMerit = %d, want 0", got)
	}
	if _, err := svc.GetRecordByID(rec.ID, u.ID); !errors.Is(err, gorm.ErrRecordNotFound) {
		t.Errorf("deleted record should be gone, got %v", err)
	}

	// 重复删除：NotFound，功德不变
	if err := svc.DeleteRecord(rec.ID, u.ID); !errors.Is(err, gorm.ErrRecordNotFound) {
		t.Errorf("second delete should be NotFound, got %v", err)
	}
	if got := totalMeritOf(t, db, u.ID); got != 0 {
		t.Errorf("totalMerit changed after duplicate delete: %d", got)
	}
}

// SVC-3：只能删自己的记录
func TestDeleteRecordIsolatedByUser(t *testing.T) {
	db := newTestDB(t)
	svc := NewRecordService(db)
	u1 := newTestUser(t, db)
	u2 := &model.User{Phone: "13900000000", Nickname: "other"}
	db.Create(u2)

	rec, err := svc.CreateRecord(u1.ID, &CreateRecordReq{
		Type: "text", Content: "指路", Tag: "帮助他人", RecordDate: "2026-09-11",
	})
	if err != nil {
		t.Fatalf("create record: %v", err)
	}
	if err := svc.DeleteRecord(rec.ID, u2.ID); !errors.Is(err, gorm.ErrRecordNotFound) {
		t.Errorf("delete other user's record should be NotFound, got %v", err)
	}
	if got := totalMeritOf(t, db, u1.ID); got != 10 {
		t.Errorf("owner totalMerit = %d, want 10", got)
	}
}

func TestGetDaysByMonth(t *testing.T) {
	db := newTestDB(t)
	svc := NewRecordService(db)
	u := newTestUser(t, db)

	for _, day := range []string{"2026-09-01", "2026-09-02", "2026-08-31"} {
		if _, err := svc.CreateRecord(u.ID, &CreateRecordReq{
			Type: "text", Content: "x", Tag: "帮助他人", RecordDate: day,
		}); err != nil {
			t.Fatalf("create record on %s: %v", day, err)
		}
	}

	days, err := svc.GetDaysByMonth(u.ID, "2026-09")
	if err != nil {
		t.Fatalf("get days: %v", err)
	}
	if len(days) != 2 || days[0] != "2026-09-02" || days[1] != "2026-09-01" {
		t.Errorf("days = %v, want [2026-09-02 2026-09-01]", days)
	}
}
