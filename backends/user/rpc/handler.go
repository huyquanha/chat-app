package main

import (
	"context"
	"errors"
	"fmt"

	"connectrpc.com/connect"
	"github.com/google/uuid"
	"github.com/jackc/pgerrcode"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/huyquanha/chat-app/backends/user/db"
	userv1 "github.com/huyquanha/chat-app/protos/user/v1"
)

type UserServer struct {
	dbRwPool, dbRoPool *pgxpool.Pool
}

func newUserServer(dbRwPool, dbRoPool *pgxpool.Pool) *UserServer {
	return &UserServer{
		dbRwPool: dbRwPool,
		dbRoPool: dbRoPool,
	}
}

func (s *UserServer) CreateUser(
	ctx context.Context,
	req *connect.Request[userv1.CreateUserRequest],
) (*connect.Response[userv1.CreateUserResponse], error) {
	q := db.New(s.dbRwPool)
	user, err := q.CreateUser(ctx, req.Msg.Username)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == pgerrcode.UniqueViolation {
			return nil, connect.NewError(connect.CodeAlreadyExists, fmt.Errorf("username already exists: %w", err))
		}
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("failed to create user: %w", err))
	}
	return &connect.Response[userv1.CreateUserResponse]{
		Msg: &userv1.CreateUserResponse{
			Id: user.ID.String(),
		},
	}, nil
}

func (s *UserServer) GetUser(
	ctx context.Context,
	req *connect.Request[userv1.GetUserRequest],
) (*connect.Response[userv1.GetUserResponse], error) {
	// use the read-only pool for this.
	q := db.New(s.dbRoPool)

	var user db.User
	switch v := req.Msg.Identifier.(type) {
	case *userv1.GetUserRequest_Id:
		id, err := uuid.Parse(v.Id)
		if err != nil {
			return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid user id: %w", err))
		}

		user, err = q.GetUserById(ctx, id)
		if err != nil {
			return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("failed to get user by id: %w", err))
		}

	case *userv1.GetUserRequest_Username:
		var err error
		user, err = q.GetUserByUsername(ctx, v.Username)
		if err != nil {
			return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("failed to get user by username: %w", err))
		}
	}

	return &connect.Response[userv1.GetUserResponse]{
		Msg: &userv1.GetUserResponse{
			Id:       user.ID.String(),
			Username: user.Username,
		},
	}, nil
}

func (s *UserServer) DeleteUser(
	ctx context.Context,
	req *connect.Request[userv1.DeleteUserRequest],
) (*connect.Response[userv1.DeleteUserResponse], error) {
	id, err := uuid.Parse(req.Msg.Id)
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid user id: %w", err))
	}

	q := db.New(s.dbRwPool)
	err = q.DeleteUser(ctx, id)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("failed to delete user: %w", err))
	}

	return &connect.Response[userv1.DeleteUserResponse]{}, nil
}
