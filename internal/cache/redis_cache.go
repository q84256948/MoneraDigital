// internal/cache/redis_cache.go
package cache

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

// RedisCache implements CacheService using Redis
type RedisCache struct {
	client *redis.Client
}

// NewRedisCache creates a new Redis cache instance
func NewRedisCache(addr string, password string, db int) (*RedisCache, error) {
	client := redis.NewClient(&redis.Options{
		Addr:     addr,
		Password: password,
		DB:       db,
	})

	// Test connection
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		return nil, &CacheError{
			Operation: "connect",
			Key:       "",
			Message:   fmt.Sprintf("failed to connect to Redis: %v", err),
		}
	}

	return &RedisCache{client: client}, nil
}

// Get retrieves a value from cache
func (rc *RedisCache) Get(ctx context.Context, key string) (string, error) {
	val, err := rc.client.Get(ctx, key).Result()
	if err == redis.Nil {
		return "", nil // Key doesn't exist
	}
	if err != nil {
		return "", &CacheError{
			Operation: "get",
			Key:       key,
			Message:   err.Error(),
		}
	}
	return val, nil
}

// Set stores a value in cache with TTL
func (rc *RedisCache) Set(ctx context.Context, key string, value string, ttl time.Duration) error {
	err := rc.client.Set(ctx, key, value, ttl).Err()
	if err != nil {
		return &CacheError{
			Operation: "set",
			Key:       key,
			Message:   err.Error(),
		}
	}
	return nil
}

// Delete removes a value from cache
func (rc *RedisCache) Delete(ctx context.Context, key string) error {
	err := rc.client.Del(ctx, key).Err()
	if err != nil {
		return &CacheError{
			Operation: "delete",
			Key:       key,
			Message:   err.Error(),
		}
	}
	return nil
}

// Exists checks if a key exists in cache
func (rc *RedisCache) Exists(ctx context.Context, key string) (bool, error) {
	exists, err := rc.client.Exists(ctx, key).Result()
	if err != nil {
		return false, &CacheError{
			Operation: "exists",
			Key:       key,
			Message:   err.Error(),
		}
	}
	return exists > 0, nil
}

// Increment increments a numeric value
func (rc *RedisCache) Increment(ctx context.Context, key string) (int64, error) {
	val, err := rc.client.Incr(ctx, key).Result()
	if err != nil {
		return 0, &CacheError{
			Operation: "increment",
			Key:       key,
			Message:   err.Error(),
		}
	}
	return val, nil
}

// Decrement decrements a numeric value
func (rc *RedisCache) Decrement(ctx context.Context, key string) (int64, error) {
	val, err := rc.client.Decr(ctx, key).Result()
	if err != nil {
		return 0, &CacheError{
			Operation: "decrement",
			Key:       key,
			Message:   err.Error(),
		}
	}
	return val, nil
}

// SetWithExpiry sets a value with absolute expiry time
func (rc *RedisCache) SetWithExpiry(ctx context.Context, key string, value string, expiry time.Time) error {
	ttl := time.Until(expiry)
	if ttl <= 0 {
		return &CacheError{
			Operation: "set_with_expiry",
			Key:       key,
			Message:   "expiry time is in the past",
		}
	}
	return rc.Set(ctx, key, value, ttl)
}

// GetTTL gets remaining TTL for a key
func (rc *RedisCache) GetTTL(ctx context.Context, key string) (time.Duration, error) {
	ttl, err := rc.client.TTL(ctx, key).Result()
	if err != nil {
		return 0, &CacheError{
			Operation: "get_ttl",
			Key:       key,
			Message:   err.Error(),
		}
	}
	return ttl, nil
}

// FlushAll clears all cache entries
func (rc *RedisCache) FlushAll(ctx context.Context) error {
	err := rc.client.FlushAll(ctx).Err()
	if err != nil {
		return &CacheError{
			Operation: "flush_all",
			Key:       "",
			Message:   err.Error(),
		}
	}
	return nil
}

// Close closes the Redis connection
func (rc *RedisCache) Close() error {
	return rc.client.Close()
}
