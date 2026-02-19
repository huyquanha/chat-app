package main

import (
	"context"
	"net/http"

	"connectrpc.com/connect"
	"connectrpc.com/validate"

	"google.golang.org/protobuf/types/known/timestamppb"

	chatv1 "github.com/huyquanha/chat-app/protos/chat/v1"
)

type ChatServer struct{}

func (s *ChatServer) SendMessage(
	_ context.Context,
	req *connect.Request[chatv1.SendMessageRequest],
) (*connect.Response[chatv1.SendMessageResponse], error) {
	res := &chatv1.SendMessageResponse{
		MessageId: "1",
		SentAt:    timestamppb.Now(),
	}
	return connect.NewResponse(res), nil
}

func (s *ChatServer) Subscribe(
	_ context.Context,
	req *connect.Request[chatv1.SubscribeRequest],
	stream *connect.ServerStream[chatv1.ChatMessage],
) error {
	res := &chatv1.ChatMessage{
		Id:       "1",
		Content:  "Hello, world!",
		SenderId: "1",
		RoomId:   "1",
		SentAt:   timestamppb.Now(),
	}
	stream.Send(res)
	return nil
}

func main() {
	chatServer := &ChatServer{}
	mux := http.NewServeMux()
	path, handler := chatv1.NewChatServiceHandler(
		chatServer,
		// Validation via Protovalidate is almost always recommended
		connect.WithInterceptors(validate.NewInterceptor()),
	)
	mux.Handle(path, handler)
	p := new(http.Protocols)
	p.SetHTTP1(true)
	// Use h2c so we can serve HTTP/2 without TLS.
	p.SetUnencryptedHTTP2(true)
	s := http.Server{
		Addr:      "localhost:8080",
		Handler:   mux,
		Protocols: p,
	}
	s.ListenAndServe()
}
