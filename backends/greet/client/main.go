package main

import (
	"context"
	"log"
	"net/http"

	"connectrpc.com/connect"

	greetv1 "github.com/huyquanha/chat-app/protos/greet/v1"
)

func main() {
	client := greetv1.NewGreetServiceClient(
		http.DefaultClient,
		"http://localhost:8080",
		// connect.WithGRPC(), // To use gRPC rather than Connect
	)
	res, err := client.Greet(
		context.Background(),
		connect.NewRequest(&greetv1.GreetRequest{Name: "Jane"}),
	)
	if err != nil {
		log.Println(err)
		return
	}
	log.Println(res.Msg.Greeting)
}
