package dianyaapi

/*
#cgo CFLAGS: -I${SRCDIR}/../../include
#cgo linux LDFLAGS: -L${SRCDIR}/../../target/release -ldianyaapi_ffi
#cgo darwin LDFLAGS: -L${SRCDIR}/../../target/release -ldianyaapi_ffi
#cgo windows LDFLAGS: -L${SRCDIR}/../../target/release -ldianyaapi_ffi
#include "../../include/dianyaapi_ffi.h"
#include <stdlib.h>
*/
import "C"

import (
	"fmt"
	"unsafe"
)

// Client 封装 Dianya API 的所有 FFI 能力
type Client struct{}

// NewClient 创建新的 Dianya 客户端实例（无状态）
func NewClient() *Client {
	return &Client{}
}

// ErrorCode 错误码
type ErrorCode int32

const (
	ErrorSuccess      ErrorCode = 0
	ErrorWsError      ErrorCode = ErrorCode(C.WsError)
	ErrorHttpError    ErrorCode = ErrorCode(C.HttpError)
	ErrorServerError  ErrorCode = ErrorCode(C.ServerError)
	ErrorInvalidInput ErrorCode = ErrorCode(C.InvalidInput)
	ErrorInvalidResp  ErrorCode = ErrorCode(C.InvalidResponse)
	ErrorInvalidToken ErrorCode = ErrorCode(C.InvalidToken)
	ErrorInvalidAPI   ErrorCode = ErrorCode(C.InvalidApiKey)
	ErrorJsonError    ErrorCode = ErrorCode(C.JsonError)
	ErrorOtherError   ErrorCode = ErrorCode(C.OtherError)
)

// UploadResponse 上传响应
type UploadResponse struct {
	// 普通模式
	TaskID string `json:"task_id,omitempty"`
	// 一句话模式
	Status  string `json:"status,omitempty"`
	Message string `json:"message,omitempty"`
	Data    string `json:"data,omitempty"`
}

// TranslateResponse 文本翻译响应
type TranslateResponse struct {
	Status string `json:"status"`
	Data   string `json:"data"`
}

// SessionResponse 会话创建响应
type SessionResponse struct {
	TaskID    string `json:"task_id"`
	SessionID string `json:"session_id"`
	UsageID   string `json:"usage_id"`
	MaxTime   int    `json:"max_time"`
}

// SessionCloseResult 会话关闭结果
type SessionCloseResult struct {
	Status    string  `json:"status"`
	Duration  *int    `json:"duration,omitempty"`
	ErrorCode *int    `json:"error_code,omitempty"`
	Message   *string `json:"message,omitempty"`
}

// StatusResponse 转写任务状态
type StatusResponse struct {
	Status          string
	OverviewMD      *string
	SummaryMD       *string
	Message         *string
	UsageID         *string
	TaskID          *string
	Keywords        []string
	CallbackHistory []CallbackHistory
	TaskType        *string
}

// CallbackHistory 状态回调历史
type CallbackHistory struct {
	Timestamp string
	Status    string
	Code      uint32
}

// ShareLinkResponse 分享链接结果
type ShareLinkResponse struct {
	ShareURL      string
	ExpirationDay int
	ExpiredAt     string
}

// SummaryResponse 总结任务结果
type SummaryResponse struct {
	TaskID string
}

// Utterance 转写段落
type Utterance struct {
	StartTime float64
	EndTime   float64
	Speaker   int32
	Text      string
}

// UtteranceTranslatorResponse Utterance 翻译响应
type UtteranceTranslatorResponse struct {
	Status string
	Lang   string
}

// TranscribeTranslatorResponse 转写翻译结果
type TranscribeTranslatorResponse struct {
	TaskID     string
	TaskType   string
	Status     string
	Lang       string
	Message    *string
	OverviewMD *string
	SummaryMD  *string
	Keywords   *[]string
}

func ffiError(code C.int, err *C.FfiError, context string) error {
	if code == 0 {
		return nil
	}

	var msg string
	if err != nil && err.message != nil {
		msg = C.GoString(err.message)
		C.transcribe_ffi_free_error(err)
	} else {
		msg = fmt.Sprintf("%s failed with error code: %d", context, int(code))
	}
	return fmt.Errorf(msg)
}

