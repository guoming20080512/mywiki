package usecase

import (
	"context"

	"github.com/chaitin/panda-wiki/domain"
	"github.com/chaitin/panda-wiki/log"
	"github.com/chaitin/panda-wiki/repo/pg"
)

type LicenseUsecase struct {
	repo   *pg.LicenseRepository
	logger *log.Logger
}

func NewLicenseUsecase(repo *pg.LicenseRepository, logger *log.Logger) *LicenseUsecase {
	return &LicenseUsecase{
		repo:   repo,
		logger: logger.WithModule("usecase.license"),
	}
}

func (u *LicenseUsecase) GetLicense(ctx context.Context) (*domain.LicenseResp, error) {
	license, err := u.repo.GetLicense(ctx)
	if err != nil {
		return nil, err
	}
	if license == nil {
		return &domain.LicenseResp{
			Edition: 3,
			State:   1,
		}, nil
	}

	resp := &domain.LicenseResp{
		Edition: 3,
		State:   1,
		Type:    license.Type,
		Code:    license.Code,
	}

	return resp, nil
}

func (u *LicenseUsecase) UploadLicense(ctx context.Context, licenseType, code string, data []byte) (*domain.LicenseResp, error) {
	license := &domain.License{
		Type:      licenseType,
		Code:      code,
		Data:      data,
	}

	if err := u.repo.CreateLicense(ctx, license); err != nil {
		return nil, err
	}

	return u.GetLicense(ctx)
}

func (u *LicenseUsecase) DeleteLicense(ctx context.Context) error {
	return u.repo.DeleteLicense(ctx)
}
