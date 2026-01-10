// internal/monitoring/monitoring_middleware.go
package monitoring

import (
	"time"

	"github.com/gin-gonic/gin"
)

// MonitoringMiddleware creates a middleware that records request metrics
func MonitoringMiddleware(metrics *Metrics) gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()

		// Process request
		c.Next()

		// Record metrics
		duration := time.Since(start)
		statusCode := c.Writer.Status()
		success := statusCode >= 200 && statusCode < 400

		metrics.RecordRequest(duration, success)

		// Record errors
		if !success {
			errorType := c.GetString("error_type")
			if errorType == "" {
				errorType = "unknown_error"
			}
			metrics.RecordError(errorType)
		}
	}
}

// AlertThreshold represents an alert threshold
type AlertThreshold struct {
	Name              string
	Condition         func(*Metrics) bool
	Message           string
	SeverityLevel     string // "info", "warning", "critical"
}

// AlertManager manages system alerts
type AlertManager struct {
	metrics    *Metrics
	thresholds []*AlertThreshold
	alerts     []Alert
}

// Alert represents a triggered alert
type Alert struct {
	Timestamp   time.Time
	Message     string
	SeverityLevel string
	Resolved    bool
}

// NewAlertManager creates a new alert manager
func NewAlertManager(metrics *Metrics) *AlertManager {
	return &AlertManager{
		metrics:    metrics,
		thresholds: make([]*AlertThreshold, 0),
		alerts:     make([]Alert, 0),
	}
}

// AddThreshold adds an alert threshold
func (am *AlertManager) AddThreshold(threshold *AlertThreshold) {
	am.thresholds = append(am.thresholds, threshold)
}

// Check checks all thresholds and triggers alerts if needed
func (am *AlertManager) Check() []Alert {
	var triggeredAlerts []Alert

	for _, threshold := range am.thresholds {
		if threshold.Condition(am.metrics) {
			alert := Alert{
				Timestamp:     time.Now(),
				Message:       threshold.Message,
				SeverityLevel: threshold.SeverityLevel,
				Resolved:      false,
			}
			triggeredAlerts = append(triggeredAlerts, alert)
			am.alerts = append(am.alerts, alert)
		}
	}

	return triggeredAlerts
}

// GetActiveAlerts returns all active (unresolved) alerts
func (am *AlertManager) GetActiveAlerts() []Alert {
	var activeAlerts []Alert
	for _, alert := range am.alerts {
		if !alert.Resolved {
			activeAlerts = append(activeAlerts, alert)
		}
	}
	return activeAlerts
}

// ResolveAlert marks an alert as resolved
func (am *AlertManager) ResolveAlert(index int) {
	if index >= 0 && index < len(am.alerts) {
		am.alerts[index].Resolved = true
	}
}

// ClearResolvedAlerts removes resolved alerts
func (am *AlertManager) ClearResolvedAlerts() {
	var activeAlerts []Alert
	for _, alert := range am.alerts {
		if !alert.Resolved {
			activeAlerts = append(activeAlerts, alert)
		}
	}
	am.alerts = activeAlerts
}
