package main

import (
	"encoding/json"
	"io/ioutil"
	"log"
	"net/http"
	"time"

	"github.com/gomodule/redigo/redis"
)

type Message struct {
	MessageNumber int64  `json:"message_number"`
	TimeStamp     string `json:"time_stamp"`
}

// Handler is the entry point for this fission function
func Handler(w http.ResponseWriter, r *http.Request) {
	b, err := ioutil.ReadAll(r.Body)
	defer r.Body.Close()
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}

	var msg Message
	err = json.Unmarshal(b, &msg)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}

	output, err := json.Marshal(msg)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	w.Header().Set("content-type", "application/json")
	w.Write(output)
	log.Println(string(output))
	conn, err := redis.Dial("tcp", "redis-single-master.redis:6379")
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()
	_, err = conn.Do("INCR", "consumed")
	if err != nil {
		log.Fatal(err)
	}
	time.Sleep(250 * time.Millisecond)
}
