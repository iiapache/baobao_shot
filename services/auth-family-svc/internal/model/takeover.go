package model

import "time"

// TakeoverVoteStatus is the lifecycle state of an admin takeover vote.
type TakeoverVoteStatus string

const (
	TakeoverStatusVoting          TakeoverVoteStatus = "voting"
	TakeoverStatusObjectionPeriod TakeoverVoteStatus = "objection_period"
	TakeoverStatusCompleted       TakeoverVoteStatus = "completed"
	TakeoverStatusCancelled       TakeoverVoteStatus = "cancelled"
	TakeoverStatusRejected        TakeoverVoteStatus = "rejected"
)

// TakeoverBallotChoice is a member ballot on a takeover vote.
type TakeoverBallotChoice string

const (
	TakeoverBallotApprove TakeoverBallotChoice = "approve"
	TakeoverBallotReject  TakeoverBallotChoice = "reject"
)

// TakeoverVote records an in-flight admin takeover for a family.
type TakeoverVote struct {
	ID              string
	FamilyID        string
	InitiatorUserID string
	Status          TakeoverVoteStatus
	OpensAt         time.Time
	EndsAt          *time.Time
	CompletedAt     *time.Time
	CreatedAt       time.Time
}

// TakeoverBallot records one member vote on a takeover.
type TakeoverBallot struct {
	VoteID   string
	UserID   string
	Choice   TakeoverBallotChoice
	VotedAt  time.Time
}
