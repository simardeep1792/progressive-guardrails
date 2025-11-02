package main

import (
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	httpRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total HTTP requests",
		},
		[]string{"app", "method", "status", "path"},
	)

	httpRequestDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "HTTP request duration",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"app", "method", "status", "path"},
	)
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/", handleRoot)
	http.HandleFunc("/healthz", handleHealth)
	http.HandleFunc("/ready", handleReady)
	http.Handle("/metrics", promhttp.Handler())

	log.Printf("Starting server on port %s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}

func handleRoot(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	status := "200"

	defer func() {
		duration := time.Since(start).Seconds()
		httpRequestsTotal.WithLabelValues("webapp", r.Method, status, r.URL.Path).Inc()
		httpRequestDuration.WithLabelValues("webapp", r.Method, status, r.URL.Path).Observe(duration)
	}()

	if os.Getenv("INJECT_FAILURE") == "true" && rand.Float32() < 0.5 {
		status = "500"
		time.Sleep(time.Duration(rand.Intn(500)) * time.Millisecond)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	if rand.Float32() < 0.1 {
		time.Sleep(time.Duration(rand.Intn(200)) * time.Millisecond)
	}

	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"message":"Hello from webapp","version":"v1.0","timestamp":"%s"}`, time.Now().Format(time.RFC3339))
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "healthy")
}

func handleReady(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "ready")
}