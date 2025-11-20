/* DianyaAPI FFI Bindings for Go/C */

#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

typedef enum ErrorCode {
  WsError = 1,
  HttpError = 2,
  ServerError = 3,
  InvalidInput = 4,
  InvalidResponse = 5,
  InvalidToken = 6,
  InvalidApiKey = 7,
  JsonError = 8,
  OtherError = 9,
} ErrorCode;

/**
 * 状态中任务类型
 */
typedef enum FfiTranscribeTaskType {
  NormalQuality,
  NormalSpeed,
  ShortAsrQuality,
  ShortAsrSpeed,
} FfiTranscribeTaskType;

/**
 * 翻译语言
 */
typedef enum FfiLanguage {
  ChineseSimplified,
  EnglishUS,
  Japanese,
  Korean,
  French,
  German,
} FfiLanguage;

/**
 * 翻译任务类型（转写 / 总结）
 */
typedef enum FfiTranslateTaskType {
  Transcribe,
  Summary,
} FfiTranslateTaskType;

typedef struct FfiCallbackRequest FfiCallbackRequest;

/**
 * WebSocket 连接信息，包含连接实例和订阅流
 * 注意：这是一个不透明的指针类型，C 代码不应该直接访问其内部字段
 */
typedef struct TranscribeStream TranscribeStream;

/**
 * FFI 错误信息结构体
 */
typedef struct FfiError {
  /**
   * 错误码
   */
  enum ErrorCode code;
  /**
   * 错误信息（C 字符串，可能为 null）
   */
  char *message;
} FfiError;

/**
 * 分享链接结果
 */
typedef struct FfiShareLink {
  char *share_url;
  int32_t expiration_day;
  char *expired_at;
} FfiShareLink;

/**
 * Utterance 映射到 C 结构体
 */
typedef struct FfiUtterance {
  double start_time;
  double end_time;
  int32_t speaker;
  char *text;
} FfiUtterance;

/**
 * 回调历史
 */
typedef struct FfiCallbackHistory {
  char *timestamp;
  char *status;
  uint32_t code;
} FfiCallbackHistory;

/**
 * 转写状态
 */
typedef struct FfiTranscribeStatus {
  char *status;
  char *overview_md;
  char *summary_md;
  struct FfiUtterance *details;
  uintptr_t details_len;
  char *message;
  char *usage_id;
  char *task_id;
  char **keywords;
  uintptr_t keywords_len;
  struct FfiCallbackHistory *callback_history;
  uintptr_t callback_history_len;
  enum FfiTranscribeTaskType task_type;
  bool has_task_type;
} FfiTranscribeStatus;

/**
 * 创建总结任务结果
 */
typedef struct FfiSummaryCreator {
  char *task_id;
} FfiSummaryCreator;

/**
 * 上传结果 - 普通模式
 */
typedef struct FfiUploadNormal {
  char *task_id;
} FfiUploadNormal;

/**
 * 上传结果 - 一句话模式
 */
typedef struct FfiUploadOneSentence {
  char *status;
  char *message;
  char *data;
} FfiUploadOneSentence;

/**
 * 上传结果总览
 */
typedef struct FfiUploadResponse {
  bool is_normal;
  struct FfiUploadNormal normal;
  struct FfiUploadOneSentence one_sentence;
} FfiUploadResponse;

/**
 * 文本翻译结果
 */
typedef struct FfiTextTranslator {
  char *status;
  char *data;
} FfiTextTranslator;

/**
 * Utterance 翻译结果
 */
typedef struct FfiUtteranceTranslator {
  char *status;
  enum FfiLanguage lang;
  struct FfiUtterance *details;
  uintptr_t details_len;
} FfiUtteranceTranslator;

/**
 * 具体翻译详情（单条）
 */
typedef struct FfiTranslateDetail {
  struct FfiUtterance utterance;
  char *translation;
} FfiTranslateDetail;

/**
 * 转写翻译结果
 */
