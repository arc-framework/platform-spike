package main

import (
	"log"
	"net/http"
	"os"
	"time"
)

func main() {
	// This program simply makes an HTTP GET request to the URL provided
	// as the first argument. It exits with status 1 if the request fails
	// or if the status code is not 200 OK.
	client := http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get(os.Args[1])
	if err != nil {
		log.Fatalf("Request failed: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		log.Fatalf("Health check failed with status code: %d", resp.StatusCode)
	}
}
