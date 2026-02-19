package main

import (
	"context"
	"fmt"
	"log"
	"net/http"

	"connectrpc.com/connect"

	chatv1 "github.com/huyquanha/chat-app/protos/chat/v1"
)

func main() {
	client := chatv1.NewChatServiceClient(http.DefaultClient, "localhost:50051")
	request := connect.NewRequest(&chatv1.SendMessageRequest{
		RoomId:  "123",
		Content: "Hello, world!",
	})
	response, err := client.SendMessage(context.Background(), request)
	if err != nil {
		log.Fatalf("failed to send message: %v", err)
	}
	fmt.Println(response)
}
