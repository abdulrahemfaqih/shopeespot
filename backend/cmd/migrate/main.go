package main

import (
	"context"
	"database/sql"
	"flag"
	"log"
	"strings"

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"

	"github.com/abdulrahemfaqih/shopeespot/internal/config"
	"github.com/abdulrahemfaqih/shopeespot/migrations"
)

func main() {
	flag.Parse()
	args := flag.Args()

	command := "up"
	var cmdArgs []string
	if len(args) > 0 {
		command = args[0]
		cmdArgs = args[1:]
	}

	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	dbURL := cfg.DatabaseURLDirect
	if dbURL == "" || strings.Contains(dbURL, "<user>") {
		dbURL = cfg.DatabaseURL
		// If pooled connection string was provided, strip -pooler to connect directly for migrations
		dbURL = strings.Replace(dbURL, "-pooler.", ".", 1)
	}

	if dbURL == "" {
		log.Fatal("database direct connection URL is required (DATABASE_URL_DIRECT or DATABASE_URL)")
	}

	db, err := sql.Open("pgx", dbURL)
	if err != nil {
		log.Fatalf("failed to open database connection: %v", err)
	}
	defer db.Close()

	if err := goose.SetDialect("postgres"); err != nil {
		log.Fatalf("failed to set goose dialect: %v", err)
	}

	goose.SetBaseFS(migrations.FS)

	ctx := context.Background()
	log.Printf("running migration command: %s (args: %v)", command, cmdArgs)
	if err := goose.RunContext(ctx, command, db, ".", cmdArgs...); err != nil {
		log.Fatalf("migration failed: %v", err)
	}
	log.Println("migration completed successfully")
}
