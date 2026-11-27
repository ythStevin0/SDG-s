package cache

import (
	"strings"
	"sync"
	"time"
)

type entry struct {
	value     any
	expiresAt time.Time
}

// TTLCache adalah application cache in-memory yang aman terhadap konkurensi (sync.RWMutex)
// untuk mencegah concurrent map writes serta mendukung TTL wajib & invalidasi eksplisit.
type TTLCache struct {
	mu    sync.RWMutex
	items map[string]entry
}

func NewTTLCache() *TTLCache {
	c := &TTLCache{
		items: make(map[string]entry),
	}
	return c
}

func (c *TTLCache) Get(key string) (any, bool) {
	c.mu.RLock()
	it, ok := c.items[key]
	c.mu.RUnlock()
	if !ok {
		return nil, false
	}
	if time.Now().After(it.expiresAt) {
		c.Delete(key)
		return nil, false
	}
	return it.value, true
}

func (c *TTLCache) Set(key string, value any, ttl time.Duration) {
	if ttl <= 0 {
		return
	}
	c.mu.Lock()
	c.items[key] = entry{
		value:     value,
		expiresAt: time.Now().Add(ttl),
	}
	c.mu.Unlock()
}

func (c *TTLCache) Delete(key string) {
	c.mu.Lock()
	delete(c.items, key)
	c.mu.Unlock()
}

func (c *TTLCache) InvalidatePrefix(prefix string) int {
	c.mu.Lock()
	defer c.mu.Unlock()
	removed := 0
	for k := range c.items {
		if strings.HasPrefix(k, prefix) {
			delete(c.items, k)
			removed++
		}
	}
	return removed
}

func (c *TTLCache) Stats() int {
	c.mu.RLock()
	defer c.mu.RUnlock()
	now := time.Now()
	active := 0
	for _, v := range c.items {
		if now.Before(v.expiresAt) {
			active++
		}
	}
	return active
}
