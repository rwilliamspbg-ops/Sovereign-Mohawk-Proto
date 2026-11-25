// Copyright 2026 Sovereign-Mohawk Core Team
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

// The old limiter keyed on RemoteAddr, so a keep-alive client with many ephemeral
// source ports (or the same one) was capped at 21 requests forever. Keying must be
// by client IP only, so distinct source ports from one host share the budget.
func TestWindowRateLimiterKeysByClientIP(t *testing.T) {
	l := newWindowRateLimiter(time.Minute, 5)
	for i := 0; i < 5; i++ {
		if !l.allow(fmt.Sprintf("10.0.0.29:%d", 40000+i)) {
			t.Fatalf("request %d from a fresh source port was rejected", i)
		}
	}
	if l.allow("10.0.0.29:49999") {
		t.Fatal("6th request from the same client IP accepted, limit=5")
	}
	if !l.allow("10.0.0.30:40000") {
		t.Fatal("unrelated client IP was rejected")
	}
}

func TestWindowRateLimiterSlidesAfterWindow(t *testing.T) {
	l := newWindowRateLimiter(20*time.Millisecond, 1)
	if !l.allow("198.51.100.7:1111") {
		t.Fatal("first request rejected")
	}
	if l.allow("198.51.100.7:2222") {
		t.Fatal("second request inside the window accepted")
	}
	time.Sleep(30 * time.Millisecond)
	if !l.allow("198.51.100.7:3333") {
		t.Fatal("request after the window expired was rejected")
	}
}

func TestRateLimitMiddlewareReturns429ForSameIPDifferentPort(t *testing.T) {
	previous := routerRateLimiter
	routerRateLimiter = newWindowRateLimiter(time.Minute, 1)
	defer func() { routerRateLimiter = previous }()

	called := false
	handler := rateLimitMiddleware(func(w http.ResponseWriter, _ *http.Request) {
		called = true
		w.WriteHeader(http.StatusOK)
	})

	first := httptest.NewRequest(http.MethodPost, "/router/publish", nil)
	first.RemoteAddr = "203.0.113.9:5000"
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, first)
	if recorder.Code != http.StatusOK || !called {
		t.Fatalf("first request: code=%d handlerCalled=%v", recorder.Code, called)
	}

	second := httptest.NewRequest(http.MethodPost, "/router/publish", nil)
	second.RemoteAddr = "203.0.113.9:5001"
	recorder = httptest.NewRecorder()
	handler.ServeHTTP(recorder, second)
	if recorder.Code != http.StatusTooManyRequests {
		t.Fatalf("second request: code=%d, want 429", recorder.Code)
	}
}