typedef struct FfiTranscribeTranslator {
  char *task_id;
  enum FfiTranslateTaskType task_type;
  char *status;
  enum FfiLanguage lang;
  char *message;
  struct FfiTranslateDetail *details;
  uintptr_t details_len;
  char *overview_md;
  char *summary_md;
  char **keywords;
  uintptr_t keywords_len;
} FfiTranscribeTranslator;

/**
 * 转写状态回调响应
 */
typedef struct FfiCallbackResponse {
  char *status;
} FfiCallbackResponse;

/**
 * Session 创建结果
 */
typedef struct FfiSessionCreator {
  char *task_id;
  char *session_id;
  char *usage_id;
  int32_t max_time;
} FfiSessionCreator;

/**
 * Session 关闭结果
 */
typedef struct FfiSessionEnder {
  char *status;
  int32_t duration;
  bool has_duration;
  int32_t error_code;
  bool has_error_code;
  char *message;
} FfiSessionEnder;

void transcribe_ffi_free_error(struct FfiError *e);

/**
 * 导出转写内容或总结内容
 *
 * # 参数
 * - `task_id`: 任务ID（C 字符串）
 * - `export_type`: 导出类型字符串（"transcript", "overview", "summary"）
 * - `export_format`: 导出格式字符串（"pdf", "txt", "docx"）
 * - `token`: Bearer token（C 字符串）
 * - `result_data`: 输出二进制数据的缓冲区指针
 * - `result_len`: 输入时为缓冲区大小，输出时为实际长度
 * - `out_error`: 错误信息输出指针，如果为 null 则不填充错误信息
 * # 返回
 * 错误码（0 表示成功）
 */
int transcribe_ffi_export(const char *task_id,
                          const char *export_type,
                          const char *export_format,
                          const char *token,
                          uint8_t *result_data,
                          uintptr_t *result_len,
                          struct FfiError *out_error);

/**
 * 获取转写分享链接
 *
 * # 参数
 * - `task_id`: 任务ID（C 字符串）
 * - `expiration_day`: 过期天数（0 表示使用默认值 7 天）
 * - `token`: Bearer token（C 字符串）
 * - `out_link`: 输出分享链接结构体指针
 * - `out_error`: 错误信息输出指针，如果为 null 则不填充错误信息
 * # 返回
 * 错误码（0 表示成功）
 */
int transcribe_ffi_get_share_link(const char *task_id,
                                  int32_t expiration_day,
                                  const char *token,
                                  struct FfiShareLink *out_link,
                                  struct FfiError *out_error);

/**
 * 获取转写任务状态
 *
 * # 参数
 * - `task_id`: 任务ID（可为 NULL，如果提供 share_id）
 * - `share_id`: 分享链接ID（可为 NULL，如果提供 task_id）
 * - `token`: Bearer token（C 字符串）
 * - `out_status`: 输出状态结构体指针
 * - `out_error`: 错误信息输出指针，如果为 null 则不填充错误信息
 * # 返回
 * 错误码（0 表示成功）
 */
int transcribe_ffi_get_status(const char *task_id,
                              const char *share_id,
                              const char *token,
                              struct FfiTranscribeStatus *out_status,
                              struct FfiError *out_error);

/**
 * 创建总结任务
 *
 * # 参数
 * - `utterances`: Utterance 数组指针
 * - `utterances_len`: Utterance 数组长度
 * - `token`: Bearer token（C 字符串）
 * - `out_summary`: 输出总结任务信息结构体指针
 * - `out_error`: 错误信息输出指针，如果为 null 则不填充错误信息
 * # 返回
 * 错误码（0 表示成功）
 */
int transcribe_ffi_create_summary(const struct FfiUtterance *utterances,
                                  uintptr_t utterances_len,
                                  const char *token,
                                  struct FfiSummaryCreator *out_summary,
                                  struct FfiError *out_error);

