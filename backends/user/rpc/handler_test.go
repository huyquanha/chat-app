package main

import (
	"context"
	"path/filepath"
	"testing"

	"connectrpc.com/connect"

	"github.com/stretchr/testify/assert"

	"github.com/huyquanha/chat-app/backends/utils/testhelpers"
	userv1 "github.com/huyquanha/chat-app/protos/user/v1"
)

func TestCreateUser(t *testing.T) {
	pgContainer, err := testhelpers.CreatePostgresContainer(context.Background(), filepath.Join("..", "db", "schema.sql"))
	if err != nil {
		t.Fatalf("failed to create postgres container: %v", err)
	}
	defer pgContainer.Cleanup()

	userServer := newUserServer(pgContainer.Pool, pgContainer.Pool)

	res, err := userServer.CreateUser(context.Background(), &connect.Request[userv1.CreateUserRequest]{
		Msg: &userv1.CreateUserRequest{
			Username: "testuser",
		},
	})
	assert.NoError(t, err)
	assert.NotNil(t, res.Msg.Id)
}
