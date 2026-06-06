package store

import (
	"context"
	"testing"
)

func TestMemoryStoreAppleSubUnique(t *testing.T) {
	users := NewMemoryStore()
	ctx := context.Background()

	in := CreateUserInput{
		ID:       "usr_test1",
		AppleSub: "dup-sub",
		Region:   "cn",
		Nickname: "u1",
	}
	if _, err := users.CreateUser(ctx, in); err != nil {
		t.Fatal(err)
	}

	in.ID = "usr_test2"
	if _, err := users.CreateUser(ctx, in); err == nil {
		t.Fatal("expected duplicate apple_sub error")
	} else if err != ErrDuplicateAppleSub {
		t.Fatalf("err = %v, want ErrDuplicateAppleSub", err)
	}
}

func TestMemoryStoreFindByAppleSub(t *testing.T) {
	users := NewMemoryStore()
	ctx := context.Background()

	created, err := users.CreateUser(ctx, CreateUserInput{
		ID:       "usr_find",
		AppleSub: "find-me",
		Region:   "os",
		Nickname: "finder",
	})
	if err != nil {
		t.Fatal(err)
	}

	found, err := users.FindByAppleSub(ctx, "find-me")
	if err != nil {
		t.Fatal(err)
	}
	if found.ID != created.ID {
		t.Fatalf("id = %s, want %s", found.ID, created.ID)
	}
}
