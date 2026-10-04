package migrations

import (
	"io/fs"
	"testing"
)

func TestFS(t *testing.T) {
	content, err := fs.ReadFile(FS, "0001_init.sql")
	if err != nil {
		t.Fatalf("expected 0001_init.sql to be present in FS, got error: %v", err)
	}
	if len(content) == 0 {
		t.Fatal("expected 0001_init.sql content to be non-empty")
	}
}
