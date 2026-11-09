package federation

import (
	"context"
	"net"

	federationpb "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/gen"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/test/bufconn"
)

// RealFederationServer is a minimal implementation of the generated gRPC
// FederationService using the compiled protobuf contract.
type RealFederationServer struct {
	federationpb.UnimplementedFederationServiceServer
}

func (s *RealFederationServer) ForwardGradient(ctx context.Context, req *federationpb.GradientRequest) (*federationpb.ForwardResponse, error) {
	return &federationpb.ForwardResponse{
		Success:          true,
		Message:          "ok",
		AcceptedCount:    1,
	}, nil
}

// NewRealGRPCServer starts an in-process gRPC server backed by bufconn for
// testing and local wiring.
func NewRealGRPCServer() (*grpc.Server, *bufconn.Listener, error) {
	lis := bufconn.Listen(1024 * 1024)
	srv := grpc.NewServer()
	federationpb.RegisterFederationServiceServer(srv, &RealFederationServer{})
	go func() {
		_ = srv.Serve(lis)
	}()
	return srv, lis, nil
}

// DialRealFederation creates a gRPC client connection to a bufconn listener.
func DialRealFederation(ctx context.Context, lis *bufconn.Listener) (federationpb.FederationServiceClient, func(), error) {
	conn, err := grpc.DialContext(ctx, "bufnet", grpc.WithContextDialer(func(ctx context.Context, s string) (net.Conn, error) {
		return lis.DialContext(ctx)
	}), grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return nil, nil, err
	}
	return federationpb.NewFederationServiceClient(conn), func() { conn.Close() }, nil
}