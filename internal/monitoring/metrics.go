// internal/monitoring/metrics.go
package monitoring

import (
	"sync"
	"time"
)

// Metrics represents application metrics
type Metrics struct {
	mu sync.RWMutex

	// Request metrics
	TotalRequests      int64
	SuccessfulRequests int64
	FailedRequests     int64
	TotalResponseTime  time.Duration

	// Error metrics
	ErrorCount map[string]int64

	// Cache metrics
	CacheHits   int64
	CacheMisses int64

	// Database metrics
	DBQueryCount    int64
	DBQueryDuration time.Duration

	// Timestamp
	StartTime time.Time
	LastReset time.Time
}

// NewMetrics creates a new metrics instance
func NewMetrics() *Metrics {
	return &Metrics{
		ErrorCount: make(map[string]int64),
		StartTime:  time.Now(),
		LastReset:  time.Now(),
	}
}

// RecordRequest records a request
func (m *Metrics) RecordRequest(duration time.Duration, success bool) {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.TotalRequests++
	m.TotalResponseTime += duration

	if success {
		m.SuccessfulRequests++
	} else {
		m.FailedRequests++
	}
}

// RecordError records an error
func (m *Metrics) RecordError(errorType string) {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.ErrorCount[errorType]++
}

// RecordCacheHit records a cache hit
func (m *Metrics) RecordCacheHit() {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.CacheHits++
}

// RecordCacheMiss records a cache miss
func (m *Metrics) RecordCacheMiss() {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.CacheMisses++
}

// RecordDBQuery records a database query
func (m *Metrics) RecordDBQuery(duration time.Duration) {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.DBQueryCount++
	m.DBQueryDuration += duration
}

// GetAverageResponseTime returns average response time
func (m *Metrics) GetAverageResponseTime() time.Duration {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if m.TotalRequests == 0 {
		return 0
	}

	return m.TotalResponseTime / time.Duration(m.TotalRequests)
}

// GetSuccessRate returns success rate percentage
func (m *Metrics) GetSuccessRate() float64 {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if m.TotalRequests == 0 {
		return 0
	}

	return float64(m.SuccessfulRequests) / float64(m.TotalRequests) * 100
}

// GetCacheHitRate returns cache hit rate percentage
func (m *Metrics) GetCacheHitRate() float64 {
	m.mu.RLock()
	defer m.mu.RUnlock()

	totalCacheOps := m.CacheHits + m.CacheMisses
	if totalCacheOps == 0 {
		return 0
	}

	return float64(m.CacheHits) / float64(totalCacheOps) * 100
}

// GetAverageDBQueryTime returns average database query time
func (m *Metrics) GetAverageDBQueryTime() time.Duration {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if m.DBQueryCount == 0 {
		return 0
	}

	return m.DBQueryDuration / time.Duration(m.DBQueryCount)
}

// GetSnapshot returns a snapshot of current metrics
func (m *Metrics) GetSnapshot() map[string]interface{} {
	m.mu.RLock()
	defer m.mu.RUnlock()

	return map[string]interface{}{
		"total_requests":       m.TotalRequests,
		"successful_requests":  m.SuccessfulRequests,
		"failed_requests":      m.FailedRequests,
		"success_rate":         m.GetSuccessRate(),
		"avg_response_time_ms": m.GetAverageResponseTime().Milliseconds(),
		"cache_hits":           m.CacheHits,
		"cache_misses":         m.CacheMisses,
		"cache_hit_rate":       m.GetCacheHitRate(),
		"db_query_count":       m.DBQueryCount,
		"avg_db_query_time_ms": m.GetAverageDBQueryTime().Milliseconds(),
		"error_count":          m.ErrorCount,
		"uptime_seconds":       time.Since(m.StartTime).Seconds(),
	}
}

// Reset resets all metrics
func (m *Metrics) Reset() {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.TotalRequests = 0
	m.SuccessfulRequests = 0
	m.FailedRequests = 0
	m.TotalResponseTime = 0
	m.ErrorCount = make(map[string]int64)
	m.CacheHits = 0
	m.CacheMisses = 0
	m.DBQueryCount = 0
	m.DBQueryDuration = 0
	m.LastReset = time.Now()
}
