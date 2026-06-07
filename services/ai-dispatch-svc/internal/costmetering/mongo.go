package costmetering

import (
	"context"
	"fmt"
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/config"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

var costIndexes = []mongo.IndexModel{
	{
		Keys:    bson.D{{Key: "taskId", Value: 1}, {Key: "reportedAt", Value: 1}},
		Options: options.Index().SetName("idx_task_reported"),
	},
	{
		Keys:    bson.D{{Key: "reportedAt", Value: 1}},
		Options: options.Index().SetName("idx_reported"),
	},
}

// MongoStore persists cost_metering documents in MongoDB.
type MongoStore struct {
	client *mongo.Client
	coll   *mongo.Collection
}

// NewMongoStore connects to MongoDB and ensures indexes.
func NewMongoStore(cfg *config.Config) (*MongoStore, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	client, err := mongo.Connect(ctx, options.Client().ApplyURI(cfg.MongoURI))
	if err != nil {
		return nil, fmt.Errorf("mongo connect: %w", err)
	}
	if err := client.Ping(ctx, nil); err != nil {
		_ = client.Disconnect(ctx)
		return nil, fmt.Errorf("mongo ping: %w", err)
	}

	coll := client.Database(cfg.MongoDatabase).Collection(CollectionName)
	if _, err := coll.Indexes().CreateMany(ctx, costIndexes); err != nil {
		_ = client.Disconnect(ctx)
		return nil, fmt.Errorf("create indexes: %w", err)
	}

	return &MongoStore{client: client, coll: coll}, nil
}

// Insert adds a cost record.
func (s *MongoStore) Insert(ctx context.Context, record *Record) error {
	if record == nil || record.ID == "" {
		return fmt.Errorf("record id required")
	}
	_, err := s.coll.InsertOne(ctx, record)
	return err
}

// ListByTaskID returns all records for a task ordered by reportedAt.
func (s *MongoStore) ListByTaskID(ctx context.Context, taskID string) ([]Record, error) {
	cur, err := s.coll.Find(ctx, bson.M{"taskId": taskID}, options.Find().SetSort(bson.D{{Key: "reportedAt", Value: 1}}))
	if err != nil {
		return nil, err
	}
	defer cur.Close(ctx)
	var out []Record
	if err := cur.All(ctx, &out); err != nil {
		return nil, err
	}
	return out, nil
}

// ListByTimeRange returns records with reportedAt in [start, end).
func (s *MongoStore) ListByTimeRange(ctx context.Context, start, end time.Time) ([]Record, error) {
	filter := bson.M{
		"reportedAt": bson.M{
			"$gte": start,
			"$lt":  end,
		},
	}
	cur, err := s.coll.Find(ctx, filter, options.Find().SetSort(bson.D{{Key: "reportedAt", Value: 1}}))
	if err != nil {
		return nil, err
	}
	defer cur.Close(ctx)
	var out []Record
	if err := cur.All(ctx, &out); err != nil {
		return nil, err
	}
	return out, nil
}

// Close disconnects the Mongo client.
func (s *MongoStore) Close(ctx context.Context) error {
	if s.client == nil {
		return nil
	}
	return s.client.Disconnect(ctx)
}
