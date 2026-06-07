package adreward

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/credit"
	"github.com/baobao/credit-sub-ad-svc/internal/model"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
	"github.com/google/uuid"
)

const ledgerRefKind = "ad_reward"

// Service grants incentivized ad rewards via client report and alliance callbacks.
type Service struct {
	rewards   store.AdRewardStore
	ledger    *credit.Service
	verifiers *Registry
	freq      *FreqGuard
	nonces    *NonceGuard
	credits   int64
	dailyCap  int
	now       func() time.Time
	newID     func() string
}

// Options configures ad reward behavior.
type Options struct {
	CreditsPerReward int64
	DailyLimit       int
	MinInterval      time.Duration
}

// NewService creates an ad reward service.
func NewService(st store.AdRewardStore, ledger *credit.Service, verifiers *Registry, opts Options) *Service {
	credits := opts.CreditsPerReward
	if credits <= 0 {
		credits = DefaultCreditsPerReward
	}
	daily := opts.DailyLimit
	if daily <= 0 {
		daily = DefaultDailyLimit
	}
	interval := opts.MinInterval
	if interval <= 0 {
		interval = 30 * time.Second
	}
	return &Service{
		rewards:   st,
		ledger:    ledger,
		verifiers: verifiers,
		freq:      NewFreqGuard(interval, daily),
		nonces:    NewNonceGuard(),
		credits:   credits,
		dailyCap:  daily,
		now:       time.Now,
		newID:     func() string { return "adr_" + uuid.NewString()[:12] },
	}
}

// SetFreqGuard overrides frequency limits (tests only).
func (s *Service) SetFreqGuard(guard *FreqGuard) {
	if guard != nil {
		s.freq = guard
	}
}

// SetNow overrides the clock (tests only).
func (s *Service) SetNow(fn func() time.Time) {
	if fn != nil {
		s.now = fn
	}
}

// SetNonceGuard overrides nonce validation (tests only).
func (s *Service) SetNonceGuard(guard *NonceGuard) {
	if guard != nil {
		s.nonces = guard
	}
}

// ClientRequest is the authenticated client report payload.
type ClientRequest struct {
	UserID      string
	Network     string
	PlacementID string
	TransID     string
	IDFV        string
	Nonce       string
	TimestampMs int64
}

// AllianceRequest is the server-to-server alliance callback payload.
type AllianceRequest struct {
	Network     string
	UserID      string
	PlacementID string
	TransID     string
	Sign        string
}

// Result is returned after a successful grant attempt.
type Result struct {
	GrantedCredits int64
	BalanceAfter   int64
	LedgerID       string
	Duplicate      bool
}

// ClientReport handles POST /v1/credits/ad-reward.
func (s *Service) ClientReport(ctx context.Context, req ClientRequest) (Result, error) {
	if err := s.validateClientRequest(req); err != nil {
		return Result{}, err
	}
	if err := s.nonces.Validate(req.Nonce, req.TimestampMs); err != nil {
		return Result{}, err
	}
	return s.grant(ctx, grantInput{
		userID:      req.UserID,
		network:     req.Network,
		placementID: req.PlacementID,
		signature:   req.TransID,
		idfv:        req.IDFV,
	})
}

// AllianceCallback handles alliance server callbacks with signature verification.
func (s *Service) AllianceCallback(ctx context.Context, req AllianceRequest) (Result, error) {
	if err := s.validateAllianceRequest(req); err != nil {
		return Result{}, err
	}
	if !s.verifiers.Verify(req.Network, req.TransID, req.UserID, req.Sign) {
		return Result{}, ErrInvalidSignature
	}
	return s.grant(ctx, grantInput{
		userID:      req.UserID,
		network:     req.Network,
		placementID: req.PlacementID,
		signature:   req.TransID,
	})
}

type grantInput struct {
	userID      string
	network     string
	placementID string
	signature   string
	idfv        string
}

func (s *Service) grant(ctx context.Context, in grantInput) (Result, error) {
	if s.rewards == nil || s.ledger == nil {
		return Result{}, ErrInvalidRequest
	}

	if existing, err := s.rewards.GetAdRewardByNetworkSig(ctx, in.network, in.signature); err == nil {
		return s.duplicateResult(ctx, existing)
	} else if !errors.Is(err, store.ErrNotFound) {
		return Result{}, err
	}

	now := s.now().UTC()
	count, err := s.rewards.CountAdRewardsByUserDay(ctx, in.userID, now)
	if err != nil {
		return Result{}, err
	}
	if err := s.freq.Check(now, in.userID, in.idfv, count); err != nil {
		return Result{}, err
	}

	reward := model.AdReward{
		ID:             s.newID(),
		UserID:         in.userID,
		Network:        in.network,
		PlacementID:    in.placementID,
		Signature:      in.signature,
		GrantedCredits: s.credits,
		CreatedAt:      now,
	}
	inserted, err := s.rewards.CreateAdReward(ctx, reward)
	if err != nil {
		return Result{}, err
	}
	if !inserted {
		existing, fetchErr := s.rewards.GetAdRewardByNetworkSig(ctx, in.network, in.signature)
		if fetchErr != nil {
			return Result{}, fetchErr
		}
		return s.duplicateResult(ctx, existing)
	}

	refID := model.AdRewardLedgerRefID(in.network, in.signature)
	grant, err := s.ledger.Grant(ctx, in.userID, s.credits, ledgerRefKind, refID)
	if err != nil {
		return Result{}, err
	}

	s.freq.Record(now, in.userID, in.idfv)

	granted := s.credits
	if grant.Duplicate {
		granted = 0
	}
	return Result{
		GrantedCredits: granted,
		BalanceAfter:   grant.Entry.BalanceAfter,
		LedgerID:       grant.Entry.ID,
		Duplicate:      grant.Duplicate,
	}, nil
}

func (s *Service) duplicateResult(ctx context.Context, existing *model.AdReward) (Result, error) {
	refID := model.AdRewardLedgerRefID(existing.Network, existing.Signature)
	grant, err := s.ledger.Grant(ctx, existing.UserID, s.credits, ledgerRefKind, refID)
	if err != nil {
		return Result{}, err
	}
	balance, balErr := s.ledger.GetBalance(ctx, existing.UserID)
	if balErr != nil {
		return Result{}, balErr
	}
	return Result{
		GrantedCredits: 0,
		BalanceAfter:   balance.Balance,
		LedgerID:       grant.Entry.ID,
		Duplicate:      true,
	}, nil
}

func (s *Service) validateClientRequest(req ClientRequest) error {
	if trim(req.UserID) == "" ||
		trim(req.Network) == "" ||
		trim(req.PlacementID) == "" ||
		trim(req.TransID) == "" ||
		trim(req.IDFV) == "" {
		return ErrInvalidRequest
	}
	return nil
}

func (s *Service) validateAllianceRequest(req AllianceRequest) error {
	if trim(req.Network) == "" ||
		trim(req.UserID) == "" ||
		trim(req.TransID) == "" ||
		trim(req.Sign) == "" {
		return ErrInvalidRequest
	}
	if trim(req.PlacementID) == "" {
		req.PlacementID = "default"
	}
	return nil
}

// NormalizeNetwork lowercases known network aliases.
func NormalizeNetwork(network string) string {
	switch strings.ToLower(trim(network)) {
	case "pangle", "csj", "穿山甲":
		return NetworkPangle
	case "gdt", "优量汇", "tencent":
		return NetworkGDT
	case "admob", "google":
		return NetworkAdMob
	default:
		return strings.ToLower(trim(network))
	}
}
