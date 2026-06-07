package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
	"github.com/lib/pq"
)

func (s *PostgresStore) GetIAPReceiptByTransactionID(ctx context.Context, transactionID string) (*model.IAPReceipt, error) {
	const q = `
SELECT id, user_id, transaction_id, original_transaction_id, product_id, signed_payload, verified_at, status
FROM iap_receipts
WHERE transaction_id = $1`
	row := s.db.QueryRowContext(ctx, q, transactionID)
	receipt, err := scanIAPReceipt(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return receipt, err
}

func (s *PostgresStore) CreateIAPReceipt(ctx context.Context, receipt model.IAPReceipt) error {
	const q = `
INSERT INTO iap_receipts (
	id, user_id, transaction_id, original_transaction_id, product_id, signed_payload, verified_at, status
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`
	_, err := s.db.ExecContext(ctx, q,
		receipt.ID,
		receipt.UserID,
		receipt.TransactionID,
		receipt.OriginalTransactionID,
		receipt.ProductID,
		receipt.SignedPayload,
		receipt.VerifiedAt.UTC(),
		string(receipt.Status),
	)
	if err != nil {
		var pqErr *pq.Error
		if errors.As(err, &pqErr) && pqErr.Code == "23505" {
			return ErrDuplicateTransaction
		}
		return fmt.Errorf("insert iap receipt: %w", err)
	}
	return nil
}

func scanIAPReceipt(row rowScanner) (*model.IAPReceipt, error) {
	var receipt model.IAPReceipt
	var status string
	if err := row.Scan(
		&receipt.ID,
		&receipt.UserID,
		&receipt.TransactionID,
		&receipt.OriginalTransactionID,
		&receipt.ProductID,
		&receipt.SignedPayload,
		&receipt.VerifiedAt,
		&status,
	); err != nil {
		return nil, err
	}
	receipt.Status = model.IAPReceiptStatus(status)
	receipt.VerifiedAt = receipt.VerifiedAt.UTC()
	return &receipt, nil
}