func toCString(str string) *C.char {
	if str == "" {
		return nil
	}
	return C.CString(str)
}

func goString(ptr *C.char) *string {
	if ptr == nil {
		return nil
	}
	s := C.GoString(ptr)
	return &s
}

func languageCode(lang C.FfiLanguage) string {
	switch lang {
	case C.ChineseSimplified:
		return "zh"
	case C.EnglishUS:
		return "en"
	case C.Japanese:
		return "ja"
	case C.Korean:
		return "ko"
	case C.French:
		return "fr"
	case C.German:
		return "de"
	default:
		return ""
	}
}

func buildFfiUtterances(utterances []Utterance) ([]C.FfiUtterance, func()) {
	if len(utterances) == 0 {
		return nil, func() {}
	}

	cUtterances := make([]C.FfiUtterance, len(utterances))
	cStrings := make([]*C.char, len(utterances))

	for i, u := range utterances {
		text := C.CString(u.Text)
		cStrings[i] = text
		cUtterances[i].start_time = C.double(u.StartTime)
		cUtterances[i].end_time = C.double(u.EndTime)
		cUtterances[i].speaker = C.int32_t(u.Speaker)
		cUtterances[i].text = text
	}

	cleanup := func() {
		for _, ptr := range cStrings {
			if ptr != nil {
				C.free(unsafe.Pointer(ptr))
			}
		}
	}

	return cUtterances, cleanup
}

// Export 导出转写/总结内容
func (c *Client) Export(token, taskID, exportType, exportFormat string) ([]byte, error) {
	cTaskID := C.CString(taskID)
	defer C.free(unsafe.Pointer(cTaskID))

	cType := C.CString(exportType)
	defer C.free(unsafe.Pointer(cType))

	cFormat := C.CString(exportFormat)
	defer C.free(unsafe.Pointer(cFormat))

	cToken := C.CString(token)
	defer C.free(unsafe.Pointer(cToken))

	bufSize := 1024 * 1024
	resultBuf := make([]byte, bufSize)
	resultLen := C.size_t(bufSize)

	var cError C.FfiError
	code := C.transcribe_ffi_export(
		cTaskID,
		cType,
		cFormat,
		cToken,
		(*C.uint8_t)(unsafe.Pointer(&resultBuf[0])),
		(*C.size_t)(unsafe.Pointer(&resultLen)),
		&cError,
	)

	if err := ffiError(code, &cError, "export"); err != nil {
		return nil, err
	}

	return resultBuf[:resultLen], nil
}

// GetShareLink 获取分享链接
func (c *Client) GetShareLink(token, taskID string, expirationDay int) (*ShareLinkResponse, error) {
	cTaskID := C.CString(taskID)
	defer C.free(unsafe.Pointer(cTaskID))

	cToken := C.CString(token)
	defer C.free(unsafe.Pointer(cToken))

	var cLink C.FfiShareLink
	var cError C.FfiError

	code := C.transcribe_ffi_get_share_link(
		cTaskID,
		C.int32_t(expirationDay),
		cToken,
		&cLink,
		&cError,
	)

	if err := ffiError(code, &cError, "get_share_link"); err != nil {
		return nil, err
	}

	resp := &ShareLinkResponse{
		ShareURL:      C.GoString(cLink.share_url),
		ExpirationDay: int(cLink.expiration_day),
		ExpiredAt:     C.GoString(cLink.expired_at),
	}
	C.transcribe_ffi_free_share_link(&cLink)
	return resp, nil
}