/**
 * 上传音频文件进行转写
 *
 * # 参数
 * - `filepath`: 音频文件路径（C 字符串）
 * - `transcribe_only`: 是否仅转写（1 = true, 0 = false）
 * - `short_asr`: 是否使用一句话转写模式（1 = true, 0 = false）
 * - `model`: 模型类型字符串（"speed", "quality", "quality_v2"）
 * - `token`: Bearer token（C 字符串）
 * - `out_result`: 输出上传结果结构体指针
 * - `out_error`: 错误信息输出指针，如果为 null 则不填充错误信息
 * # 返回
 * 错误码（0 表示成功）
 */
int transcribe_ffi_upload(const char *filepath,
                          bool transcribe_only,
                          bool short_asr,
                          const char *model,
                          const char *token,
                          struct FfiUploadResponse *out_result,
                          struct FfiError *out_error);

/**
 * 翻译文本
 *
 * # 参数
 * - `text`: 要翻译的文本（C 字符串）
 * - `target_lang`: 目标语言代码（"zh", "en", "ja", "ko", "fr", "de"）
 * - `token`: Bearer token（C 字符串）
 * - `out_result`: 输出文本翻译结果结构体指针
 * - `out_error`: 错误信息输出指针，如果为 null 则不填充错误信息
 * # 返回
 * 错误码（0 表示成功）
 */
int transcribe_ffi_translate_text(const char *text,
                                  const char *target_lang,
                                  const char *token,
                                  struct FfiTextTranslator *out_result,
                                  struct FfiError *out_error);

/**
 * 翻译 utterances 列表
 *
 * # 参数
 * - `utterances`: Utterance 数组指针
 * - `utterances_len`: Utterance 数组长度
 * - `target_lang`: 目标语言代码（"zh", "en", "ja", "ko", "fr", "de"）
 * - `token`: Bearer token（C 字符串）
 * - `out_result`: 输出 utterance 翻译结果结构体指针
 * - `out_error`: 错误信息输出指针，如果为 null 则不填充错误信息
 * # 返回
 * 错误码（0 表示成功）
 */
int transcribe_ffi_translate_utterance(const struct FfiUtterance *utterances,
                                       uintptr_t utterances_len,
                                       const char *target_lang,
                                       const char *token,
                                       struct FfiUtteranceTranslator *out_result,
                                       struct FfiError *out_error);

/**
 * 获取转写任务的翻译结果
 *
 * # 参数
 * - `task_id`: 任务ID（C 字符串）
 * - `target_lang`: 目标语言代码（"zh", "en", "ja", "ko", "fr", "de"）
 * - `token`: Bearer token（C 字符串）
 * - `out_result`: 输出转写翻译结果结构体指针
 * - `out_error`: 错误信息输出指针，如果为 null 则不填充错误信息
 * # 返回
 * 错误码（0 表示成功）
 */
int transcribe_ffi_translate_transcribe(const char *task_id,
                                        const char *target_lang,
                                        const char *token,
                                        struct FfiTranscribeTranslator *out_result,
                                        struct FfiError *out_error);

/**
 * 处理转写任务状态回调（服务器端使用）
 *
 * # 参数
 * - `request`: 回调请求结构体指针
 * - `token`: Bearer token（C 字符串）
 * - `out_response`: 输出回调响应结构体指针
 * - `out_error`: 错误信息输出指针，如果为 null 则不填充错误信息
 * # 返回
 * 错误码（0 表示成功）
 */
int transcribe_ffi_callback(const struct FfiCallbackRequest *request,
                            const char *token,
                            struct FfiCallbackResponse *out_response,
                            struct FfiError *out_error);

/**
 * 创建实时转写会话
 *
 * # 参数
 * - `model`: 模型类型字符串（"speed", "quality", "quality_v2"）
 * - `token`: Bearer token（C 字符串）
 * - `out_session`: 输出的会话信息结构体指针
 *
 * # 返回
 * 错误码（0 表示成功）
 */
int transcribe_ffi_create_session(const char *model,
                                  const char *token,
                                  struct FfiSessionCreator *out_session,
                                  struct FfiError *out_error);

