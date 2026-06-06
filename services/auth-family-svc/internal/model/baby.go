package model

import "time"

// BabyGender is the baby's gender.
type BabyGender string

const (
	BabyGenderMale    BabyGender = "male"
	BabyGenderFemale  BabyGender = "female"
	BabyGenderUnknown BabyGender = "unknown"
)

// Baby is a baby profile within a family.
type Baby struct {
	ID          string
	FamilyID    string
	Name        string
	FullName    *string
	Gender      BabyGender
	BirthDate   time.Time
	BirthTime   *time.Time
	BirthWeight *float64
	BirthLength *float64
	BirthPlace  *string
	Timezone    string
	AvatarURL   *string
	CreatedAt   time.Time
	UpdatedAt   time.Time
	DeletedAt   *time.Time
}
