package cache

import (
	"fmt"
	"sync"
	"testing"
	"time"
)

func TestTTLCacheOperations(t *testing.T) {
	c := NewTTLCache()
	c.Set("catalog:jagung", "ok", time.Minute)
	c.Set("other:key", 42, time.Minute)

	if v, ok := c.Get("catalog:jagung"); !ok || v != "ok" {
		t.Fatalf("expected cached value 'ok', got %v (%v)", v, ok)
	}

	c.Set("temp:short", "gone", 50*time.Millisecond)
	time.Sleep(80 * time.Millisecond)
	if _, ok := c.Get("temp:short"); ok {
		t.Fatalf("expected expired key to return false")
	}

	removed := c.InvalidatePrefix("catalog:")
	if removed != 1 {
		t.Errorf("expected 1 key invalidated, got %d", removed)
	}
	if _, ok := c.Get("catalog:jagung"); ok {
		t.Errorf("expected catalog:jagung to be invalidated")
	}
	if v, ok := c.Get("other:key"); !ok || v != 42 {
		t.Errorf("expected other:key to survive invalidation, got %v (%v)", v, ok)
	}

	c.Delete("other:key")
	if _, ok := c.Get("other:key"); ok {
		t.Errorf("expected deleted key to return false")
	}
}

func TestTTLCacheConcurrentAccess(t *testing.T) {
	c := NewTTLCache()
	var wg sync.WaitGroup
	for g := 0; g < 20; g++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			key := fmt.Sprintf("forecast:%d", id%5)
			for i := 0; i < 30; i++ {
				c.Set(key, i, time.Second)
				_, _ = c.Get(key)
				if i%10 == 0 {
					_ = c.Stats()
				}
			}
		}(g)
	}
	wg.Wait()
}
