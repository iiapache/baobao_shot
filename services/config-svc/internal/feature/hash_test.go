package feature

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestUserIDHashGoldenVectors(t *testing.T) {
	root := filepath.Join("..", "..", "..", "..", "infra", "feature-flags", "golden_hashes.json")
	data, err := os.ReadFile(root)
	if err != nil {
		t.Skip("golden_hashes.json not found:", err)
	}

	var golden struct {
		Vectors []struct {
			UserID string `json:"userId"`
			Hash   int    `json:"hash"`
		} `json:"vectors"`
	}
	if err := json.Unmarshal(data, &golden); err != nil {
		t.Fatal(err)
	}

	for _, v := range golden.Vectors {
		got := UserIDHash(v.UserID)
		if got != v.Hash {
			t.Fatalf("UserIDHash(%q) = %d, want %d", v.UserID, got, v.Hash)
		}
	}
}