/**
 * 关闭实时转写会话
 *
 * # 参数
 * - `task_id`: 任务ID（C 字符串）
 * - `token`: Bearer token（C 字符串）
 * - `timeout`: 超时时间（秒），0 表示使用默认值 30 秒
 * - `out_result`: 输出的会话关闭结果结构体指针
 *
 * # 返回
 * 错误码（0 表示成功）
 */
int transcribe_ffi_close_session(const char *task_id,
                                 const char *token,
                                 uint64_t timeout,
                                 struct FfiSessionEnder *out_result,
                                 struct FfiError *out_error);

/**
 * 创建 WebSocket 连接句柄
 *
 * # 参数
 * - `session_id`: 会话ID（C 字符串）
 *
 * # 返回
 * WebSocket 句柄，0 表示失败
 */
int transcribe_ffi_ws_create(const char *session_id,
                             struct TranscribeStream **handle,
                             struct FfiError *out_error);

/**
 * 启动 WebSocket 连接
 *
 * # 参数
 * - `handle`: WebSocket 句柄
 *
 * # 返回
 * 错误码（0 表示成功）
 */
int transcribe_ffi_ws_start(struct TranscribeStream *handle, struct FfiError *out_error);

/**
 * 发送文本消息到 WebSocket
 *
 * # 参数
 * - `handle`: WebSocket 句柄
 * - `text`: 文本消息（C 字符串）
 *
 * # 返回
 * 错误码（0 表示成功）
 */
int transcribe_ffi_ws_write_txt(struct TranscribeStream *handle,
                                const char *text,
                                struct FfiError *out_error);

/**
 * 发送二进制数据到 WebSocket
 *
 * # 参数
 * - `handle`: WebSocket 句柄
 * - `data`: 二进制数据指针
 * - `data_len`: 数据长度
 *
 * # 返回
 * 错误码（0 表示成功）
 */
int transcribe_ffi_ws_write_bytes(struct TranscribeStream *handle,
                                  const uint8_t *data,
                                  uintptr_t data_len,
                                  struct FfiError *out_error);

/**
 * 停止 WebSocket 连接（不断开，但停止消息处理）
 *
 * # 参数
 * - `handle`: WebSocket 句柄
 *
 * # 返回
 * 错误码（0 表示成功）
 */
int transcribe_ffi_ws_stop(struct TranscribeStream *handle, struct FfiError *out_error);

/**
 * 接收 WebSocket 消息（轮询方式）
 *
 * # 参数
 * - `handle`: WebSocket 句柄
 * - `message_json`: 输出消息 JSON 的缓冲区指针
 * - `message_len`: 输入时为缓冲区大小，输出时为实际长度
 * - `timeout_ms`: 超时时间（毫秒），0 表示立即返回
 *
 * # 返回
 * 错误码（0 表示成功）
 */
int transcribe_ffi_ws_receive(struct TranscribeStream *handle,
                              char *message_json,
                              uintptr_t *message_len,
                              uint64_t timeout_ms,
                              struct FfiError *out_error);

/**
 * 释放 WebSocket 连接内存
 *
 * # 参数
 * - `handle`: WebSocket 句柄指针
 */
void transcribe_ffi_ws_free(struct TranscribeStream *handle);

void transcribe_ffi_free_share_link(struct FfiShareLink *s);

void transcribe_ffi_free_transcribe_status(struct FfiTranscribeStatus *s);

void transcribe_ffi_free_callback_response(struct FfiCallbackResponse *s);

void transcribe_ffi_free_summary_creator(struct FfiSummaryCreator *s);

void transcribe_ffi_free_text_translator(struct FfiTextTranslator *s);

void transcribe_ffi_free_utterance_translator(struct FfiUtteranceTranslator *s);

void transcribe_ffi_free_transcribe_translator(struct FfiTranscribeTranslator *s);

void transcribe_ffi_free_upload_response(struct FfiUploadResponse *s);

void transcribe_ffi_free_session_creator(struct FfiSessionCreator *s);

void transcribe_ffi_free_session_ender(struct FfiSessionEnder *s);
