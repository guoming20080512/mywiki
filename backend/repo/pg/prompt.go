package pg

import (
	"context"
	"encoding/json"
	"errors"
	"strings"

	"gorm.io/gorm"

	"github.com/chaitin/panda-wiki/domain"
	"github.com/chaitin/panda-wiki/log"
	"github.com/chaitin/panda-wiki/store/pg"
)

type PromptRepo struct {
	db     *pg.DB
	logger *log.Logger
}

type promptJson struct {
	Content        string `json:"content"`
	SummaryContent string `json:"summary_content"`
}

func NewPromptRepo(db *pg.DB, logger *log.Logger) *PromptRepo {
	return &PromptRepo{
		db:     db,
		logger: logger,
	}
}

func (r *PromptRepo) GetPrompt(ctx context.Context, kbID string) (string, error) {
	var setting domain.Setting
	var prompt promptJson
	err := r.db.WithContext(ctx).Table("settings").
		Where("kb_id = ? AND key = ?", kbID, domain.SettingKeySystemPrompt).
		First(&setting).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return "", nil
		}
		return "", err
	}
	if err := json.Unmarshal(setting.Value, &prompt); err != nil {
		return "", err
	}
	return prompt.Content, nil
}

func (r *PromptRepo) GetSummaryPrompt(ctx context.Context, kbID string) (string, error) {
	var setting domain.Setting
	var prompt promptJson
	err := r.db.WithContext(ctx).Table("settings").
		Where("kb_id = ? AND key = ?", kbID, domain.SettingKeySystemPrompt).
		First(&setting).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return domain.SystemDefaultSummaryPrompt, nil
		}
		return "", err
	}
	if err := json.Unmarshal(setting.Value, &prompt); err != nil {
		return "", err
	}
	if strings.TrimSpace(prompt.SummaryContent) == "" {
		prompt.SummaryContent = domain.SystemDefaultSummaryPrompt
	}
	return prompt.SummaryContent, nil
}
