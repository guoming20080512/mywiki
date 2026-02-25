package pg

import (
	"context"
	"errors"

	"github.com/chaitin/panda-wiki/domain"
	"github.com/chaitin/panda-wiki/log"
	"github.com/chaitin/panda-wiki/store/pg"

	"gorm.io/gorm"
)

type LicenseRepository struct {
	db     *pg.DB
	logger *log.Logger
}

func NewLicenseRepository(db *pg.DB, logger *log.Logger) *LicenseRepository {
	return &LicenseRepository{
		db:     db,
		logger: logger.WithModule("repo.pg.license"),
	}
}

func (r *LicenseRepository) GetLicense(ctx context.Context) (*domain.License, error) {
	var license domain.License
	err := r.db.WithContext(ctx).Order("id DESC").First(&license).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &license, nil
}

func (r *LicenseRepository) CreateLicense(ctx context.Context, license *domain.License) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Delete(&domain.License{}).Error; err != nil {
			return err
		}
		return tx.Create(license).Error
	})
}

func (r *LicenseRepository) DeleteLicense(ctx context.Context) error {
	return r.db.WithContext(ctx).Delete(&domain.License{}).Error
}
