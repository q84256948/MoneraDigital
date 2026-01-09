package services

import (
	"database/sql"
	"errors"
	"monera-digital/internal/config"
	"monera-digital/internal/models"
	"monera-digital/internal/utils"
)

type AuthService struct{
	DB *sql.DB
}

func NewAuthService(db *sql.DB) *AuthService {
	return &AuthService{DB: db}
}

type LoginResponse struct {
	User        *models.User `json:"user,omitempty"`
	Token       string       `json:"token,omitempty"`
	Requires2FA bool         `json:"requires_2fa,omitempty"`
	UserID      int          `json:"user_id,omitempty"`
}

func (s *AuthService) Register(req models.RegisterRequest) (*models.User, error) {
	// 1. Check if user exists
	var exists bool
	err := s.DB.QueryRow("SELECT EXISTS(SELECT 1 FROM users WHERE email = $1)", req.Email).Scan(&exists)
	if err != nil {
		return nil, err
	}
	if exists {
		return nil, errors.New("email already registered")
	}

	// 2. Hash password
	hashedPassword, err := utils.HashPassword(req.Password)
	if err != nil {
		return nil, err
	}

	// 3. Insert user
	var user models.User
	query := `
		INSERT INTO users (email, password, created_at)
		VALUES ($1, $2, NOW())
		RETURNING id, email, created_at, two_factor_enabled`
	
	err = s.DB.QueryRow(query, req.Email, hashedPassword).Scan(
		&user.ID, &user.Email, &user.CreatedAt, &user.TwoFactorEnabled,
	)
	if err != nil {
		return nil, err
	}

	return &user, nil
}

func (s *AuthService) Login(req models.LoginRequest) (*LoginResponse, error) {
	// 1. Find user
	var user models.User
	var hashedPassword string
	
	query := `SELECT id, email, password, two_factor_enabled FROM users WHERE email = $1`
	err := s.DB.QueryRow(query, req.Email).Scan(&user.ID, &user.Email, &hashedPassword, &user.TwoFactorEnabled)
	
	if err == sql.ErrNoRows {
		return nil, errors.New("invalid credentials")
	} else if err != nil {
		return nil, err
	}

	// 2. Check password
	if !utils.CheckPasswordHash(req.Password, hashedPassword) {
		return nil, errors.New("invalid credentials")
	}

	// 3. Generate Token
	// Note: In a real app, we should pass the secret from config properly.
	// For now, we load it again or assume it's passed. 
	// To keep signature simple, let's load config here (not ideal for perf but works)
	cfg := config.Load()
	token, err := utils.GenerateJWT(user.ID, user.Email, cfg.JWTSecret)
	if err != nil {
		return nil, err
	}

	return &LoginResponse{
		User:  &user,
		Token: token,
	}, nil
}

func (s *AuthService) Verify2FAAndLogin(userID int, token string) (*LoginResponse, error) {
	// TODO: Implement
	return &LoginResponse{}, nil
}

func (s *AuthService) GetUserByID(userID int) (*models.User, error) {
	// TODO: Implement
	return &models.User{}, nil
}