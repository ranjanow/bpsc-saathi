package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"bpsc-engine/handlers"
	"bpsc-engine/repositories"
	"bpsc-engine/services"
)

func main() {
	// ── Background context for long-lived SDK clients ─────────────────────────
	ctx := context.Background()

	// ── Server port ───────────────────────────────────────────────────────────
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// ─────────────────────────────────────────────────────────────────────────
	// JWT SECRET — required for authentication
	// ─────────────────────────────────────────────────────────────────────────
	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		jwtSecret = "bpsc-saathi-dev-secret-change-in-production"
		log.Println("[Auth] ⚠️  JWT_SECRET not set — using default dev secret. SET THIS IN PRODUCTION!")
	}

	// ─────────────────────────────────────────────────────────────────────────
	// DATABASE — PostgreSQL connection pool
	// ─────────────────────────────────────────────────────────────────────────
	connString := os.Getenv("DATABASE_URL")
	if connString == "" {
		// Fallback for local development outside of Docker
		dbCfg := DefaultDBConfig()
		if pw := os.Getenv("BPSC_DB_PASSWORD"); pw != "" {
			dbCfg.Password = pw
		}
		connString = dbCfg.dsn()
	}

	var repo *repositories.EcosystemRepository
	var bookmarkRepo *repositories.PostgresBookmarkRepository
	var userRepo *repositories.UserRepository
	var analyticsRepo *repositories.AnalyticsRepository
	var featuresRepo *repositories.FeaturesRepository
	if err := InitDB(connString); err != nil {
		log.Printf("[DB] ⚠️  Database connection failed (running in degraded mode): %v", err)
	} else {
		defer CloseDB()
		repo = repositories.NewEcosystemRepository(DB)
		bookmarkRepo = repositories.NewPostgresBookmarkRepository(DB)
		userRepo = repositories.NewUserRepository(DB)
		analyticsRepo = repositories.NewAnalyticsRepository(DB)
		featuresRepo = repositories.NewFeaturesRepository(DB)

		// Run migrations
		if err := userRepo.RunAuthMigration(); err != nil {
			log.Printf("[DB] ⚠️  Auth migration warning: %v", err)
		}
		if err := analyticsRepo.RunMigration(); err != nil {
			log.Printf("[DB] ⚠️  Analytics migration warning: %v", err)
		}
		if err := featuresRepo.RunMigration(); err != nil {
			log.Printf("[DB] ⚠️  Features migration warning: %v", err)
		}

		log.Println("[DB] ✅ All repositories ready")
	}

	// ─────────────────────────────────────────────────────────────────────────
	// AUTH SERVICE
	// ─────────────────────────────────────────────────────────────────────────
	var authService *services.AuthService
	if userRepo != nil {
		authService = services.NewAuthService(jwtSecret, userRepo)
		log.Println("[Auth] ✅ AuthService initialized")
	}

	// ─────────────────────────────────────────────────────────────────────────
	// LLM SERVICE — Google Gemini
	// ─────────────────────────────────────────────────────────────────────────
	geminiKey := os.Getenv("GEMINI_API_KEY")
	if geminiKey == "" {
		log.Fatal("[LLM] FATAL: GEMINI_API_KEY environment variable is not set. " +
			"Set it and restart the server.\n" +
			"  PowerShell: $env:GEMINI_API_KEY=\"your-key-here\"\n" +
			"  Bash:       export GEMINI_API_KEY=\"your-key-here\"")
	}

	llmSvc, err := services.NewLLMService(ctx, geminiKey)
	if err != nil {
		log.Fatalf("[LLM] Failed to initialise Gemini client: %v", err)
	}
	defer func() {
		if err := llmSvc.Close(); err != nil {
			log.Printf("[LLM] Warning: error closing LLM client: %v", err)
		}
	}()

	// ─────────────────────────────────────────────────────────────────────────
	// HANDLERS — dependency-injected
	// ─────────────────────────────────────────────────────────────────────────
	tutorHandler := handlers.NewTutorHandler(llmSvc)
	refresherHandler := handlers.NewRefresherHandler(llmSvc)
	mainsEvalHandler := handlers.NewMainsEvaluationHandler(llmSvc)
	dailyQuizHandler := handlers.NewDailyQuizHandler(llmSvc)

	// ─────────────────────────────────────────────────────────────────────────
	// HTTP ROUTER
	// ─────────────────────────────────────────────────────────────────────────
	mux := http.NewServeMux()

	// Health check (no auth, no DB dependency)
	mux.HandleFunc("/ping", handlers.HandlePing)

	// ── Auth routes (public — no JWT required) ──────────────────────────────
	if authService != nil {
		authHandler := handlers.NewAuthHandler(authService)
		mux.HandleFunc("/api/v1/auth/signup", authHandler.HandleSignup)
		mux.HandleFunc("/api/v1/auth/login", authHandler.HandleLogin)
		mux.HandleFunc("/api/v1/auth/google", authHandler.HandleGoogleAuth)
		mux.HandleFunc("/api/v1/auth/refresh", authHandler.HandleRefreshToken)
		mux.HandleFunc("/api/v1/auth/logout", authHandler.HandleLogout)
		mux.HandleFunc("/api/v1/auth/forgot-password", authHandler.HandleForgotPassword)
		mux.HandleFunc("/api/v1/auth/reset-password", authHandler.HandleResetPassword)

		// Protected auth route
		mux.Handle("/api/v1/auth/me",
			handlers.JWTAuthMiddleware(authService)(http.HandlerFunc(authHandler.HandleGetMe)),
		)
	} else {
		// Degraded mode — auth endpoints unavailable
		authDegraded := func(w http.ResponseWriter, r *http.Request) {
			http.Error(w, `{"error":"Database unavailable. Auth is running in degraded mode.","code":503}`, http.StatusServiceUnavailable)
		}
		mux.HandleFunc("/api/v1/auth/signup", authDegraded)
		mux.HandleFunc("/api/v1/auth/login", authDegraded)
		mux.HandleFunc("/api/v1/auth/google", authDegraded)
		mux.HandleFunc("/api/v1/auth/refresh", authDegraded)
		mux.HandleFunc("/api/v1/auth/logout", authDegraded)
		mux.HandleFunc("/api/v1/auth/forgot-password", authDegraded)
		mux.HandleFunc("/api/v1/auth/reset-password", authDegraded)
		mux.HandleFunc("/api/v1/auth/me", authDegraded)
	}

	// ── DB-dependent routes ─────────────────────────────────────────────────
	if repo != nil {
		ecosystemHandler := handlers.NewEcosystemHandler(llmSvc, repo)
		mux.HandleFunc("/api/v1/generate-ecosystem", ecosystemHandler.HandleGenerateEcosystem)
	} else {
		mux.HandleFunc("/api/v1/generate-ecosystem", func(w http.ResponseWriter, r *http.Request) {
			http.Error(w, `{"error":"Database unavailable. Service is running in degraded mode.","code":503}`, http.StatusServiceUnavailable)
		})
	}

	if bookmarkRepo != nil {
		bookmarkHandler := handlers.NewBookmarkHandler(bookmarkRepo)
		mux.HandleFunc("/api/v1/bookmarks", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodPost:
				bookmarkHandler.HandleCreateBookmark(w, r)
			case http.MethodGet:
				bookmarkHandler.HandleGetBookmarks(w, r)
			case http.MethodDelete:
				bookmarkHandler.HandleDeleteBookmark(w, r)
			default:
				http.Error(w, `{"error":"method not allowed","code":405}`, http.StatusMethodNotAllowed)
			}
		})
	} else {
		mux.HandleFunc("/api/v1/bookmarks", func(w http.ResponseWriter, r *http.Request) {
			http.Error(w, `{"error":"Database unavailable. Service is running in degraded mode.","code":503}`, http.StatusServiceUnavailable)
		})
	}

	// ── Profile routes (protected — require JWT) ────────────────────────────
	if userRepo != nil && authService != nil {
		profileHandler := handlers.NewProfileHandler(userRepo)
		jwtMW := handlers.JWTAuthMiddleware(authService)

		mux.Handle("/api/v1/profile",
			jwtMW(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodGet:
					profileHandler.HandleGetProfile(w, r)
				case http.MethodPut:
					profileHandler.HandleUpdateProfile(w, r)
				default:
					http.Error(w, `{"error":"method not allowed","code":405}`, http.StatusMethodNotAllowed)
				}
			})),
		)
		mux.Handle("/api/v1/profile/stats",
			jwtMW(http.HandlerFunc(profileHandler.HandleGetStats)),
		)
	} else {
		profileDegraded := func(w http.ResponseWriter, r *http.Request) {
			http.Error(w, `{"error":"Database unavailable. Profile is running in degraded mode.","code":503}`, http.StatusServiceUnavailable)
		}
		mux.HandleFunc("/api/v1/profile", profileDegraded)
		mux.HandleFunc("/api/v1/profile/stats", profileDegraded)
	}

	// ── LLM-only routes (no auth required for now) ──────────────────────────
	mux.HandleFunc("/api/v1/tutor", tutorHandler.HandleTutorRequest)
	mux.HandleFunc("/api/v1/syllabus-refresher", refresherHandler.HandleGetSyllabusRefresher)
	mux.HandleFunc("/api/v1/mains-evaluate", mainsEvalHandler.HandleMainsEvaluation)
	mux.HandleFunc("/api/v1/daily-quiz", dailyQuizHandler.HandleDailyQuiz)

	// ── Features 2-9 routes (protected — require JWT) ──────────────────────
	if analyticsRepo != nil && authService != nil {
		jwtMW := handlers.JWTAuthMiddleware(authService)
		analyticsHandler := handlers.NewAnalyticsHandler(analyticsRepo)

		// F2: Analytics
		mux.Handle("/api/v1/analytics/dashboard", jwtMW(http.HandlerFunc(analyticsHandler.HandleDashboard)))
		mux.Handle("/api/v1/analytics/progress", jwtMW(http.HandlerFunc(analyticsHandler.HandleProgress)))
		mux.Handle("/api/v1/analytics/streak", jwtMW(http.HandlerFunc(analyticsHandler.HandleStreak)))
		mux.Handle("/api/v1/analytics/record-attempt", jwtMW(http.HandlerFunc(analyticsHandler.HandleRecordAttempt)))
	}

	if featuresRepo != nil && authService != nil {
		jwtMW := handlers.JWTAuthMiddleware(authService)

		// F4/F5: AI Tutor Chat + Mentor
		tutorChatHandler := handlers.NewTutorChatHandler(llmSvc, featuresRepo)
		mux.Handle("/api/v1/tutor-chat/sessions", jwtMW(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				tutorChatHandler.HandleListSessions(w, r)
			case http.MethodPost:
				tutorChatHandler.HandleCreateSession(w, r)
			default:
				http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
			}
		})))
		mux.Handle("/api/v1/tutor-chat/messages", jwtMW(http.HandlerFunc(tutorChatHandler.HandleGetMessages)))
		mux.Handle("/api/v1/tutor-chat/send", jwtMW(http.HandlerFunc(tutorChatHandler.HandleSendMessage)))

		// F6: Revision Engine
		revisionHandler := handlers.NewRevisionHandler(featuresRepo)
		mux.Handle("/api/v1/revision/today", jwtMW(http.HandlerFunc(revisionHandler.HandleGetRevisions)))
		mux.Handle("/api/v1/revision/add", jwtMW(http.HandlerFunc(revisionHandler.HandleAddRevision)))
		mux.Handle("/api/v1/revision/complete", jwtMW(http.HandlerFunc(revisionHandler.HandleCompleteRevision)))

		// F7: Mock Tests
		mockTestHandler := handlers.NewMockTestHandler(featuresRepo)
		mux.HandleFunc("/api/v1/mock-tests", mockTestHandler.HandleListTests) // public listing
		mux.Handle("/api/v1/mock-tests/detail", jwtMW(http.HandlerFunc(mockTestHandler.HandleGetTest)))
		mux.Handle("/api/v1/mock-tests/start", jwtMW(http.HandlerFunc(mockTestHandler.HandleStartTest)))
		mux.Handle("/api/v1/mock-tests/submit", jwtMW(http.HandlerFunc(mockTestHandler.HandleSubmitTest)))
		mux.Handle("/api/v1/mock-tests/result", jwtMW(http.HandlerFunc(mockTestHandler.HandleGetResult)))

		// F8: Study Planner
		studyPlannerHandler := handlers.NewStudyPlannerHandler(featuresRepo, llmSvc)
		mux.Handle("/api/v1/study-plan", jwtMW(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				studyPlannerHandler.HandleGetPlan(w, r)
			case http.MethodPost:
				studyPlannerHandler.HandleCreatePlan(w, r)
			default:
				http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
			}
		})))
		mux.Handle("/api/v1/study-plan/complete-task", jwtMW(http.HandlerFunc(studyPlannerHandler.HandleCompleteTask)))

		// F9: Notes / Bookmarks v2
		notesHandler := handlers.NewNotesHandler(featuresRepo)
		mux.Handle("/api/v1/notes", jwtMW(http.HandlerFunc(notesHandler.HandleNotes)))
	}

	// ── Static routes (no auth, no DB) ──────────────────────────────────────
	mux.HandleFunc("/api/v1/syllabus", handlers.HandleGetSyllabus)

	// ─────────────────────────────────────────────────────────────────────────
	// MIDDLEWARE STACK  (applied outermost → innermost)
	// Order: Logging → CORS → Router
	// ─────────────────────────────────────────────────────────────────────────
	var handler http.Handler = mux
	handler = handlers.CORSMiddleware(handler)
	handler = handlers.LoggingMiddleware(handler)

	// ─────────────────────────────────────────────────────────────────────────
	// START
	// ─────────────────────────────────────────────────────────────────────────
	addr := fmt.Sprintf(":%s", port)

	log.Println("╔══════════════════════════════════════════════════════╗")
	log.Println("║   BPSC Engine — Examination Intelligence API       ║")
	log.Printf("║   Listening on http://localhost%s                ║\n", addr)
	log.Println("║   Version: 1.0.0  (Phase 8: Auth + Production)     ║")
	log.Println("╚══════════════════════════════════════════════════════╝")

	server := &http.Server{
		Addr:         addr,
		Handler:      handler,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 120 * time.Second, // generous for LLM responses
		IdleTimeout:  60 * time.Second,
	}
	if err := server.ListenAndServe(); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
