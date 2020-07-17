package main

import (
	"fmt"
	"log"
	"net/http"
	"time"

	sarama "github.com/Shopify/sarama"
	"github.com/gomodule/redigo/redis"
)

// Handler posts a message to Kafka Topic
func Handler(w http.ResponseWriter, r *http.Request) {
	brokers := []string{"my-cluster-kafka-brokers.my-kafka-project.svc:9092"}
	producerConfig := sarama.NewConfig()
	producerConfig.Producer.RequiredAcks = sarama.WaitForAll
	producerConfig.Producer.Retry.Max = 10
	producerConfig.Producer.Retry.Backoff = 10
	producerConfig.Producer.Return.Successes = true
	producerConfig.Version = sarama.V1_0_0_0
	producer, err := sarama.NewSyncProducer(brokers, producerConfig)
	fmt.Println("Created a new producer ", producer)
	if err != nil {
		panic(err)
	}
	conn, err := redis.Dial("tcp", "redis-single-master.redis:6379")
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()
	for msg := 1; msg <= 1700; msg++ {
		ts := time.Now().Format(time.RFC3339)
		message := fmt.Sprintf("{\"message_number\": %d, \"time_stamp\": \"%s\"}", msg, ts)
		_, _, err = producer.SendMessage(&sarama.ProducerMessage{
			Topic: "one-seven-request",
			Value: sarama.StringEncoder(message),
		})
		_, _ = conn.Do("INCR", "produced")
		if err != nil {
			w.Write([]byte(fmt.Sprintf("Failed to publish message to topic %s: %v on msg: %v", "one-seven-request", err, msg)))
			return
		}
	}

	w.Write([]byte("Successfully sent to one-seven-request"))
}
