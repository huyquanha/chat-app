package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"connectrpc.com/connect"
	"connectrpc.com/validate"

	"github.com/huyquanha/chat-app/backends/utils/postgres"
	userv1 "github.com/huyquanha/chat-app/protos/user/v1"
)

const (
	rwDbHost = "user-db-rw.user.svc"
	roDbHost = "user-db-ro.user.svc"
	dbName   = "user"
	dbPort   = 5432
)

func main() {
	if err := run(); err != nil {
		slog.Error("fatal error", "error", err)
		os.Exit(1)
	}
}

func run() error {
	verbose := flag.Bool("verbose", false, "Enable debug logging")
	flag.Parse()

	level := slog.LevelInfo
	if *verbose {
		level = slog.LevelDebug
	}
	logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
		Level: level,
	}))
	slog.SetDefault(logger)

	dbRwPool, err := postgres.CreateDatabasePool(rwDbHost, dbPort, dbName)
	if err != nil {
		return fmt.Errorf("failed to create read-write database pool: %w", err)
	}
	slog.Info("read-write database pool created", "host", rwDbHost)
	defer dbRwPool.Close()

	dbRoPool, err := postgres.CreateDatabasePool(roDbHost, dbPort, dbName)
	if err != nil {
		return fmt.Errorf("failed to create read-only database pool: %w", err)
	}
	slog.Info("read-only database pool created", "host", roDbHost)
	defer dbRoPool.Close()

	userServer := newUserServer(dbRwPool, dbRoPool)

	mux := http.NewServeMux()
	compress1KB := connect.WithCompressMinBytes(1024)
	path, handler := userv1.NewUserServiceHandler(
		userServer,
		connect.WithInterceptors(validate.NewInterceptor()),
		compress1KB,
	)
	mux.Handle(path, handler)
	p := new(http.Protocols)
	p.SetHTTP1(true)
	// h2c is necessary so we can serve HTTP/2 without TLS. Without it,
	// HTTP/2 can only be negotiated using ALPN during the TLS handshake,
	// forcing us to support TLS as well.
	p.SetUnencryptedHTTP2(true)

	s := http.Server{
		Addr:              "localhost:8080",
		Handler:           mux,
		Protocols:         p,
		ReadHeaderTimeout: 1 * time.Second,
		ReadTimeout:       5 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       time.Minute,
		MaxHeaderBytes:    8 * 1024, // 8KiB
	}
	signals := make(chan os.Signal, 1)
	signal.Notify(signals, os.Interrupt, syscall.SIGTERM)
	go func() {
		if err := s.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("HTTP listen and serve: %v", err)
		}
	}()

	<-signals
	// Give it 10s to shutdown, which matches the WriteTimeout setting to ensure
	// on-going requests are completed.
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := s.Shutdown(ctx); err != nil {
		return fmt.Errorf("HTTP server shutdown: %w", err)
	}
	return nil
}
