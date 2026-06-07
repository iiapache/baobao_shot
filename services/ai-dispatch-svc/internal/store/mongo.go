package store

import (
	"context"
	"fmt"
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/config"
	"github.com/baobao/ai-dispatch-svc/internal/model"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// index definitions per design-backend §4.2
var taskIndexes = []mongo.IndexModel{
	{
		Keys:    bson.D{{Key: "userId", Value: 1}, {Key: "createdAt", Value: -1}},
		Options: options.Index().SetName("idx_user_created"),
	},
	{
		Keys:    bson.D{{Key: "state", Value: 1}, {Key: "createdAt", Value: 1}},
		Options: options.Index().SetName("idx_state_created"),
	},
	{
		Keys:    bson.D{{Key: "input.sha256", Value: 1}},
		Options: options.Index().SetName("idx_input_sha256"),
	},
	{
		Keys:    bson.D{{Key: "creditHoldId", Value: 1}},
		Options: options.Index().SetName("idx_credit_hold"),
	},
}

// MongoTaskStore persists tasks in MongoDB ai_tasks collection.
type MongoTaskStore struct {
	client *mongo.Client
	coll   *mongo.Collection
}

// NewMongoTaskStore connects to MongoDB and ensures indexes.
func NewMongoTaskStore(cfg *config.Config) (*MongoTaskStore, error) {
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

	coll := client.Database(cfg.MongoDatabase).Collection(model.CollectionName)
	if _, err := coll.Indexes().CreateMany(ctx, taskIndexes); err != nil {
		_ = client.Disconnect(ctx)
		return nil, fmt.Errorf("create indexes: %w", err)
	}

	return &MongoTaskStore{client: client, coll: coll}, nil
}

// Create inserts a task document.
func (s *MongoTaskStore) Create(ctx context.Context, task *model.Task) error {
	if task == nil || task.ID == "" {
		return fmt.Errorf("task id required")
	}
	_, err := s.coll.InsertOne(ctx, task)
	return err
}

// GetByID loads a task by _id.
func (s *MongoTaskStore) GetByID(ctx context.Context, id string) (*model.Task, error) {
	var task model.Task
	err := s.coll.FindOne(ctx, bson.M{"_id": id}).Decode(&task)
	if err != nil {
		return nil, err
	}
	return &task, nil
}

// UpdateState updates state and appends history entry.
func (s *MongoTaskStore) UpdateState(ctx context.Context, id string, state string, at time.Time) error {
	return s.UpdateTask(ctx, id, TaskPatch{State: state, UpdatedAt: at})
}

// UpdateTask applies partial updates to a task document.
func (s *MongoTaskStore) UpdateTask(ctx context.Context, id string, patch TaskPatch) error {
	set := bson.M{}
	if patch.State != "" {
		set["state"] = patch.State
	}
	if patch.Model != nil {
		set["model"] = *patch.Model
	}
	if patch.ModelRetryCount != nil {
		set["modelRetryCount"] = *patch.ModelRetryCount
	}
	if patch.Output != nil {
		set["output"] = *patch.Output
	}
	if patch.DeepSynth != nil {
		set["deepSynth"] = *patch.DeepSynth
	}
	if !patch.UpdatedAt.IsZero() {
		set["updatedAt"] = patch.UpdatedAt
	}

	update := bson.M{}
	if len(set) > 0 {
		update["$set"] = set
	}
	if patch.State != "" {
		at := patch.UpdatedAt
		if at.IsZero() {
			at = time.Now().UTC()
		}
		entry := model.StateHistoryEntry{State: patch.State, At: at}
		if update["$push"] == nil {
			update["$push"] = bson.M{}
		}
		update["$push"].(bson.M)["stateHistory"] = entry
	}
	if patch.AppendInvocation != nil {
		if update["$push"] == nil {
			update["$push"] = bson.M{}
		}
		update["$push"].(bson.M)["modelInvocations"] = *patch.AppendInvocation
	}
	if len(update) == 0 {
		return nil
	}
	_, err := s.coll.UpdateByID(ctx, id, update)
	return err
}

// Close disconnects the Mongo client.
func (s *MongoTaskStore) Close(ctx context.Context) error {
	if s.client == nil {
		return nil
	}
	return s.client.Disconnect(ctx)
}

// IndexModels exports index definitions for documentation and migration tools.
func IndexModels() []mongo.IndexModel {
	return taskIndexes
}
