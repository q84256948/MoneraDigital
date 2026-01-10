// internal/monitoring/health_check.go
package monitoring

import (
	"database/sql"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"monera-digital/internal/cache"
)

// HealthCheckService provides health check functionality
type HealthCheckService struct {
	db      *sql.DB
	cache   cache.CacheService
	metrics *Metrics
}

// NewHealthCheckService creates a new health check service
func NewHealthCheckService(db *sql.DB, cache cache.CacheService, metrics *Metrics) *HealthCheckService {
	return &HealthCheckService{
		db:      db,
		cache:   cache,
		metrics: metrics,
	}
}

// HealthStatus represents the health status of the system
type HealthStatus struct {
	Status    string                 `json:"status"`
	Timestamp time.Time              `json:"timestamp"`
	Uptime    float64                `json:"uptime_seconds"`
	Components map[string]ComponentStatus `json:"components"`
	Metrics   map[string]interface{} `json:"metrics"`
}

// ComponentStatus represents the status of a system component
type ComponentStatus struct {
	Status  string `json:"status"`
	Message string `json:"message,omitempty"`
}

// Check performs a health check on all components
func (hcs *HealthCheckService) Check() *HealthStatus {
	status := &HealthStatus{
		Status:     "healthy",
		Timestamp:  time.Now(),
		Components: make(map[string]ComponentStatus),
		Metrics:    hcs.metrics.GetSnapshot(),
	}

	// Check database
	if err := hcs.checkDatabase(); err != nil {
		status.Components["database"] = ComponentStatus{
			Status:  "unhealthy",
			Message: err.Error(),
		}
		status.Status = "degraded"
	} else {
		status.Components["database"] = ComponentStatus{Status: "healthy"}
	}

	// Check cache
	if err := hcs.checkCache(); err != nil {
		status.Components["cache"] = ComponentStatus{
			Status:  "unhealthy",
			Message: err.Error(),
		}
		status.Status = "degraded"
	} else {
		status.Components["cache"] = ComponentStatus{Status: "healthy"}
	}

	// Calculate uptime
	status.Uptime = time.Since(hcs.metrics.StartTime).Seconds()

	return status
}

// checkDatabase checks database connectivity
func (hcs *HealthCheckService) checkDatabase() error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := hcs.db.PingContext(ctx); err != nil {
		return err
	}
	return nil
}

// checkCache checks cache connectivity
func (hcs *HealthCheckService) checkCache() error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Try to set and get a test key
	testKey := "health_check_test"
	testValue := "ok"

	if err := hcs.cache.Set(ctx, testKey, testValue, 10*time.Second); err != nil {
		return err
	}

	val, err := hcs.cache.Get(ctx, testKey)
	if err != nil {
		return err
	}

	if val != testValue {
		return ErrCacheValueMismatch
	}

	// Clean up
	_ = hcs.cache.Delete(ctx, testKey)

	return nil
}

// HealthCheckHandler returns a Gin handler for health checks
func (hcs *HealthCheckService) HealthCheckHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		status := hcs.Check()

		statusCode := http.StatusOK
		if status.Status == "unhealthy" {
			statusCode = http.StatusServiceUnavailable
		} else if status.Status == "degraded" {
			statusCode = http.StatusOK // Still return 200 but indicate degraded status
		}

		c.JSON(statusCode, status)
	}
}

// MetricsHandler returns a Gin handler for metrics
func (hcs *HealthCheckService) MetricsHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusOK, hcs.metrics.GetSnapshot())
	}
}

// Custom errors
var (
	ErrCacheValueMismatch = &CacheError{
		Operation: "health_check",
		Key:       "health_check_test",
		Message:   "cache value mismatch",
	}
)

// Import context
import "context"
