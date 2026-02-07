package domain

const (
	Bucket = "static-file"
)

type ObjectUploadResp struct {
	Key      string `json:"key"`
	Filename string `json:"filename"`
}

type AnydocUploadResp struct {
	Code uint   `json:"code"`
	Err  string `json:"err"`
	Data string `json:"data"`
}
