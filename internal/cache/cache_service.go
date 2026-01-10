// internal/cache/cache_service.go
package cache

import (
	"context"
	"time"
)

// CacheService defines the interface for caching operations
type CacheService interface {
	// Get retrieves a value from cache
	Get(ctx context.Context, key string) (string, error)

	// Set stores a value in cache with TTL
	Set(ctx context.Context, key string, value string, ttl time.Duration) error

	// Delete removes a value from cache
	Delete(ctx context.Context, key string) error

	// Exists checks if a key exists in cache
	Exists(ctx context.Context, key string) (bool, error)

	// Increment increments a numeric value
	Increment(ctx context.Context, key string) (int64, error)

	// Decrement decrements a numeric value
	Decrement(ctx context.Context, key string) (int64, error)

	// SetWithExpiry sets a value with absolute expiry time
	SetWithExpiry(ctx context.Context, key string, value string, expiry time.Time) error

	// GetTTL gets remaining TTL for a key
	GetTTL(ctx context.Context, key string) (time.Duration, error)

	// FlushAll clears all cache entries
	FlushAll(ctx context.Context) error

	// Close closes the cache connection
	Close() error
}

// CacheError represents a cache operation error
type CacheError struct {
	Operation string
	Key       string
	Message   string
}

func (e *CacheError) Error() string {
	return "cache error: " + e.Message + " (operation: " + e.Operation + ", key: " + e.Key + ")"
}
