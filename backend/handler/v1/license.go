package v1

import (
	"mime/multipart"

	"github.com/labstack/echo/v4"

	"github.com/chaitin/panda-wiki/consts"
	"github.com/chaitin/panda-wiki/handler"
	"github.com/chaitin/panda-wiki/log"
	"github.com/chaitin/panda-wiki/middleware"
	"github.com/chaitin/panda-wiki/usecase"
)

type LicenseHandler struct {
	*handler.BaseHandler
	usecase *usecase.LicenseUsecase
	logger  *log.Logger
	auth    middleware.AuthMiddleware
}

func NewLicenseHandler(echo *echo.Echo, baseHandler *handler.BaseHandler, logger *log.Logger, usecase *usecase.LicenseUsecase, auth middleware.AuthMiddleware) *LicenseHandler {
	h := &LicenseHandler{
		BaseHandler: baseHandler,
		usecase:     usecase,
		logger:      logger.WithModule("handler.v1.license"),
		auth:        auth,
	}

	group := echo.Group("/api/v1/license")
	group.GET("", h.GetLicense, h.auth.Authorize)
	group.POST("", h.UploadLicense, h.auth.Authorize, h.auth.ValidateUserRole(consts.UserRoleAdmin))
	group.DELETE("", h.DeleteLicense, h.auth.Authorize, h.auth.ValidateUserRole(consts.UserRoleAdmin))

	return h
}

type UploadLicenseReq struct {
	LicenseType  string                `json:"license_type" form:"license_type"`
	LicenseCode  string                `json:"license_code" form:"license_code"`
	LicenseFile  *multipart.FileHeader `json:"license_file" form:"license_file"`
}

func (h *LicenseHandler) GetLicense(c echo.Context) error {
	resp, err := h.usecase.GetLicense(c.Request().Context())
	if err != nil {
		return h.NewResponseWithError(c, "failed to get license", err)
	}
	return h.NewResponseWithData(c, resp)
}

func (h *LicenseHandler) UploadLicense(c echo.Context) error {
	var req UploadLicenseReq
	if err := c.Bind(&req); err != nil {
		return h.NewResponseWithError(c, "invalid request", err)
	}

	var data []byte
	var licenseType string
	var licenseCode string

	if req.LicenseFile != nil {
		file, err := req.LicenseFile.Open()
		if err != nil {
			return h.NewResponseWithError(c, "failed to open license file", err)
		}
		defer file.Close()

		data = make([]byte, req.LicenseFile.Size)
		if _, err := file.Read(data); err != nil {
			return h.NewResponseWithError(c, "failed to read license file", err)
		}
		licenseType = "file"
	} else if req.LicenseCode != "" {
		data = []byte(req.LicenseCode)
		licenseType = "code"
	} else {
		return h.NewResponseWithError(c, "either license_code or license_file is required", nil)
	}

	resp, err := h.usecase.UploadLicense(c.Request().Context(), licenseType, licenseCode, data)
	if err != nil {
		return h.NewResponseWithError(c, "failed to upload license", err)
	}
	return h.NewResponseWithData(c, resp)
}

func (h *LicenseHandler) DeleteLicense(c echo.Context) error {
	err := h.usecase.DeleteLicense(c.Request().Context())
	if err != nil {
		return h.NewResponseWithError(c, "failed to delete license", err)
	}
	return h.NewResponseWithData(c, nil)
}
