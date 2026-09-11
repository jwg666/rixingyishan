package handler

import "testing"

func TestValidateUploadMeta(t *testing.T) {
	cases := []struct {
		name     string
		mimeType string
		filename string
		size     int64
		wantOK   bool
	}{
		{"jpeg ok", "image/jpeg", "a.jpg", 1024, true},
		{"jpeg with .jpeg ext", "image/jpeg", "a.jpeg", 1024, true},
		{"ext case-insensitive", "image/jpeg", "A.JPG", 1024, true},
		{"png at limit", "image/png", "a.png", 10 << 20, true},
		{"png over limit", "image/png", "a.png", 10<<20 + 1, false},
		{"webp ok", "image/webp", "a.webp", 1024, true},
		{"image over video limit rejected", "image/png", "a.png", 20 << 20, false},
		{"mp4 at limit", "video/mp4", "a.mp4", 50 << 20, true},
		{"mp4 over limit", "video/mp4", "a.mp4", 50<<20 + 1, false},
		{"ext mismatch mime", "image/jpeg", "a.png", 1024, false},
		{"no extension", "image/jpeg", "a", 1024, false},
		{"unsupported mime", "application/octet-stream", "a.exe", 1, false},
		{"gif rejected", "image/gif", "a.gif", 1024, false},
		{"zero size", "image/jpeg", "a.jpg", 0, false},
		{"negative size", "image/jpeg", "a.jpg", -1, false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := validateUploadMeta(c.mimeType, c.filename, c.size)
			if (got == "") != c.wantOK {
				t.Errorf("validateUploadMeta(%q, %q, %d) = %q, wantOK=%v",
					c.mimeType, c.filename, c.size, got, c.wantOK)
			}
		})
	}
}