// GetStatus 获取转写任务状态
func (c *Client) GetStatus(token, taskID, shareID string) (*StatusResponse, error) {
	cToken := C.CString(token)
	defer C.free(unsafe.Pointer(cToken))

	var cTaskID, cShareID *C.char
	if taskID != "" {
		cTaskID = C.CString(taskID)
		defer C.free(unsafe.Pointer(cTaskID))
	}
	if shareID != "" {
		cShareID = C.CString(shareID)
		defer C.free(unsafe.Pointer(cShareID))
	}

	var cStatus C.FfiTranscribeStatus
	var cError C.FfiError

	code := C.transcribe_ffi_get_status(
		cTaskID,
		cShareID,
		cToken,
		&cStatus,
		&cError,
	)

	if err := ffiError(code, &cError, "get_status"); err != nil {
		return nil, err
	}

	resp := &StatusResponse{
		Status: C.GoString(cStatus.status),
	}
	resp.OverviewMD = goString(cStatus.overview_md)
	resp.SummaryMD = goString(cStatus.summary_md)
	resp.Message = goString(cStatus.message)
	resp.UsageID = goString(cStatus.usage_id)
	resp.TaskID = goString(cStatus.task_id)

	if cStatus.keywords_len > 0 && cStatus.keywords != nil {
		n := int(cStatus.keywords_len)
		slice := (*[1 << 30]*C.char)(unsafe.Pointer(cStatus.keywords))[:n:n]
		for _, ptr := range slice {
			if ptr != nil {
				resp.Keywords = append(resp.Keywords, C.GoString(ptr))
			}
		}
	}

	if cStatus.callback_history_len > 0 && cStatus.callback_history != nil {
		n := int(cStatus.callback_history_len)
		slice := (*[1 << 30]C.FfiCallbackHistory)(unsafe.Pointer(cStatus.callback_history))[:n:n]
		for _, item := range slice {
			resp.CallbackHistory = append(resp.CallbackHistory, CallbackHistory{
				Timestamp: C.GoString(item.timestamp),
				Status:    C.GoString(item.status),
				Code:      uint32(item.code),
			})
		}
	}

	if cStatus.has_task_type {
		t := cStatus.task_type
		var val string
		switch t {
		case C.NormalQuality:
			val = "normal_quality"
		case C.NormalSpeed:
			val = "normal_speed"
		case C.ShortAsrQuality:
			val = "short_asr_quality"
		case C.ShortAsrSpeed:
			val = "short_asr_speed"
		default:
			val = "unknown"
		}
		resp.TaskType = &val
	}

	C.transcribe_ffi_free_transcribe_status(&cStatus)
	return resp, nil
}

// CreateSummary 创建总结任务
func (c *Client) CreateSummary(token string, utterances []Utterance) (*SummaryResponse, error) {
	if len(utterances) == 0 {
		return nil, fmt.Errorf("utterances cannot be empty")
	}

	cToken := C.CString(token)
	defer C.free(unsafe.Pointer(cToken))

	cUtterances, cleanup := buildFfiUtterances(utterances)
	defer cleanup()

	var cSummary C.FfiSummaryCreator
	var cError C.FfiError

	code := C.transcribe_ffi_create_summary(
		(*C.FfiUtterance)(unsafe.Pointer(&cUtterances[0])),
		C.uintptr_t(len(cUtterances)),
		cToken,
		&cSummary,
		&cError,
	)

	if err := ffiError(code, &cError, "create_summary"); err != nil {
		return nil, err
	}

	resp := &SummaryResponse{TaskID: C.GoString(cSummary.task_id)}
	C.transcribe_ffi_free_summary_creator(&cSummary)
	return resp, nil
}

// Upload 上传音频文件
func (c *Client) Upload(token, filepath string, transcribeOnly, shortASR bool, model string) (*UploadResponse, error) {
	cFile := C.CString(filepath)
	defer C.free(unsafe.Pointer(cFile))

	cModel := C.CString(model)
	defer C.free(unsafe.Pointer(cModel))

	cToken := C.CString(token)
	defer C.free(unsafe.Pointer(cToken))

	var cResp C.FfiUploadResponse
	var cError C.FfiError

	code := C.transcribe_ffi_upload(
		cFile,
		C.bool(transcribeOnly),
		C.bool(shortASR),
		cModel,
		cToken,
		&cResp,
		&cError,
	)

	if err := ffiError(code, &cError, "upload"); err != nil {
		C.transcribe_ffi_free_upload_response(&cResp)
		return nil, err
	}

	resp := &UploadResponse{}
	if !cResp.is_normal {
		resp.Status = C.GoString(cResp.one_sentence.status)
		resp.Message = C.GoString(cResp.one_sentence.message)
		resp.Data = C.GoString(cResp.one_sentence.data)
	} else {
		resp.TaskID = C.GoString(cResp.normal.task_id)
	}
	C.transcribe_ffi_free_upload_response(&cResp)
	return resp, nil
}

