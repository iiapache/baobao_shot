package baby

import (
	"errors"
)

var (
	ErrNotFound      = errors.New("baby not found")
	ErrNotMember     = errors.New("not a family member")
	ErrInvalidName   = errors.New("invalid baby name")
	ErrInvalidGender = errors.New("invalid gender")
	ErrInvalidBirth  = errors.New("invalid birth date")
	ErrBabyLimit     = errors.New("baby limit reached")
)

const (
	MaxAvatarBytes     = 5 << 20 // 5 MiB
	MaxBabiesPerFamily = 5       // product-config.yaml family.max_babies
)
