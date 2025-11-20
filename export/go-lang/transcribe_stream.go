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
	"time"
	"unsafe"
)

// CreateSession 创建实时转写会话
func CreateSession(model, token string) (*SessionResponse, error) {
	cModel := C.CString(model)
	defer C.free(unsafe.Pointer(cModel))

	cToken := C.CString(token)
	defer C.free(unsafe.Pointer(cToken))

	var cSession C.FfiSessionCreator
	var cError C.FfiError

	code := C.transcribe_ffi_create_session(
		cModel,
		cToken,
		&cSession,
		&cError,
	)

	if err := ffiError(code, &cError, "create_session"); err != nil {
		C.transcribe_ffi_free_session_creator(&cSession)
		return nil, err
	}

	resp := &SessionResponse{
		TaskID:    C.GoString(cSession.task_id),
		SessionID: C.GoString(cSession.session_id),
		UsageID:   C.GoString(cSession.usage_id),
		MaxTime:   int(cSession.max_time),
	}
	C.transcribe_ffi_free_session_creator(&cSession)
	return resp, nil
}

// CloseSession 关闭实时转写会话
func CloseSession(taskID, token string, timeout time.Duration) (*SessionCloseResult, error) {
	cTaskID := C.CString(taskID)
	defer C.free(unsafe.Pointer(cTaskID))

	cToken := C.CString(token)
	defer C.free(unsafe.Pointer(cToken))

	var seconds C.uint64_t
	if timeout <= 0 {
		seconds = 0
	} else {
		seconds = C.uint64_t(timeout / time.Second)
		if seconds == 0 {
			seconds = 1
		}
	}

	var cEnd C.FfiSessionEnder
	var cError C.FfiError

	code := C.transcribe_ffi_close_session(
		cTaskID,
		cToken,
		seconds,
		&cEnd,
		&cError,
	)

	if err := ffiError(code, &cError, "close_session"); err != nil {
		C.transcribe_ffi_free_session_ender(&cEnd)
		return nil, err
	}

	resp := &SessionCloseResult{
		Status: C.GoString(cEnd.status),
		Message: func() *string {
			if cEnd.message == nil {
				return nil
			}
			msg := C.GoString(cEnd.message)
			return &msg
		}(),
	}
	if cEnd.has_duration {
		val := int(cEnd.duration)
		resp.Duration = &val
	}
	if cEnd.has_error_code {
		val := int(cEnd.error_code)
		resp.ErrorCode = &val
	}

	C.transcribe_ffi_free_session_ender(&cEnd)
	return resp, nil
}

// Stream 封装实时转写的 WebSocket 连接
type Stream struct {
	handle *C.TranscribeStream
}

// NewStream 从 sessionID 创建流式转写连接
func NewStream(sessionID string) (*Stream, error) {
	if sessionID == "" {
		return nil, fmt.Errorf("sessionID cannot be empty")
	}

	cSession := C.CString(sessionID)
	defer C.free(unsafe.Pointer(cSession))

	var handle *C.TranscribeStream
	var cError C.FfiError
	code := C.transcribe_ffi_ws_create(cSession, &handle, &cError)

	if err := ffiError(code, &cError, "ws_create"); err != nil {
		return nil, err
	}

	return &Stream{handle: handle}, nil
}

// Start 启动 WebSocket
func (s *Stream) Start() error {
	if s == nil || s.handle == nil {
		return fmt.Errorf("stream handle is nil")
	}
	var cError C.FfiError
	code := C.transcribe_ffi_ws_start(s.handle, &cError)
	return ffiError(code, &cError, "ws_start")
}

// Stop 停止 WebSocket（不释放内存）
func (s *Stream) Stop() error {
	if s == nil || s.handle == nil {
		return fmt.Errorf("stream handle is nil")
	}
	var cError C.FfiError
	code := C.transcribe_ffi_ws_stop(s.handle, &cError)
	return ffiError(code, &cError, "ws_stop")
}

// SendText 发送文本数据
func (s *Stream) SendText(text string) error {
	if s == nil || s.handle == nil {
		return fmt.Errorf("stream handle is nil")
	}
	cText := C.CString(text)
	defer C.free(unsafe.Pointer(cText))

	var cError C.FfiError
	code := C.transcribe_ffi_ws_write_txt(s.handle, cText, &cError)
	return ffiError(code, &cError, "ws_write_txt")
}

// SendBytes 发送二进制音频数据
func (s *Stream) SendBytes(data []byte) error {
	if s == nil || s.handle == nil {
		return fmt.Errorf("stream handle is nil")
	}
	if len(data) == 0 {
		return nil
	}

	var cError C.FfiError
	code := C.transcribe_ffi_ws_write_bytes(
		s.handle,
		(*C.uint8_t)(unsafe.Pointer(&data[0])),
		C.size_t(len(data)),
		&cError,
	)
	return ffiError(code, &cError, "ws_write_bytes")
}

// Receive 读取一条消息
// 返回值：(message, ok, error) 。ok=false 表示超时或无消息。
func (s *Stream) Receive(timeout time.Duration) (string, bool, error) {
	if s == nil || s.handle == nil {
		return "", false, fmt.Errorf("stream handle is nil")
	}

	buffer := make([]byte, 64*1024)
	length := C.size_t(len(buffer))

	var timeoutMS C.uint64_t
	if timeout > 0 {
		timeoutMS = C.uint64_t(timeout / time.Millisecond)
	} else {
		timeoutMS = 0
	}

	var cError C.FfiError
	code := C.transcribe_ffi_ws_receive(
		s.handle,
		(*C.char)(unsafe.Pointer(&buffer[0])),
		(*C.size_t)(unsafe.Pointer(&length)),
		timeoutMS,
		&cError,
	)
	if err := ffiError(code, &cError, "ws_receive"); err != nil {
		return "", false, err
	}

	if length == 0 {
		return "", false, nil
	}
	msg := C.GoStringN((*C.char)(unsafe.Pointer(&buffer[0])), C.int(length))
	return msg, true, nil
}

// Close 释放 WebSocket 资源
func (s *Stream) Close() {
	if s == nil || s.handle == nil {
		return
	}
	C.transcribe_ffi_ws_free(s.handle)
	s.handle = nil
}
