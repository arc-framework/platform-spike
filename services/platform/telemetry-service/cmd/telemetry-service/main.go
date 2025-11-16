package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"time"
)

func main() {
	slog.Info("Starting telemetry service...")

	// Set up a context that is canceled on an interrupt signal (CTRL+C).
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	// TODO: Initialize Pulsar Client
	// pulsarURL := os.Getenv("PULSAR_URL")
	// if pulsarURL == "" {
	// 	pulsarURL = "pulsar://localhost:6650"
	// }
	// client, err := pulsar.NewClient(...)
	// if err != nil {
	// 	slog.Error("could not connect to Pulsar", "error", err)
	// 	os.Exit(1)
	// }
	// defer client.Close()

	// TODO: Initialize OpenTelemetry Exporters (Trace, Metric, Log)
	// shutdown, err := newOtelProvider(ctx)
	// if err != nil {
	// 	slog.Error("failed to set up OpenTelemetry exporters", "error", err)
	// 	os.Exit(1)
	// }
	// defer func() {
	// 	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	// 	defer cancel()
	// 	if err := shutdown(shutdownCtx); err != nil {
	// 		slog.Error("failed to shutdown OpenTelemetry provider", "error", err)
	// 	}
	// }()

	// TODO: Start the Pulsar consumer
	// consumer, err := client.Subscribe(...)
	// if err != nil {
	// 	slog.Error("could not subscribe to topic", "error", err)
	// 	os.Exit(1)
	// }
	// go consumeMessages(ctx, consumer)

	slog.Info("Service is running. Waiting for messages...")

	// Wait for the interrupt signal.
	<-ctx.Done()

	slog.Info("Shutting down service...")
}

// consumeMessages would be the main loop for receiving messages from Pulsar.
// func consumeMessages(ctx context.Context, consumer pulsar.Consumer) {
// 	for {
// 		msg, err := consumer.Receive(ctx)
// 		if err != nil {
// 			// If context is cancelled, the loop will exit gracefully.
// 			if ctx.Err() != nil {
// 				slog.Info("Consumer shutting down.")
// 				return
// 			}
// 			slog.Error("failed to receive message", "error", err)
// 			continue
// 		}
//
// 		// TODO:
// 		// 1. Deserialize the message payload using the telemetry.proto definition.
// 		// 2. Use a switch on the `oneof` payload type.
// 		// 3. Based on the type, deserialize the inner OTel proto bytes.
// 		// 4. Send the OTel object to the appropriate exporter.
//
// 		consumer.Ack(msg)
// 	}
// }