// TranslateText 翻译文本
func (c *Client) TranslateText(token, text, targetLang string) (*TranslateResponse, error) {
	cText := C.CString(text)
	defer C.free(unsafe.Pointer(cText))

	cLang := C.CString(targetLang)
	defer C.free(unsafe.Pointer(cLang))

	cToken := C.CString(token)
	defer C.free(unsafe.Pointer(cToken))

	var cResp C.FfiTextTranslator
	var cError C.FfiError

	code := C.transcribe_ffi_translate_text(
		cText,
		cLang,
		cToken,
		&cResp,
		&cError,
	)

	if err := ffiError(code, &cError, "translate_text"); err != nil {
		C.transcribe_ffi_free_text_translator(&cResp)
		return nil, err
	}

	resp := &TranslateResponse{
		Status: C.GoString(cResp.status),
		Data:   C.GoString(cResp.data),
	}
	C.transcribe_ffi_free_text_translator(&cResp)
	return resp, nil
}

// TranslateUtterance 翻译 Utterances
func (c *Client) TranslateUtterance(token string, utterances []Utterance, targetLang string) (*UtteranceTranslatorResponse, error) {
	if len(utterances) == 0 {
		return nil, fmt.Errorf("utterances cannot be empty")
	}

	cLang := C.CString(targetLang)
	defer C.free(unsafe.Pointer(cLang))

	cToken := C.CString(token)
	defer C.free(unsafe.Pointer(cToken))

	cUtterances, cleanup := buildFfiUtterances(utterances)
	defer cleanup()

	var cResp C.FfiUtteranceTranslator
	var cError C.FfiError

	code := C.transcribe_ffi_translate_utterance(
		(*C.FfiUtterance)(unsafe.Pointer(&cUtterances[0])),
		C.uintptr_t(len(cUtterances)),
		cLang,
		cToken,
		&cResp,
		&cError,
	)

	if err := ffiError(code, &cError, "translate_utterance"); err != nil {
		C.transcribe_ffi_free_utterance_translator(&cResp)
		return nil, err
	}

	resp := &UtteranceTranslatorResponse{
		Status: C.GoString(cResp.status),
		Lang:   languageCode(C.FfiLanguage(cResp.lang)),
	}
	C.transcribe_ffi_free_utterance_translator(&cResp)
	return resp, nil
}

// TranslateTranscribe 获取转写任务的翻译结果
func (c *Client) TranslateTranscribe(token, taskID, targetLang string) (*TranscribeTranslatorResponse, error) {
	cTaskID := C.CString(taskID)
	defer C.free(unsafe.Pointer(cTaskID))

	cLang := C.CString(targetLang)
	defer C.free(unsafe.Pointer(cLang))

	cToken := C.CString(token)
	defer C.free(unsafe.Pointer(cToken))

	var cResp C.FfiTranscribeTranslator
	var cError C.FfiError

	code := C.transcribe_ffi_translate_transcribe(
		cTaskID,
		cLang,
		cToken,
		&cResp,
		&cError,
	)

	if err := ffiError(code, &cError, "translate_transcribe"); err != nil {
		C.transcribe_ffi_free_transcribe_translator(&cResp)
		return nil, err
	}

	resp := &TranscribeTranslatorResponse{
		TaskID: C.GoString(cResp.task_id),
		Status: C.GoString(cResp.status),
		Lang:   languageCode(C.FfiLanguage(cResp.lang)),
	}

	switch cResp.task_type {
	case C.Transcribe:
		resp.TaskType = "transcribe"
	case C.Summary:
		resp.TaskType = "summary"
	default:
		resp.TaskType = ""
	}

	resp.Message = goString(cResp.message)
	resp.OverviewMD = goString(cResp.overview_md)
	resp.SummaryMD = goString(cResp.summary_md)

	if cResp.keywords != nil && cResp.keywords_len > 0 {
		n := int(cResp.keywords_len)
		slice := (*[1 << 30]*C.char)(unsafe.Pointer(cResp.keywords))[:n:n]
		values := make([]string, 0, n)
		for _, ptr := range slice {
			if ptr != nil {
				values = append(values, C.GoString(ptr))
			}
		}
		resp.Keywords = &values
	}

	C.transcribe_ffi_free_transcribe_translator(&cResp)
	return resp, nil
}
